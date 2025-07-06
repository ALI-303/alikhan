/**
 * KC705 MobileNetV3 PCIe Driver Interface
 * 
 * This header provides the C/C++ API for communicating with the MobileNetV3
 * accelerator on the KC705 board via PCIe interface.
 * 
 * Usage Example:
 *   kc705_device_t* device = kc705_open();
 *   kc705_upload_image(device, image_data, size);
 *   kc705_start_inference(device);
 *   result = kc705_get_result(device);
 *   kc705_close(device);
 */

#ifndef KC705_MOBILENET_DRIVER_H
#define KC705_MOBILENET_DRIVER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

//=============================================================================
// Constants and Definitions
//=============================================================================

#define KC705_VENDOR_ID     0x10EE      // Xilinx Vendor ID
#define KC705_DEVICE_ID     0x7024      // KC705 Device ID
#define KC705_MAX_DEVICES   8           // Maximum devices supported

// Memory map addresses
#define KC705_REG_BASE      0x0000
#define KC705_IMAGE_BASE    0x1000
#define KC705_RESULT_BASE   0x2000
#define KC705_WEIGHT_BASE   0x10000

// Register offsets
#define REG_CONTROL         0x00
#define REG_STATUS          0x04
#define REG_INTERRUPT       0x08
#define REG_IMAGE_SIZE      0x0C
#define REG_IMAGE_ADDR      0x10
#define REG_RESULT_ADDR     0x14
#define REG_WEIGHT_ADDR     0x18
#define REG_DEBUG           0x1C

// Control register bits
#define CTRL_START          (1 << 0)
#define CTRL_RESET          (1 << 1)
#define CTRL_IRQ_EN         (1 << 2)
#define CTRL_DMA_EN         (1 << 3)

// Status register bits
#define STAT_DONE           (1 << 0)
#define STAT_BUSY           (1 << 1)
#define STAT_ERROR          (1 << 2)
#define STAT_LINK_UP        (1 << 3)

// Image format constants
#define IMAGE_WIDTH         224
#define IMAGE_HEIGHT        224
#define IMAGE_CHANNELS      3
#define IMAGE_SIZE          (IMAGE_WIDTH * IMAGE_HEIGHT * IMAGE_CHANNELS)
#define NUM_CLASSES         1000

// Error codes
#define KC705_SUCCESS       0
#define KC705_ERROR         -1
#define KC705_TIMEOUT       -2
#define KC705_NO_DEVICE     -3
#define KC705_INVALID_PARAM -4

//=============================================================================
// Data Structures
//=============================================================================

/**
 * KC705 device handle structure
 */
typedef struct kc705_device {
    int pci_fd;                    // PCIe device file descriptor
    void *reg_base;                // Memory-mapped register base
    void *mem_base;                // Memory-mapped data base
    uint32_t bar_size[6];          // BAR sizes
    bool is_open;                  // Device open status
    uint32_t device_id;            // Device ID
    char device_path[256];         // Device path
} kc705_device_t;

/**
 * Classification result structure
 */
typedef struct {
    uint32_t class_id;             // Predicted class ID (0-999)
    float confidence;              // Confidence score (0.0-1.0)
    uint32_t processing_time_us;   // Processing time in microseconds
    bool valid;                    // Result validity flag
} classification_result_t;

/**
 * Performance statistics structure
 */
typedef struct {
    uint64_t total_inferences;     // Total number of inferences
    uint64_t total_time_us;        // Total processing time
    float avg_fps;                 // Average frames per second
    float avg_latency_ms;          // Average latency in milliseconds
    uint32_t errors;               // Number of errors
} performance_stats_t;

/**
 * Device information structure
 */
typedef struct {
    uint16_t vendor_id;            // PCI vendor ID
    uint16_t device_id;            // PCI device ID
    uint8_t revision;              // Device revision
    char driver_version[32];       // Driver version string
    bool link_up;                  // PCIe link status
    uint32_t link_speed;           // PCIe link speed (GT/s)
    uint8_t link_width;            // PCIe link width (lanes)
} device_info_t;

//=============================================================================
// Core API Functions
//=============================================================================

/**
 * Open KC705 device
 * @return Device handle or NULL on error
 */
kc705_device_t* kc705_open(void);

/**
 * Open specific KC705 device by index
 * @param device_index Device index (0-based)
 * @return Device handle or NULL on error
 */
kc705_device_t* kc705_open_device(int device_index);

/**
 * Close KC705 device
 * @param device Device handle
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_close(kc705_device_t* device);

/**
 * Upload image data to KC705 device
 * @param device Device handle
 * @param image_data Pointer to image data (224x224x3 RGB)
 * @param size Size of image data in bytes
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_upload_image(kc705_device_t* device, const uint8_t* image_data, size_t size);

/**
 * Start MobileNetV3 inference
 * @param device Device handle
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_start_inference(kc705_device_t* device);

/**
 * Get inference result (blocking)
 * @param device Device handle
 * @param result Pointer to result structure
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_get_result(kc705_device_t* device, classification_result_t* result);

/**
 * Get inference result (non-blocking)
 * @param device Device handle
 * @param result Pointer to result structure
 * @return KC705_SUCCESS on success, KC705_TIMEOUT if not ready, error code on failure
 */
