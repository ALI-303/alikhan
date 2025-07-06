# OV7670 Camera Integration with KC705 FPGA Board

## Overview

This guide provides a complete implementation of OV7670 camera integration with the Xilinx KC705 evaluation board (Kintex-7 XC7K325T). The KC705 offers more resources than typical development boards, allowing for full VGA resolution capture and advanced features.

## KC705 Board Specifications

- **FPGA**: Kintex-7 XC7K325T-2FFG900C
- **Block RAM**: 445 x 36Kb blocks (16.0 Mb total)
- **Clock Resources**: Multiple PLLs and MMCMs
- **I/O**: 500 user I/O pins
- **Voltage**: 3.3V, 2.5V, 1.8V, 1.5V, 1.2V I/O standards
- **Connectors**: FMC (FPGA Mezzanine Card), SMA, GPIO

## Hardware Connection Plan

### KC705 GPIO Connector Pinout
The KC705 has dedicated GPIO headers that we'll use for camera connection:

```
OV7670 Pin    →    KC705 GPIO Pin    →    FPGA Pin
------------------------------------------------
D0            →    GPIO_DIP_SW0       →    Y29
D1            →    GPIO_DIP_SW1       →    W29  
D2            →    GPIO_DIP_SW2       →    AA28
D3            →    GPIO_DIP_SW3       →    Y28
D4            →    GPIO_LED_0         →    AB8
D5            →    GPIO_LED_1         →    AA8
D6            →    GPIO_LED_2         →    AC9
D7            →    GPIO_LED_3         →    AB9
PCLK          →    USER_CLOCK_P       →    AD12 (Clock capable)
HREF          →    GPIO_LED_4         →    AE26
VSYNC         →    GPIO_LED_5         →    G19
XCLK          →    GPIO_LED_6         →    E19
SIOC (SCL)    →    GPIO_LED_7         →    F20
SIOD (SDA)    →    GPIO_SW_N          →    G12
RESET         →    GPIO_SW_S          →    AC16
PWDN          →    GPIO_SW_W          →    AC17
VCC           →    3.3V (P3V3)        →    Power
GND           →    GND                →    Ground
```

### Pull-up Resistors
- 4.7kΩ resistor: SIOC to 3.3V  
- 4.7kΩ resistor: SIOD to 3.3V

## Project Structure

```
KC705_OV7670/
├── src/
│   ├── kc705_ov7670_top.v           # Top-level module
│   ├── ov7670_controller.v          # SCCB/I2C controller  
│   ├── ov7670_capture.v             # Camera data capture
│   ├── ov7670_registers.v           # Register configuration
│   ├── vga_controller.v             # VGA timing controller
│   ├── frame_buffer_controller.v    # Frame buffer management
│   ├── vga_display_gen.v            # VGA display generator
│   ├── reset_generator.v            # Reset synchronization
│   └── uart_debug_tx.v              # Debug UART transmitter
├── constraints/
│   └── kc705_ov7670.xdc             # Pin and timing constraints
├── scripts/
│   └── build_kc705.tcl              # Vivado build script
├── ip/
│   ├── clk_wiz_0.xci                # Clock wizard IP
│   ├── frame_buffer_bram.xci        # Block RAM IP
│   └── ila_0.xci                    # ILA for debugging
└── reports/
    └── (Generated timing and utilization reports)
```

## Key Features

### 🎯 **Full Resolution Support**
- **VGA Resolution**: 640x480 @ 30fps full capture
- **Dual Frame Buffers**: Ping-pong operation for smooth video
- **RGB565 Format**: 16-bit color depth with conversion to 8-bit RGB

### 🔧 **Advanced Memory Management**
- **620KB Block RAM**: Utilizes KC705's abundant memory resources
- **Clock Domain Crossing**: Proper synchronization between camera and VGA domains
- **Address Scaling**: Support for different capture and display modes

### 📡 **Multiple Display Modes**
- **Normal Display**: Direct camera output
- **Monochrome**: Luminance-based grayscale
- **Edge Detection**: Real-time edge detection
- **False Color**: Channel swapping for analysis
- **Test Patterns**: Built-in test pattern generation

### 🎛️ **User Controls**
- **DIP Switches**: Capture and display mode selection
- **Push Buttons**: Test pattern enable, capture control
- **LED Indicators**: Status and debug information
- **UART Debug**: Serial debug output at 115200 baud

## Implementation Details

### Clock Architecture
```
200 MHz LVDS Input → Clock Wizard → 100 MHz (System)
                                 → 25 MHz (VGA)
                                 → 24 MHz (Camera)
Camera PCLK (async) → Direct capture domain
```

### Memory Architecture
```
Camera → Capture → Frame Buffer 0/1 → VGA Display
         (PCLK)    (Dual-port BRAM)     (25 MHz)
```

### Control Interface
```
DIP SW[1:0]: Display Mode (00=Normal, 01=Mono, 10=Edge, 11=False)
DIP SW[3:2]: Capture Mode (00=VGA, 01=QVGA, 10=CIF, 11=QCIF)
SW_N: Test Pattern Enable
SW_S: Capture Enable (active low)
```

