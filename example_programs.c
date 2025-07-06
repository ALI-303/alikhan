/**
 * KC705 MobileNetV3 Example Programs
 * 
 * These examples show how to use the PCIe interface to send data from your
 * computer to the KC705 board for MobileNetV3 inference.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "kc705_mobilenet_driver.h"

//=============================================================================
// Example 1: Basic Single Image Inference
//=============================================================================

/**
 * Example: Classify a single image from your computer
 */
int example_single_image() {
    printf("=== KC705 MobileNetV3 Single Image Example ===\n");
    
    // Open KC705 device
    kc705_device_t* device = kc705_open();
    if (!device) {
        printf("Error: Failed to open KC705 device\n");
        return -1;
    }
    
    // Load image from your computer
    const char* image_path = "C:/Users/YourName/Pictures/cat.jpg";  // YOUR IMAGE FILE
    printf("Loading image: %s\n", image_path);
    
    classification_result_t result;
    int ret = kc705_infer_file(device, image_path, &result);
    
    if (ret == KC705_SUCCESS) {
        printf("Classification Result:\n");
        printf("  Class ID: %d\n", result.class_id);
        printf("  Class Name: %s\n", kc705_get_class_name(result.class_id));
        printf("  Confidence: %.2f%%\n", result.confidence * 100.0);
        printf("  Processing Time: %d μs\n", result.processing_time_us);
    } else {
        printf("Error: Inference failed (%s)\n", kc705_get_error_string(ret));
    }
    
    // Clean up
    kc705_close(device);
    return ret;
}

//=============================================================================
// Example 2: Batch Processing Multiple Images
//=============================================================================

/**
 * Example: Process multiple images from your computer folder
 */
int example_batch_processing() {
    printf("=== KC705 MobileNetV3 Batch Processing Example ===\n");
    
    kc705_device_t* device = kc705_open();
    if (!device) {
        printf("Error: Failed to open KC705 device\n");
        return -1;
    }
    
    // List of images from your computer
    const char* image_files[] = {
        "C:/dataset/image1.jpg",   // YOUR IMAGE FILES
        "C:/dataset/image2.jpg",
        "C:/dataset/image3.jpg",
        "C:/dataset/image4.jpg",
        "C:/dataset/image5.jpg"
    };
    
    int num_images = sizeof(image_files) / sizeof(image_files[0]);
    classification_result_t results[num_images];
    
    printf("Processing %d images...\n", num_images);
    
    clock_t start_time = clock();
    
    // Process all images
    int processed = kc705_infer_batch(device, image_files, num_images, results);
    
    clock_t end_time = clock();
    double total_time = (double)(end_time - start_time) / CLOCKS_PER_SEC;
    
    printf("\nBatch Processing Results:\n");
    printf("Successfully processed: %d/%d images\n", processed, num_images);
    printf("Total time: %.2f seconds\n", total_time);
    printf("Average FPS: %.1f\n", processed / total_time);
    
    // Display results for each image
    for (int i = 0; i < processed; i++) {
        printf("\nImage %d (%s):\n", i + 1, image_files[i]);
        printf("  Class: %s (ID: %d)\n", kc705_get_class_name(results[i].class_id), results[i].class_id);
        printf("  Confidence: %.2f%%\n", results[i].confidence * 100.0);
        printf("  Time: %d μs\n", results[i].processing_time_us);
    }
    
    kc705_close(device);
    return KC705_SUCCESS;
}

//=============================================================================
// Example 3: Real-time Camera Feed Processing
//=============================================================================

/**
 * Example: Process real-time camera feed from your computer
 * Requires OpenCV for camera capture
 */
#ifdef OPENCV_AVAILABLE
#include <opencv2/opencv.hpp>

