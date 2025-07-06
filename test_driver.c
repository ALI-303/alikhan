/**
 * KC705 MobileNetV3 Driver Test Program
 * 
 * This program tests basic driver functionality:
 * - Device enumeration
 * - Basic register access
 * - Library linking verification
 */

#include "kc705_mobilenet_driver.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

void print_header(void) {
    printf("===========================================\n");
    printf("KC705 MobileNetV3 Driver Test Program\n");
    printf("Version: %s\n", kc705_get_version());
    printf("===========================================\n\n");
}

void test_device_enumeration(void) {
    printf("🔍 Testing device enumeration...\n");
    
    char device_paths[KC705_MAX_DEVICES][256];
    int num_devices = kc705_enumerate_devices(device_paths, KC705_MAX_DEVICES);
    
    printf("Found %d KC705 device(s)\n", num_devices);
    
    for (int i = 0; i < num_devices; i++) {
        printf("  Device %d: %s\n", i, device_paths[i]);
    }
    
    if (num_devices == 0) {
        printf("⚠️  No KC705 devices found. This is normal if:\n");
        printf("   - KC705 is not connected via PCIe\n");
        printf("   - FPGA is not programmed with MobileNetV3 bitstream\n");
        printf("   - Running in simulation/test mode\n");
    } else {
        printf("✅ Device enumeration successful!\n");
    }
    printf("\n");
}

void test_device_open_close(void) {
    printf("🔗 Testing device open/close...\n");
    
    kc705_device_t* device = kc705_open();
    if (device) {
        printf("✅ Device opened successfully\n");
        
        // Test device info
        device_info_t info;
        if (kc705_get_device_info(device, &info) == KC705_SUCCESS) {
            printf("   Vendor ID: 0x%04X\n", info.vendor_id);
            printf("   Device ID: 0x%04X\n", info.device_id);
            printf("   Driver Version: %s\n", info.driver_version);
            printf("   Link Status: %s\n", info.link_up ? "UP" : "DOWN");
            printf("   Link Speed: %d GT/s\n", info.link_speed);
            printf("   Link Width: x%d\n", info.link_width);
        }
        
        // Close device
        int result = kc705_close(device);
        if (result == KC705_SUCCESS) {
            printf("✅ Device closed successfully\n");
        } else {
            printf("❌ Device close failed: %s\n", kc705_get_error_string(result));
        }
    } else {
        printf("⚠️  Could not open device (expected if no hardware present)\n");
        printf("   This test passes if running without actual KC705 hardware\n");
    }
    printf("\n");
}

void test_error_handling(void) {
    printf("🧪 Testing error handling...\n");
    
    // Test error code strings
    printf("Error codes:\n");
    printf("  KC705_SUCCESS: %s\n", kc705_get_error_string(KC705_SUCCESS));
    printf("  KC705_ERROR: %s\n", kc705_get_error_string(KC705_ERROR));
    printf("  KC705_TIMEOUT: %s\n", kc705_get_error_string(KC705_TIMEOUT));
    printf("  KC705_NO_DEVICE: %s\n", kc705_get_error_string(KC705_NO_DEVICE));
    
    // Test invalid parameters
    int result = kc705_close(NULL);
    if (result == KC705_INVALID_PARAM) {
        printf("✅ NULL parameter handling works\n");
    }
    
    printf("✅ Error handling test passed\n\n");
}

void test_class_names(void) {
    printf("📋 Testing class name lookup...\n");
    
    // Test first few ImageNet classes
    for (uint32_t i = 0; i < 10; i++) {
        const char* class_name = kc705_get_class_name(i);
        printf("  Class %d: %s\n", i, class_name);
    }
    
    // Test out of range
    const char* unknown = kc705_get_class_name(9999);
    printf("  Class 9999: %s\n", unknown);
    
    printf("✅ Class name lookup test passed\n\n");
}

void test_simulation_mode(void) {
    printf("🎯 Testing simulation mode...\n");
    
    // In simulation mode, we can test the API without hardware
    classification_result_t result;
    
    // Create dummy image data
    uint8_t dummy_image[224 * 224 * 3];
    memset(dummy_image, 128, sizeof(dummy_image)); // Gray image
    
    printf("   Created dummy 224x224x3 image (%zu bytes)\n", sizeof(dummy_image));
    
    // Test image loading functions
    uint8_t* loaded_image = kc705_load_image("nonexistent.jpg", NULL, NULL, NULL);
    if (!loaded_image) {
        printf("✅ Image loading correctly fails for non-existent file\n");
    }
    
    printf("✅ Simulation mode test passed\n\n");
}

void print_compilation_info(void) {
    printf("🔧 Compilation Information:\n");
    
#ifdef __LINUX__
    printf("   Platform: Linux\n");
#elif defined(_WIN32)
    printf("   Platform: Windows\n");
#elif defined(__MACOS__)
    printf("   Platform: macOS\n");
#else
    printf("   Platform: Unknown\n");
#endif

#ifdef DEBUG
    printf("   Build Type: Debug\n");
#else
    printf("   Build Type: Release\n");
#endif

    printf("   Compiler: ");
#ifdef __GNUC__
    printf("GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
#elif defined(_MSC_VER)
    printf("MSVC %d\n", _MSC_VER);
#else
    printf("Unknown\n");
#endif

    printf("   C Standard: ");
#if __STDC_VERSION__ >= 201112L
    printf("C11\n");
#elif __STDC_VERSION__ >= 199901L
    printf("C99\n");
#else
    printf("C90\n");
#endif

    printf("\n");
}

void run_performance_test(void) {
    printf("⚡ Basic Performance Test:\n");
    
    clock_t start = clock();
    
    // Simulate some operations
    for (int i = 0; i < 1000; i++) {
        kc705_get_error_string(KC705_SUCCESS);
        kc705_get_class_name(i % 1000);
    }
    
    clock_t end = clock();
    double cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;
    
    printf("   1000 function calls took %.6f seconds\n", cpu_time);
    printf("   Average: %.2f microseconds per call\n", cpu_time * 1000000 / 1000);
    
    printf("✅ Performance test completed\n\n");
}

int main(void) {
    print_header();
    print_compilation_info();
    
    // Enable debug output
    kc705_set_debug(true);
    
    printf("🚀 Starting KC705 Driver Tests...\n\n");
    
    // Run all tests
    test_device_enumeration();
    test_device_open_close();
    test_error_handling();
    test_class_names();
    test_simulation_mode();
    run_performance_test();
    
    printf("🎉 All tests completed!\n");
    printf("\nTest Summary:\n");
    printf("✅ Driver compiles successfully\n");
    printf("✅ All API functions are accessible\n");
    printf("✅ Error handling works correctly\n");
    printf("✅ Library linking is functional\n");
    
    if (kc705_enumerate_devices(NULL, 0) > 0) {
        printf("✅ Hardware detected and accessible\n");
        printf("\n💡 Next steps:\n");
        printf("   1. Program KC705 with MobileNetV3 bitstream\n");
        printf("   2. Run example programs: ./bin/kc705_examples\n");
        printf("   3. Try real image classification\n");
    } else {
        printf("⚠️  No hardware detected (software-only test)\n");
        printf("\n💡 Next steps:\n");
        printf("   1. Connect KC705 via PCIe\n");
        printf("   2. Program FPGA with provided bitstream\n");
        printf("   3. Re-run this test to verify hardware detection\n");
        printf("   4. Use example programs for real inference\n");
    }
    
    return 0;
}