int kc705_get_result_nowait(kc705_device_t* device, classification_result_t* result);

/**
 * Check if inference is complete
 * @param device Device handle
 * @return true if complete, false if still processing
 */
bool kc705_is_done(kc705_device_t* device);

/**
 * Reset the device
 * @param device Device handle
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_reset(kc705_device_t* device);

//=============================================================================
// Convenience Functions
//=============================================================================

/**
 * Perform complete inference (upload + start + get result)
 * @param device Device handle
 * @param image_data Pointer to image data
 * @param size Size of image data
 * @param result Pointer to result structure
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_infer(kc705_device_t* device, const uint8_t* image_data, 
                size_t size, classification_result_t* result);

/**
 * Load image from file and perform inference
 * @param device Device handle
 * @param filename Image file path
 * @param result Pointer to result structure
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_infer_file(kc705_device_t* device, const char* filename, 
                     classification_result_t* result);

/**
 * Process batch of images
 * @param device Device handle
 * @param image_files Array of image file paths
 * @param num_images Number of images
 * @param results Array of result structures
 * @return Number of successfully processed images
 */
int kc705_infer_batch(kc705_device_t* device, const char** image_files, 
                      int num_images, classification_result_t* results);

//=============================================================================
// Weight and Configuration Functions
//=============================================================================

/**
 * Load MobileNetV3 weights from file
 * @param device Device handle
 * @param weights_file Path to weights file
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_load_weights(kc705_device_t* device, const char* weights_file);

/**
 * Load weights from memory
 * @param device Device handle
 * @param weights Pointer to weight data
 * @param size Size of weight data
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_load_weights_mem(kc705_device_t* device, const uint8_t* weights, size_t size);

/**
 * Set model configuration
 * @param device Device handle
 * @param model_type "LARGE" or "SMALL"
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_set_model(kc705_device_t* device, const char* model_type);

//=============================================================================
// Status and Debug Functions
//=============================================================================

/**
 * Get device information
 * @param device Device handle
 * @param info Pointer to device info structure
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_get_device_info(kc705_device_t* device, device_info_t* info);

/**
 * Get performance statistics
 * @param device Device handle
 * @param stats Pointer to performance stats structure
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_get_performance_stats(kc705_device_t* device, performance_stats_t* stats);

/**
 * Reset performance counters
 * @param device Device handle
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_reset_stats(kc705_device_t* device);

/**
 * Read register value
 * @param device Device handle
 * @param offset Register offset
 * @param value Pointer to store register value
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_read_reg(kc705_device_t* device, uint32_t offset, uint32_t* value);

/**
 * Write register value
 * @param device Device handle
 * @param offset Register offset
 * @param value Register value to write
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_write_reg(kc705_device_t* device, uint32_t offset, uint32_t value);

/**
 * Get debug status
 * @param device Device handle
 * @return Debug status register value
 */
uint32_t kc705_get_debug_status(kc705_device_t* device);

//=============================================================================
// Utility Functions
//=============================================================================

/**
 * Get driver version string
 * @return Version string
 */
const char* kc705_get_version(void);

/**
 * Get error string for error code
 * @param error_code Error code
 * @return Error description string
 */
const char* kc705_get_error_string(int error_code);

/**
 * Enable/disable debug output
 * @param enable True to enable, false to disable
 */
void kc705_set_debug(bool enable);

/**
 * Enumerate available KC705 devices
 * @param device_paths Array to store device paths
 * @param max_devices Maximum number of devices to find
 * @return Number of devices found
 */
int kc705_enumerate_devices(char device_paths[][256], int max_devices);

//=============================================================================
// Image Processing Utilities
//=============================================================================

/**
 * Load image from file and convert to RGB format
 * @param filename Image file path
 * @param width Pointer to store image width
 * @param height Pointer to store image height
 * @param channels Pointer to store number of channels
 * @return Pointer to image data (caller must free) or NULL on error
 */
uint8_t* kc705_load_image(const char* filename, int* width, int* height, int* channels);

/**
 * Resize image to 224x224
 * @param src Source image data
 * @param src_width Source width
 * @param src_height Source height
 * @param dst Destination buffer (must be allocated)
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_resize_image(const uint8_t* src, int src_width, int src_height, uint8_t* dst);

/**
 * Normalize image data for MobileNetV3 input
 * @param image Image data to normalize (in-place)
 * @param size Image size in bytes
 * @return KC705_SUCCESS on success, error code on failure
 */
int kc705_normalize_image(uint8_t* image, size_t size);

/**
 * Free image data allocated by kc705_load_image
 * @param image_data Pointer to image data
 */
void kc705_free_image(uint8_t* image_data);

//=============================================================================
// ImageNet Class Labels
//=============================================================================

/**
 * Get ImageNet class name for class ID
 * @param class_id Class ID (0-999)
 * @return Class name string
 */
const char* kc705_get_class_name(uint32_t class_id);

/**
 * Get top-k class names and confidences
 * @param results Array of classification results
 * @param k Number of top results to get
 * @param class_names Array to store class names
 * @param confidences Array to store confidences
 * @return Number of results returned
 */
int kc705_get_top_k(const classification_result_t* results, int k, 
                    const char** class_names, float* confidences);

#ifdef __cplusplus
}
#endif

#endif // KC705_MOBILENET_DRIVER_H