int example_realtime_camera() {
    printf("=== KC705 MobileNetV3 Real-time Camera Example ===\n");
    
    kc705_device_t* device = kc705_open();
    if (!device) {
        printf("Error: Failed to open KC705 device\n");
        return -1;
    }
    
    // Open camera on your computer
    cv::VideoCapture cap(0);  // Camera 0
    if (!cap.isOpened()) {
        printf("Error: Cannot open camera\n");
        kc705_close(device);
        return -1;
    }
    
    printf("Press 'q' to quit\n");
    
    cv::Mat frame, resized_frame;
    classification_result_t result;
    int frame_count = 0;
    clock_t start_time = clock();
    
    while (true) {
        // Capture frame from your computer's camera
        cap >> frame;
        if (frame.empty()) break;
        
        // Resize to 224x224 for MobileNetV3
        cv::resize(frame, resized_frame, cv::Size(224, 224));
        
        // Convert to RGB format
        cv::cvtColor(resized_frame, resized_frame, cv::COLOR_BGR2RGB);
        
        // Send to KC705 for inference
        int ret = kc705_infer(device, resized_frame.data, 224*224*3, &result);
        
        if (ret == KC705_SUCCESS) {
            // Display result on frame
            std::string text = kc705_get_class_name(result.class_id);
            text += " (" + std::to_string((int)(result.confidence * 100)) + "%)";
            
            cv::putText(frame, text, cv::Point(10, 30), 
                       cv::FONT_HERSHEY_SIMPLEX, 1, cv::Scalar(0, 255, 0), 2);
            
            frame_count++;
            
            // Calculate and display FPS
            if (frame_count % 30 == 0) {
                clock_t current_time = clock();
                double elapsed = (double)(current_time - start_time) / CLOCKS_PER_SEC;
                double fps = frame_count / elapsed;
                printf("FPS: %.1f, Last result: %s\n", fps, kc705_get_class_name(result.class_id));
            }
        }
        
        // Display frame
        cv::imshow("KC705 MobileNetV3 Real-time", frame);
        
        // Check for quit
        if (cv::waitKey(1) == 'q') break;
    }
    
    cap.release();
    cv::destroyAllWindows();
    kc705_close(device);
    
    printf("Processed %d frames\n", frame_count);
    return KC705_SUCCESS;
}
#endif

//=============================================================================
// Example 4: Performance Benchmarking
//=============================================================================

/**
 * Example: Benchmark performance with different image sizes and batches
 */
int example_performance_benchmark() {
    printf("=== KC705 MobileNetV3 Performance Benchmark ===\n");
    
    kc705_device_t* device = kc705_open();
    if (!device) {
        printf("Error: Failed to open KC705 device\n");
        return -1;
    }
    
    // Get device info
    device_info_t info;
    kc705_get_device_info(device, &info);
    printf("Device: %04X:%04X, PCIe Gen%d x%d\n", 
           info.vendor_id, info.device_id, info.link_speed/2, info.link_width);
    
    // Create test image data
    uint8_t* test_image = malloc(IMAGE_SIZE);
    for (int i = 0; i < IMAGE_SIZE; i++) {
        test_image[i] = rand() % 256;  // Random image data
    }
    
    // Benchmark different scenarios
    int test_counts[] = {1, 10, 100, 1000};
    int num_tests = sizeof(test_counts) / sizeof(test_counts[0]);
    
    printf("\nBenchmark Results:\n");
    printf("Iterations | Avg Latency | Throughput | Total Time\n");
    printf("-----------|-------------|------------|------------\n");
    
    for (int t = 0; t < num_tests; t++) {
        int iterations = test_counts[t];
        
        clock_t start = clock();
        
        for (int i = 0; i < iterations; i++) {
            classification_result_t result;
            kc705_infer(device, test_image, IMAGE_SIZE, &result);
        }
        
        clock_t end = clock();
        double total_time = (double)(end - start) / CLOCKS_PER_SEC;
        double avg_latency = (total_time / iterations) * 1000;  // ms
        double throughput = iterations / total_time;            // FPS
        
        printf("%10d | %8.2f ms | %8.1f FPS | %8.2f s\n", 
               iterations, avg_latency, throughput, total_time);
    }
    
    // Get performance statistics
    performance_stats_t stats;
    kc705_get_performance_stats(device, &stats);
    
    printf("\nCumulative Statistics:\n");
    printf("Total inferences: %llu\n", stats.total_inferences);
    printf("Average FPS: %.1f\n", stats.avg_fps);
    printf("Average latency: %.2f ms\n", stats.avg_latency_ms);
    printf("Errors: %d\n", stats.errors);
    
    free(test_image);
    kc705_close(device);
    return KC705_SUCCESS;
}

//=============================================================================
// Example 5: Directory Processing
//=============================================================================

/**
 * Example: Process all images in a directory from your computer
 */
