# KC705 PCIe Setup Guide - Read Data from Your Computer

## 🚀 Quick Start: Get Your Images Processed in 30 Minutes

### **Step 1: Hardware Setup (5 minutes)**

1. **Install KC705 in PCIe Slot**
   ```
   Power Off Computer → Install KC705 in PCIe x8 slot → Power On
   ```

2. **Connect Power**
   - Connect 12V power adapter to KC705
   - Power on KC705 (green LED should light up)

3. **Verify Detection**
   ```bash
   # Linux
   lspci | grep Xilinx
   # Should show: 10ee:7024 Xilinx Corporation
   
   # Windows
   Device Manager → System devices → Look for Xilinx device
   ```

### **Step 2: Program FPGA (10 minutes)**

1. **Generate Bitstream in Vivado**
   ```tcl
   # In Vivado
   open_project kc705_mobilenetv3.xpr
   launch_runs impl_1 -to_step write_bitstream
   wait_on_run impl_1
   ```

2. **Program FPGA**
   ```tcl
   # Program via JTAG
   open_hw_manager
   connect_hw_server
   program_hw_devices -bitstream mobilenetv3_kc705.bit
   ```

3. **Verify Programming**
   - LED1 should turn ON (DDR3 calibrated)
   - LED2 should turn ON (clocks locked)

### **Step 3: Install Driver (5 minutes)**

1. **Compile Driver**
   ```bash
   gcc -o kc705_test example_programs.c kc705_mobilenet_driver.c -lpci
   ```

2. **Test Connection**
   ```bash
   ./kc705_test
   # Should output: "KC705 device detected successfully!"
   ```

### **Step 4: Run Your First Inference (10 minutes)**

1. **Single Image Test**
   ```c
   // test_single_image.c
   #include "kc705_mobilenet_driver.h"
   
   int main() {
       // Open device
       kc705_device_t* device = kc705_open();
       
       // Classify your image
       classification_result_t result;
       kc705_infer_file(device, "C:/your_image.jpg", &result);
       
       // Print result
       printf("Result: %s (%.1f%% confidence)\n", 
              kc705_get_class_name(result.class_id),
              result.confidence * 100.0);
       
       kc705_close(device);
       return 0;
   }
   ```

2. **Compile and Run**
   ```bash
   gcc -o test test_single_image.c kc705_mobilenet_driver.c -lpci
   ./test
   ```

## 📂 **Reading Data from Your Computer**

### **Method 1: Single Image**
```c
// Read any image from your computer
kc705_infer_file(device, "C:/Users/YourName/Documents/photo.jpg", &result);
```

### **Method 2: Batch Processing**
```c
// Process multiple images from your folders
const char* my_images[] = {
    "C:/Photos/vacation1.jpg",
    "C:/Photos/vacation2.jpg", 
    "C:/Photos/vacation3.jpg"
};
kc705_infer_batch(device, my_images, 3, results);
```

### **Method 3: Real-time Camera**
```c
// Process live camera feed from your computer
cv::VideoCapture cap(0);  // Your webcam
while (true) {
    cap >> frame;
    kc705_infer(device, frame.data, 224*224*3, &result);
    // Display result on screen
}
```

### **Method 4: Directory Processing**
```c
// Process entire folders of images
kc705_infer_batch_directory(device, "C:/Users/YourName/Pictures/", results);
```

## 🔧 **Memory Map - How Data Flows**

```
Your Computer              KC705 Board
┌─────────────┐           ┌─────────────┐
│ Your Images │──PCIe────▶│ Image Buffer│
│ (Any Format)│           │ (4KB BRAM)  │
└─────────────┘           └─────────────┘
                                  │
                          ┌─────────────┐
                          │ MobileNetV3 │
                          │ Processing  │
                          └─────────────┘
                                  │
┌─────────────┐           ┌─────────────┐
│ Results on  │◀──PCIe────│Result Buffer│
│ Your Screen │           │ (4KB BRAM)  │
└─────────────┘           └─────────────┘
```

**Address Map:**
- `0x0000-0x00FF`: Control registers
- `0x1000-0x1FFF`: Your image data (uploaded from computer)
- `0x2000-0x2FFF`: Classification results (downloaded to computer)

## 💻 **Example Use Cases**

### **1. Photo Album Classification**
```bash
./kc705_examples 5 "C:/Users/YourName/Photos/"
# Classifies all photos in your photo album
# Saves results to CSV file
```

### **2. Real-time Object Detection**
```bash
./kc705_examples 3
# Uses your webcam for real-time classification
# Shows results on screen in real-time
```

### **3. Performance Testing**
```bash
./kc705_examples 4
# Benchmarks performance with your images
# Shows FPS and latency statistics
```

## 📊 **Expected Performance**

| Use Case | Data Transfer | Latency | Throughput |
|----------|---------------|---------|------------|
| **Single Image** | Your PC → KC705 | 15-25 ms | 40-60 FPS |
| **Batch Processing** | Multiple files | 10-15 ms | 60-100 FPS |
| **Real-time Camera** | Live video stream | <20 ms | 50+ FPS |
| **Directory Scan** | Folder of images | 12-18 ms | 55-80 FPS |

## 🛠 **Troubleshooting**

### **Device Not Detected**
```bash
# Check PCIe connection
lspci | grep 10ee
# Should show: 10ee:7024

# Check power
# LED0 on KC705 should be ON
```

### **Programming Failed**
```bash
# Verify JTAG connection
vivado -mode tcl
open_hw_manager
connect_hw_server
# Should detect KC705
```

### **Driver Issues**
```bash
# Check permissions
sudo ./kc705_test

# Install PCI development libraries
sudo apt-get install libpci-dev  # Ubuntu
sudo yum install pciutils-devel  # CentOS
```

### **Performance Issues**
```c
// Check status
uint32_t status = kc705_read_reg(device, REG_STATUS);
printf("Status: 0x%08X\n", status);

// Should show:
// Bit 0: Processing done
// Bit 1: Not busy
// Bit 2: No error
// Bit 3: PCIe link up
```

## 🎯 **Quick Test Commands**

```bash
# Test 1: Device detection
./kc705_examples
# Should output: "KC705 device detected successfully!"

# Test 2: Single image classification
./kc705_examples 1
# Processes a single image file

# Test 3: Performance benchmark  
./kc705_examples 4
# Shows latency and throughput metrics

# Test 4: Process your photos
./kc705_examples 5 "/path/to/your/photos/"
# Classifies all images in your directory
```

## 📈 **Monitoring Performance**

```c
// Get real-time statistics
performance_stats_t stats;
kc705_get_performance_stats(device, &stats);

printf("Total processed: %llu images\n", stats.total_inferences);
printf("Average FPS: %.1f\n", stats.avg_fps);
printf("Average latency: %.2f ms\n", stats.avg_latency_ms);
```

## ✅ **Success Indicators**

When everything is working correctly:

1. **Hardware**: 
   - KC705 LEDs 0,1,2 are ON
   - `lspci` shows Xilinx device

2. **Software**: 
   - `kc705_open()` returns valid device handle
   - Status register shows `0x0000000F` (all good)

3. **Performance**: 
   - Latency < 25ms per image
   - Throughput > 40 FPS
   - No errors in debug status

**You're now ready to process your images with hardware-accelerated MobileNetV3 on KC705!**

The system reads data directly from your computer's files, camera, or any data source via the high-speed PCIe interface, processes it on the FPGA hardware, and returns results back to your computer for display or storage.