/**
 * KC705 MobileNetV3 PCIe Driver Implementation
 * 
 * This file implements the driver functions for communicating with the
 * KC705 MobileNetV3 accelerator via PCIe interface.
 */

// Feature test macros for usleep and other POSIX functions
#define _DEFAULT_SOURCE
#define _BSD_SOURCE
#define _POSIX_C_SOURCE 200809L

#include "kc705_mobilenet_driver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <time.h>
#include <dirent.h>



#ifdef __linux__
// PCI headers - optional, only needed for hardware detection
#ifdef HAVE_LIBPCI
#include <pci/pci.h>
#include <linux/pci.h>
#endif
#endif

#ifdef _WIN32
#include <windows.h>
#include <setupapi.h>
#include <cfgmgr32.h>
#endif

//=============================================================================
// Global Variables and Constants
//=============================================================================

static bool debug_enabled = false;
static const char* driver_version = "1.0.0";

// ImageNet class names (first 10 for demo)
static const char* imagenet_classes[] = {
    "tench", "goldfish", "great white shark", "tiger shark", "hammerhead",
    "electric ray", "stingray", "cock", "hen", "ostrich"
    // ... (normally all 1000 classes would be here)
};

//=============================================================================
// Debug and Utility Functions
//=============================================================================

#define DEBUG_PRINT(fmt, ...) \
    do { if (debug_enabled) printf("[KC705] " fmt "\n", ##__VA_ARGS__); } while(0)

const char* kc705_get_version(void) {
    return driver_version;
}

const char* kc705_get_error_string(int error_code) {
    switch (error_code) {
        case KC705_SUCCESS:       return "Success";
        case KC705_ERROR:         return "General error";
        case KC705_TIMEOUT:       return "Operation timeout";
        case KC705_NO_DEVICE:     return "No device found";
        case KC705_INVALID_PARAM: return "Invalid parameter";
        default:                  return "Unknown error";
    }
}

void kc705_set_debug(bool enable) {
    debug_enabled = enable;
}

//=============================================================================
// Linux-Specific PCIe Device Discovery
//=============================================================================

#ifdef __linux__
int kc705_enumerate_devices(char device_paths[][256], int max_devices) {
#ifdef HAVE_LIBPCI
    struct pci_access *pacc;
    struct pci_dev *dev;
    int count = 0;
    
    pacc = pci_alloc();
    pci_init(pacc);
    pci_scan_bus(pacc);
    
    for (dev = pacc->devices; dev && count < max_devices; dev = dev->next) {
        pci_fill_info(dev, PCI_FILL_IDENT | PCI_FILL_BASES);
        
        if (dev->vendor_id == KC705_VENDOR_ID && dev->device_id == KC705_DEVICE_ID) {
            snprintf(device_paths[count], 256, "/sys/bus/pci/devices/%04x:%02x:%02x.%d",
                    dev->domain, dev->bus, dev->dev, dev->func);
            count++;
            DEBUG_PRINT("Found KC705 device: %s", device_paths[count-1]);
        }
    }
    
    pci_cleanup(pacc);
    return count;
#else
    // Fallback: simulate device detection for testing
    (void)device_paths;
    (void)max_devices;
    DEBUG_PRINT("PCI library not available - using simulation mode");
    return 0;  // No devices found in simulation mode
#endif
}

static int map_pci_device(kc705_device_t* device, const char* device_path) {
    char resource_path[512];
    
    // Open BAR0 (registers)
    snprintf(resource_path, sizeof(resource_path), "%s/resource0", device_path);
    device->pci_fd = open(resource_path, O_RDWR | O_SYNC);
    if (device->pci_fd < 0) {
        DEBUG_PRINT("Failed to open %s: %s", resource_path, strerror(errno));
        return KC705_ERROR;
    }
    
    // Map BAR0 for register access
    device->reg_base = mmap(NULL, 4096, PROT_READ | PROT_WRITE, 
                           MAP_SHARED, device->pci_fd, 0);
    if (device->reg_base == MAP_FAILED) {
        DEBUG_PRINT("Failed to map registers: %s", strerror(errno));
        close(device->pci_fd);
        return KC705_ERROR;
    }
    
    // Map BAR1 for memory access (if available)
    snprintf(resource_path, sizeof(resource_path), "%s/resource1", device_path);
    int mem_fd = open(resource_path, O_RDWR | O_SYNC);
    if (mem_fd >= 0) {
        device->mem_base = mmap(NULL, 65536, PROT_READ | PROT_WRITE,
                               MAP_SHARED, mem_fd, 0);
        close(mem_fd);
    }
    
    return KC705_SUCCESS;
}
#endif

//=============================================================================
// Windows-Specific PCIe Device Discovery
//=============================================================================

#ifdef _WIN32
int kc705_enumerate_devices(char device_paths[][256], int max_devices) {
    HDEVINFO dev_info;
    SP_DEVINFO_DATA dev_info_data;
    DWORD index = 0;
    int count = 0;
    
    dev_info = SetupDiGetClassDevs(NULL, NULL, NULL, 
                                   DIGCF_PRESENT | DIGCF_ALLCLASSES);
    if (dev_info == INVALID_HANDLE_VALUE) {
        return 0;
    }
    
    dev_info_data.cbSize = sizeof(SP_DEVINFO_DATA);
    
    while (SetupDiEnumDeviceInfo(dev_info, index, &dev_info_data) && count < max_devices) {
        char hardware_id[256];
        DWORD required_size;
        
        if (SetupDiGetDeviceRegistryProperty(dev_info, &dev_info_data,
                                           SPDRP_HARDWAREID, NULL,
                                           (PBYTE)hardware_id, sizeof(hardware_id),
                                           &required_size)) {
            if (strstr(hardware_id, "VEN_10EE&DEV_7024")) {
                snprintf(device_paths[count], 256, "\\\\.\\KC705_%d", count);
                count++;
                DEBUG_PRINT("Found KC705 device: %s", device_paths[count-1]);
            }
        }
        index++;
    }
    
    SetupDiDestroyDeviceInfoList(dev_info);
    return count;
}

static int map_pci_device(kc705_device_t* device, const char* device_path) {
    // Windows-specific device mapping would go here
    // This is a simplified version
    DEBUG_PRINT("Windows PCIe mapping not fully implemented in this example");
    return KC705_ERROR;
}
#endif

//=============================================================================
// Core Device Functions
//=============================================================================

kc705_device_t* kc705_open(void) {
    return kc705_open_device(0);  // Open first device
}

kc705_device_t* kc705_open_device(int device_index) {
    char device_paths[KC705_MAX_DEVICES][256];
    int num_devices = kc705_enumerate_devices(device_paths, KC705_MAX_DEVICES);
    
    if (num_devices == 0) {
        DEBUG_PRINT("No KC705 devices found");
        return NULL;
    }
    
    if (device_index >= num_devices) {
        DEBUG_PRINT("Device index %d out of range (0-%d)", device_index, num_devices-1);
        return NULL;
    }
    
    kc705_device_t* device = malloc(sizeof(kc705_device_t));
    if (!device) {
        DEBUG_PRINT("Failed to allocate device structure");
        return NULL;
    }
    
    memset(device, 0, sizeof(kc705_device_t));
    strcpy(device->device_path, device_paths[device_index]);
    
    if (map_pci_device(device, device->device_path) != KC705_SUCCESS) {
        free(device);
        return NULL;
    }
    
    device->is_open = true;
    device->device_id = device_index;
    
    DEBUG_PRINT("Opened KC705 device %d successfully", device_index);
    return device;
}

int kc705_close(kc705_device_t* device) {
    if (!device || !device->is_open) {
        return KC705_INVALID_PARAM;
    }
    
    if (device->reg_base && device->reg_base != MAP_FAILED) {
        munmap(device->reg_base, 4096);
    }
    
    if (device->mem_base && device->mem_base != MAP_FAILED) {
        munmap(device->mem_base, 65536);
    }
    
    if (device->pci_fd >= 0) {
        close(device->pci_fd);
    }
    
    device->is_open = false;
    free(device);
    
    DEBUG_PRINT("Closed KC705 device");
    return KC705_SUCCESS;
}

//=============================================================================
// Register Access Functions
//=============================================================================

int kc705_read_reg(kc705_device_t* device, uint32_t offset, uint32_t* value) {
    if (!device || !device->is_open || !device->reg_base) {
        return KC705_INVALID_PARAM;
    }
    
    volatile uint32_t* reg_ptr = (volatile uint32_t*)((char*)device->reg_base + offset);
    *value = *reg_ptr;
    
    DEBUG_PRINT("Read reg 0x%02X = 0x%08X", offset, *value);
    return KC705_SUCCESS;
}

int kc705_write_reg(kc705_device_t* device, uint32_t offset, uint32_t value) {
    if (!device || !device->is_open || !device->reg_base) {
        return KC705_INVALID_PARAM;
    }
    
    volatile uint32_t* reg_ptr = (volatile uint32_t*)((char*)device->reg_base + offset);
    *reg_ptr = value;
    
    DEBUG_PRINT("Write reg 0x%02X = 0x%08X", offset, value);
    return KC705_SUCCESS;
}

uint32_t kc705_get_debug_status(kc705_device_t* device) {
    uint32_t status = 0;
    kc705_read_reg(device, REG_DEBUG, &status);
    return status;
}

//=============================================================================
// Status and Control Functions
//=============================================================================

bool kc705_is_done(kc705_device_t* device) {
    uint32_t status;
    if (kc705_read_reg(device, REG_STATUS, &status) != KC705_SUCCESS) {
        return false;
    }
    return (status & STAT_DONE) != 0;
}

int kc705_reset(kc705_device_t* device) {
    // Set reset bit
    int ret = kc705_write_reg(device, REG_CONTROL, CTRL_RESET);
    if (ret != KC705_SUCCESS) return ret;
    
    usleep(1000);  // Wait 1ms
    
    // Clear reset bit
    return kc705_write_reg(device, REG_CONTROL, 0);
}

//=============================================================================
// Image Processing Functions
//=============================================================================

int kc705_upload_image(kc705_device_t* device, const uint8_t* image_data, size_t size) {
    if (!device || !device->is_open || !image_data) {
        return KC705_INVALID_PARAM;
    }
    
    if (size > 4096) {  // 4KB buffer limit
        DEBUG_PRINT("Image size %zu exceeds buffer limit", size);
        return KC705_INVALID_PARAM;
    }
    
    // Write image data to memory-mapped region
    if (device->mem_base) {
        memcpy((char*)device->mem_base + KC705_IMAGE_BASE, image_data, size);
    } else {
        // Alternative: write via register interface (slower)
        for (size_t i = 0; i < size; i += 4) {
            uint32_t word = *(uint32_t*)(image_data + i);
            kc705_write_reg(device, KC705_IMAGE_BASE + i, word);
        }
    }
    
    // Set image size
    kc705_write_reg(device, REG_IMAGE_SIZE, size);
    
    DEBUG_PRINT("Uploaded %zu bytes of image data", size);
    return KC705_SUCCESS;
}

int kc705_start_inference(kc705_device_t* device) {
    if (!device || !device->is_open) {
        return KC705_INVALID_PARAM;
    }
    
    // Enable interrupts and start processing
    uint32_t control = CTRL_START | CTRL_IRQ_EN;
    int ret = kc705_write_reg(device, REG_CONTROL, control);
    
    DEBUG_PRINT("Started inference");
    return ret;
}

int kc705_get_result(kc705_device_t* device, classification_result_t* result) {
    if (!device || !device->is_open || !result) {
        return KC705_INVALID_PARAM;
    }
    
    // Wait for completion (with timeout)
    int timeout_ms = 5000;  // 5 second timeout
    int elapsed_ms = 0;
    
    while (!kc705_is_done(device) && elapsed_ms < timeout_ms) {
        usleep(1000);  // Sleep 1ms
        elapsed_ms++;
    }
    
    if (elapsed_ms >= timeout_ms) {
        DEBUG_PRINT("Inference timeout");
        return KC705_TIMEOUT;
    }
    
    // Read result from memory
    uint32_t class_id, confidence_raw, timing;
    
    if (device->mem_base) {
        uint32_t* result_ptr = (uint32_t*)((char*)device->mem_base + KC705_RESULT_BASE);
        class_id = result_ptr[0];
        confidence_raw = result_ptr[1];
        timing = result_ptr[2];
    } else {
        kc705_read_reg(device, KC705_RESULT_BASE + 0, &class_id);
        kc705_read_reg(device, KC705_RESULT_BASE + 4, &confidence_raw);
        kc705_read_reg(device, KC705_RESULT_BASE + 8, &timing);
    }
    
    // Fill result structure
    result->class_id = class_id % NUM_CLASSES;
    result->confidence = (float)confidence_raw / 10000.0f;  // Convert from fixed-point
    result->processing_time_us = timing;
    result->valid = true;
    
    DEBUG_PRINT("Result: class=%d, confidence=%.2f%%, time=%dus", 
                result->class_id, result->confidence * 100.0f, result->processing_time_us);
    
    return KC705_SUCCESS;
}

int kc705_get_result_nowait(kc705_device_t* device, classification_result_t* result) {
    if (!kc705_is_done(device)) {
        return KC705_TIMEOUT;
    }
    return kc705_get_result(device, result);
}

//=============================================================================
// Convenience Functions
//=============================================================================

int kc705_infer(kc705_device_t* device, const uint8_t* image_data, 
                size_t size, classification_result_t* result) {
    int ret;
    
    ret = kc705_upload_image(device, image_data, size);
    if (ret != KC705_SUCCESS) return ret;
    
    ret = kc705_start_inference(device);
    if (ret != KC705_SUCCESS) return ret;
    
    return kc705_get_result(device, result);
}

int kc705_infer_batch(kc705_device_t* device, const char** image_files, 
                      int num_images, classification_result_t* results) {
    int processed = 0;
    
    for (int i = 0; i < num_images; i++) {
        int ret = kc705_infer_file(device, image_files[i], &results[processed]);
        if (ret == KC705_SUCCESS) {
            processed++;
        } else {
            DEBUG_PRINT("Failed to process %s: %s", image_files[i], kc705_get_error_string(ret));
        }
    }
    
    return processed;
}

//=============================================================================
// Image Loading Functions (Simplified)
//=============================================================================

uint8_t* kc705_load_image(const char* filename, int* width, int* height, int* channels) {
    FILE* fp = fopen(filename, "rb");
    if (!fp) {
        DEBUG_PRINT("Failed to open image file: %s", filename);
        return NULL;
    }
    
    // This is a simplified loader - in practice you'd use a library like stb_image
    // For demo purposes, assume 224x224x3 RGB data
    *width = 224;
    *height = 224;
    *channels = 3;
    
    size_t image_size = 224 * 224 * 3;
    uint8_t* image_data = malloc(image_size);
    
    if (fread(image_data, 1, image_size, fp) != image_size) {
        DEBUG_PRINT("Failed to read expected image data");
        free(image_data);
        fclose(fp);
        return NULL;
    }
    
    fclose(fp);
    return image_data;
}

void kc705_free_image(uint8_t* image_data) {
    if (image_data) {
        free(image_data);
    }
}

int kc705_infer_file(kc705_device_t* device, const char* filename, 
                     classification_result_t* result) {
    int width, height, channels;
    uint8_t* image_data = kc705_load_image(filename, &width, &height, &channels);
    
    if (!image_data) {
        return KC705_ERROR;
    }
    
    int ret = kc705_infer(device, image_data, width * height * channels, result);
    kc705_free_image(image_data);
    
    return ret;
}

//=============================================================================
// Device Information Functions
//=============================================================================

int kc705_get_device_info(kc705_device_t* device, device_info_t* info) {
    if (!device || !info) {
        return KC705_INVALID_PARAM;
    }
    
    info->vendor_id = KC705_VENDOR_ID;
    info->device_id = KC705_DEVICE_ID;
    info->revision = 1;
    strcpy(info->driver_version, driver_version);
    
    uint32_t status;
    kc705_read_reg(device, REG_STATUS, &status);
    info->link_up = (status & STAT_LINK_UP) != 0;
    info->link_speed = 5;  // Gen2 = 5 GT/s
    info->link_width = 8;  // x8 lanes
    
    return KC705_SUCCESS;
}

//=============================================================================
// Class Name Functions
//=============================================================================

const char* kc705_get_class_name(uint32_t class_id) {
    if (class_id >= 1000) {
        return "unknown";
    }
    
    // Return class name from ImageNet dataset
    // For demo purposes, only first 10 classes are defined
    if (class_id < 10) {
        return imagenet_classes[class_id];
    }
    
    static char class_buffer[32];
    snprintf(class_buffer, sizeof(class_buffer), "class_%d", class_id);
    return class_buffer;
}