int example_directory_processing(const char* directory_path) {
    printf("=== KC705 MobileNetV3 Directory Processing Example ===\n");
    printf("Processing directory: %s\n", directory_path);
    
    kc705_device_t* device = kc705_open();
    if (!device) {
        printf("Error: Failed to open KC705 device\n");
        return -1;
    }
    
    // This would normally use directory scanning functions
    // For demonstration, we'll use a hardcoded list
    const char* extensions[] = {".jpg", ".jpeg", ".png", ".bmp"};
    int num_extensions = 4;
    
    printf("Scanning for image files...\n");
    
    // In a real implementation, you would:
    // 1. Scan directory for image files
    // 2. Filter by supported extensions
    // 3. Process each file
    
    // Example hardcoded files (replace with actual directory scan)
    const char* found_files[] = {
        "C:/photos/vacation1.jpg",
        "C:/photos/vacation2.jpg", 
        "C:/photos/vacation3.jpg"
    };
    
    int num_files = sizeof(found_files) / sizeof(found_files[0]);
    classification_result_t* results = malloc(num_files * sizeof(classification_result_t));
    
    printf("Found %d image files\n", num_files);
    
    // Process all files
    int processed = 0;
    for (int i = 0; i < num_files; i++) {
        printf("Processing: %s... ", found_files[i]);
        
        int ret = kc705_infer_file(device, found_files[i], &results[processed]);
        if (ret == KC705_SUCCESS) {
            printf("✓ %s (%.1f%%)\n", 
                   kc705_get_class_name(results[processed].class_id),
                   results[processed].confidence * 100.0);
            processed++;
        } else {
            printf("✗ Error\n");
        }
    }
    
    // Save results to CSV file
    FILE* csv = fopen("classification_results.csv", "w");
    if (csv) {
        fprintf(csv, "Filename,Class_ID,Class_Name,Confidence,Processing_Time_us\n");
        for (int i = 0; i < processed; i++) {
            fprintf(csv, "%s,%d,%s,%.4f,%d\n",
                   found_files[i],
                   results[i].class_id,
                   kc705_get_class_name(results[i].class_id),
                   results[i].confidence,
                   results[i].processing_time_us);
        }
        fclose(csv);
        printf("Results saved to classification_results.csv\n");
    }
    
    free(results);
    kc705_close(device);
    return KC705_SUCCESS;
}

//=============================================================================
// Main Function - Run Examples
//=============================================================================

int main(int argc, char* argv[]) {
    printf("KC705 MobileNetV3 PCIe Interface Examples\n");
    printf("==========================================\n\n");
    
    // Check if KC705 device is available
    kc705_device_t* test_device = kc705_open();
    if (!test_device) {
        printf("Error: No KC705 device found!\n");
        printf("Please ensure:\n");
        printf("1. KC705 board is installed in PCIe slot\n");
        printf("2. FPGA is programmed with MobileNetV3 bitstream\n");
        printf("3. PCIe drivers are installed\n");
        return -1;
    }
    kc705_close(test_device);
    
    printf("KC705 device detected successfully!\n\n");
    
    // Run examples based on command line argument
    if (argc > 1) {
        int example = atoi(argv[1]);
        switch (example) {
            case 1:
                return example_single_image();
            case 2:
                return example_batch_processing();
            case 3:
#ifdef OPENCV_AVAILABLE
                return example_realtime_camera();
#else
                printf("Example 3 requires OpenCV\n");
                return -1;
#endif
            case 4:
                return example_performance_benchmark();
            case 5:
                if (argc > 2) {
                    return example_directory_processing(argv[2]);
                } else {
                    printf("Example 5 requires directory path\n");
                    return -1;
                }
            default:
                printf("Invalid example number\n");
                return -1;
        }
    }
    
    // Run all examples by default
    printf("Running all examples...\n\n");
    
    example_single_image();
    printf("\n");
    
    example_batch_processing();
    printf("\n");
    
    example_performance_benchmark();
    printf("\n");
    
    example_directory_processing("C:/test_images/");
    
    printf("\nAll examples completed!\n");
    return 0;
}

//=============================================================================
// Compilation Instructions
//=============================================================================

/*
To compile these examples:

1. Basic compilation:
   gcc -o kc705_examples example_programs.c kc705_mobilenet_driver.c -lpci

2. With OpenCV (for camera example):
   gcc -o kc705_examples example_programs.c kc705_mobilenet_driver.c -lpci `pkg-config --cflags --libs opencv4` -DOPENCV_AVAILABLE

3. Usage:
   ./kc705_examples          # Run all examples
   ./kc705_examples 1        # Run single image example
   ./kc705_examples 2        # Run batch processing example
   ./kc705_examples 3        # Run camera example (requires OpenCV)
   ./kc705_examples 4        # Run performance benchmark
   ./kc705_examples 5 /path  # Run directory processing

4. Example with your images:
   ./kc705_examples 5 "C:/Users/YourName/Pictures/"
*/