## Build Instructions

### Prerequisites
- Xilinx Vivado 2019.2 or later
- KC705 evaluation board
- OV7670 camera module
- VGA monitor and cable
- 4.7kΩ resistors (2x)
- Jumper wires

### Hardware Setup
1. **Connect Pull-up Resistors**:
   - Solder 4.7kΩ from SIOC to 3.3V
   - Solder 4.7kΩ from SIOD to 3.3V

2. **Wire Camera to KC705**:
   - Use the pin mapping table above
   - Ensure all connections are secure
   - Double-check power connections (3.3V)

3. **Connect VGA Output**:
   - Use FMC connector for VGA breakout
   - Connect to VGA monitor

### Software Build
1. **Clone/Download Files**:
   ```bash
   mkdir KC705_OV7670
   cd KC705_OV7670
   # Copy all .v and .xdc files to this directory
   ```

2. **Run Build Script**:
   ```bash
   vivado -mode batch -source build_kc705.tcl
   ```

3. **Program FPGA**:
   ```bash
   # Connect KC705 and power on
   # Use Vivado Hardware Manager or:
   vivado -mode batch -source program.tcl
   ```

### Expected Resource Utilization
```
Resource      Used    Available   Utilization
LUTs          8,500   203,800     4.17%
FFs           12,000  407,600     2.94%
BRAM          170     445         38.20%
DSPs          8       840         0.95%
```

## Operation and Testing

### Power-On Sequence
1. **LED Status Check**:
   - LED[7]: Clock locked indicator
   - LED[1]: Camera configuration complete
   - LED[0]: Configuration finished
   - LED[3]: Frame capture indicator

2. **Test Pattern Verification**:
   - Set SW_N to enable test pattern
   - Should see color gradient with crosshair
   - Verify VGA timing is correct

3. **Camera Operation**:
   - Release SW_N for camera mode
   - Set SW_S low to enable capture
   - Adjust DIP switches for different modes

### Debug Features

#### UART Debug Output (115200 baud)
```
STAT: R F:01A3
STAT: R F:01A4
STAT: R F:01A5
```
- `R`: Camera ready, `N`: Not ready
- `F:xxxx`: Frame counter in hex

#### ILA Debug Signals
- Camera data bus monitoring
- Synchronization signal analysis
- Frame buffer write operations
- Timing violation detection

### Troubleshooting

#### No VGA Output
1. Check VGA cable connections
2. Verify monitor supports 640x480@60Hz
3. Check clock wizard lock status (LED[7])
4. Enable test pattern to verify VGA path

#### No Camera Data
1. Verify camera power (3.3V)
2. Check SCCB pull-up resistors
3. Monitor UART debug output
4. Use ILA to check PCLK and data signals

#### Corrupted Image
1. Check PCLK timing constraints
2. Verify frame buffer addressing
3. Monitor camera synchronization signals
4. Check for clock domain crossing issues

## Advanced Features

### Digital Zoom Implementation
The system supports 2x digital zoom by cropping the center portion:
```verilog
// In address_scaler module
scaled_x <= (x_coord >> 1) + 160;  // Center crop
scaled_y <= (y_coord >> 1) + 120;
```

### Real-time Image Processing
Basic edge detection is implemented:
```verilog
function [7:0] edge_detect_output;
    input [7:0] red, green, blue;
    reg [7:0] luminance;
    begin
        luminance = (red >> 2) + (green >> 1) + (blue >> 3);
        edge_detect_output = (luminance > 8'h80) ? 8'hFF : 8'h00;
    end
endfunction
```

## Performance Characteristics

### Timing Performance
- **Camera Interface**: 25 MHz max PCLK support
- **VGA Output**: Standard 640x480@60Hz timing
- **Frame Rate**: 30 fps with full resolution
- **Latency**: ~2 frame periods (ping-pong buffering)

### Memory Bandwidth
- **Write Bandwidth**: 400 MB/s (25 MHz × 16 bits)
- **Read Bandwidth**: 200 MB/s (25 MHz × 8 bits × 3 channels)
- **Total Memory**: 1.2 MB (dual 640x480x16-bit buffers)

## Future Enhancements

### Possible Upgrades
1. **DDR3 Interface**: Use external memory for multiple frame storage
2. **Image Processing**: Add histogram equalization, color correction
3. **Compression**: Implement JPEG compression
4. **Ethernet Interface**: Stream video over network
5. **Multiple Cameras**: Support for stereo vision

### Performance Optimizations
1. **Pipeline Optimization**: Reduce latency with deeper pipelines
2. **Memory Access**: Optimize burst transfers
3. **Clock Optimization**: Higher frequency operation
4. **Resource Sharing**: Efficient use of DSP blocks for image processing

## Conclusion

This implementation provides a robust, full-featured OV7670 camera interface for the KC705 FPGA board. The design demonstrates proper clock domain crossing, memory management, and real-time video processing capabilities. The modular architecture makes it easy to extend with additional features and optimizations.

The project serves as an excellent foundation for computer vision applications, real-time image processing research, and FPGA-based video systems development.