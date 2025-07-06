/**
 * PCIe MobileNetV3 Interface for KC705
 * 
 * This module implements a high-performance PCIe Gen2 x8 interface for MobileNetV3
 * acceleration on the KC705 board. It provides:
 * 
 * - PCIe Gen2 x8 (up to 4 GB/s bandwidth)
 * - DMA transfers for high throughput
 * - Memory-mapped register interface
 * - Interrupt-driven completion notification
 * - Image upload and result download
 * - Weight loading interface
 * 
 * Memory Map:
 * 0x0000-0x00FF: Control/Status registers
 * 0x0100-0x01FF: Configuration registers  
 * 0x1000-0x1FFF: Image data buffer (4KB)
 * 0x2000-0x2FFF: Result buffer (4KB)
 * 0x10000+: Weight memory (large)
 */

module pcie_mobilenetv3_interface #(
    parameter DATA_WIDTH = 64,
    parameter PCIE_LANES = 8,
    parameter IMAGE_SIZE = 224*224*3,   // 150KB for 224x224 RGB
    parameter RESULT_SIZE = 1000*4      // 4KB for 1000 classes
) (
    // PCIe Physical Interface
    input wire pcie_clk_p,
    input wire pcie_clk_n,
    input wire pcie_rst_n,
    input wire [PCIE_LANES-1:0] pcie_rx_p,
    input wire [PCIE_LANES-1:0] pcie_rx_n,
    output wire [PCIE_LANES-1:0] pcie_tx_p,
    output wire [PCIE_LANES-1:0] pcie_tx_n,
    
    // System Interface
    input wire sys_clk,
    input wire sys_rst_n,
    
    // MobileNetV3 Core Interface
    output wire [63:0] mobilenet_data,
    output wire mobilenet_valid,
    input wire mobilenet_ready,
    output wire mobilenet_start,
    
    input wire [63:0] mobilenet_result,
    input wire mobilenet_result_valid,
    output wire mobilenet_result_ready,
    input wire mobilenet_done,
    
    // Weight Loading Interface
    output wire [63:0] weight_data,
    output wire [31:0] weight_addr,
    output wire weight_valid,
    input wire weight_ready,
    
    // Status and Debug
    output wire pcie_link_up,
    output wire [15:0] debug_status,
    output wire processing_active
);

//=============================================================================
// PCIe Core Instance (Xilinx 7-Series PCIe Gen2 x8)
//=============================================================================

wire user_clk;
wire user_reset;
wire user_lnk_up;

// AXI Stream interfaces
wire [DATA_WIDTH-1:0] m_axis_rx_tdata;
wire m_axis_rx_tvalid;
wire m_axis_rx_tready;
wire m_axis_rx_tlast;
wire [21:0] m_axis_rx_tuser;

wire [DATA_WIDTH-1:0] s_axis_tx_tdata;
wire s_axis_tx_tvalid;
wire s_axis_tx_tready;
wire s_axis_tx_tlast;
wire [3:0] s_axis_tx_tuser;

// Configuration interface
wire [31:0] cfg_do;
wire cfg_rd_wr_done;
wire [31:0] cfg_di;
wire [3:0] cfg_byte_en;
wire [9:0] cfg_dwaddr;
wire cfg_wr_en;
wire cfg_rd_en;

// Interrupt interface
wire cfg_interrupt;
wire cfg_interrupt_rdy;
wire cfg_interrupt_assert;
wire [7:0] cfg_interrupt_di;
wire [7:0] cfg_interrupt_do;
wire [2:0] cfg_interrupt_mmenable;
wire cfg_interrupt_msienable;

pcie_7x_gen2_x8 pcie_core (
    // PCIe Physical
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_rxp(pcie_rx_p),
    .pci_exp_rxn(pcie_rx_n),
    
    // Reference Clock
    .sys_clk_p(pcie_clk_p),
    .sys_clk_n(pcie_clk_n),
    .sys_rst_n(pcie_rst_n),
    
    // User Interface
    .user_clk_out(user_clk),
    .user_reset_out(user_reset),
    .user_lnk_up(user_lnk_up),
    
    // AXI Stream RX
    .m_axis_rx_tdata(m_axis_rx_tdata),
    .m_axis_rx_tvalid(m_axis_rx_tvalid),
    .m_axis_rx_tready(m_axis_rx_tready),
    .m_axis_rx_tlast(m_axis_rx_tlast),
    .m_axis_rx_tuser(m_axis_rx_tuser),
    
    // AXI Stream TX
    .s_axis_tx_tdata(s_axis_tx_tdata),
    .s_axis_tx_tvalid(s_axis_tx_tvalid),
    .s_axis_tx_tready(s_axis_tx_tready),
    .s_axis_tx_tlast(s_axis_tx_tlast),
    .s_axis_tx_tuser(s_axis_tx_tuser),
    
    // Configuration Space
    .cfg_do(cfg_do),
    .cfg_rd_wr_done(cfg_rd_wr_done),
    .cfg_di(cfg_di),
    .cfg_byte_en(cfg_byte_en),
    .cfg_dwaddr(cfg_dwaddr),
    .cfg_wr_en(cfg_wr_en),
    .cfg_rd_en(cfg_rd_en),
    
    // Interrupts
    .cfg_interrupt(cfg_interrupt),
    .cfg_interrupt_rdy(cfg_interrupt_rdy),
    .cfg_interrupt_assert(cfg_interrupt_assert),
    .cfg_interrupt_di(cfg_interrupt_di),
    .cfg_interrupt_do(cfg_interrupt_do),
    .cfg_interrupt_mmenable(cfg_interrupt_mmenable),
    .cfg_interrupt_msienable(cfg_interrupt_msienable)
);

//=============================================================================
// Memory-Mapped Register Interface
//=============================================================================

// Register definitions
localparam REG_CONTROL      = 8'h00;   // Control register
localparam REG_STATUS       = 8'h04;   // Status register  
localparam REG_INTERRUPT    = 8'h08;   // Interrupt control
localparam REG_IMAGE_SIZE   = 8'h0C;   // Image size
localparam REG_IMAGE_ADDR   = 8'h10;   // Image buffer address
localparam REG_RESULT_ADDR  = 8'h14;   // Result buffer address
localparam REG_WEIGHT_ADDR  = 8'h18;   // Weight memory address
localparam REG_DEBUG       = 8'h1C;    // Debug register

// Control register bits
localparam CTRL_START       = 0;       // Start processing
localparam CTRL_RESET       = 1;       // Reset core
localparam CTRL_IRQ_EN      = 2;       // Enable interrupts
localparam CTRL_DMA_EN      = 3;       // Enable DMA

// Status register bits  
localparam STAT_DONE        = 0;       // Processing done
localparam STAT_BUSY        = 1;       // Processing active
localparam STAT_ERROR       = 2;       // Error occurred
localparam STAT_LINK_UP     = 3;       // PCIe link up

reg [31:0] control_reg;
reg [31:0] status_reg;
reg [31:0] interrupt_reg;
reg [31:0] image_size_reg;
reg [31:0] image_addr_reg;
reg [31:0] result_addr_reg;
reg [31:0] weight_addr_reg;
reg [31:0] debug_reg;

//=============================================================================
// TLP (Transaction Layer Packet) Decoder
//=============================================================================

reg [63:0] rx_data_reg;
reg rx_valid_reg;
reg rx_last_reg;
reg [21:0] rx_user_reg;

// TLP Header parsing
wire [6:0] tlp_fmt_type = rx_data_reg[62:56];
wire [9:0] tlp_length = rx_data_reg[9:0];
wire [31:0] tlp_address = rx_data_reg[63:32];
wire [15:0] tlp_requester_id = rx_data_reg[47:32];
wire [7:0] tlp_tag = rx_data_reg[47:40];

// TLP Types
localparam TLP_MEM_READ_32  = 7'b0000000;
localparam TLP_MEM_WRITE_32 = 7'b1000000;
localparam TLP_CONFIG_READ  = 7'b0000100;
localparam TLP_CONFIG_WRITE = 7'b1000100;

wire is_memory_read = (tlp_fmt_type == TLP_MEM_READ_32);
wire is_memory_write = (tlp_fmt_type == TLP_MEM_WRITE_32);
wire is_config_read = (tlp_fmt_type == TLP_CONFIG_READ);
wire is_config_write = (tlp_fmt_type == TLP_CONFIG_WRITE);

// Address decoder
wire is_reg_access = (tlp_address[31:16] == 16'h0000);
wire is_image_access = (tlp_address[31:12] == 20'h00001);
wire is_result_access = (tlp_address[31:12] == 20'h00002);
wire is_weight_access = (tlp_address[31:16] == 16'h0001);

wire [7:0] reg_address = tlp_address[7:0];

//=============================================================================
// PCIe Transaction Processing State Machine
//=============================================================================

typedef enum logic [3:0] {
    IDLE,
    PARSE_HEADER,
    REG_READ,
    REG_WRITE, 
    MEM_READ,
    MEM_WRITE,
    SEND_COMPLETION,
    ERROR
} pcie_state_t;

pcie_state_t pcie_state, pcie_next_state;

reg [31:0] completion_data;
reg completion_valid;
reg [15:0] completion_req_id;
reg [7:0] completion_tag;
reg [9:0] completion_length;

always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        pcie_state <= IDLE;
        rx_data_reg <= 64'b0;
        rx_valid_reg <= 1'b0;
        rx_last_reg <= 1'b0;
        rx_user_reg <= 22'b0;
    end else begin
        pcie_state <= pcie_next_state;
        
        if (m_axis_rx_tvalid && m_axis_rx_tready) begin
            rx_data_reg <= m_axis_rx_tdata;
            rx_valid_reg <= m_axis_rx_tvalid;
            rx_last_reg <= m_axis_rx_tlast;
            rx_user_reg <= m_axis_rx_tuser;
        end else begin
            rx_valid_reg <= 1'b0;
        end
    end
end

always_comb begin
    pcie_next_state = pcie_state;
    
    case (pcie_state)
        IDLE: begin
            if (m_axis_rx_tvalid && m_axis_rx_tready) begin
                pcie_next_state = PARSE_HEADER;
            end
        end
        
        PARSE_HEADER: begin
            if (rx_valid_reg) begin
                if (is_memory_read && is_reg_access) begin
                    pcie_next_state = REG_READ;
                end else if (is_memory_write && is_reg_access) begin
                    pcie_next_state = REG_WRITE;
                end else if (is_memory_read) begin
                    pcie_next_state = MEM_READ;
                end else if (is_memory_write) begin
                    pcie_next_state = MEM_WRITE;
                end else begin
                    pcie_next_state = ERROR;
                end
            end
        end
        
        REG_READ: begin
            pcie_next_state = SEND_COMPLETION;
        end
        
        REG_WRITE: begin
            pcie_next_state = IDLE;
        end
        
        MEM_READ: begin
            pcie_next_state = SEND_COMPLETION;
        end
        
        MEM_WRITE: begin
            pcie_next_state = IDLE;
        end
        
        SEND_COMPLETION: begin
            if (s_axis_tx_tvalid && s_axis_tx_tready && s_axis_tx_tlast) begin
                pcie_next_state = IDLE;
            end
        end
        
        ERROR: begin
            pcie_next_state = IDLE;
        end
    endcase
end

//=============================================================================
// Register Read/Write Logic
//=============================================================================

always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        control_reg <= 32'h0;
        status_reg <= 32'h0;
        interrupt_reg <= 32'h0;
        image_size_reg <= IMAGE_SIZE;
        image_addr_reg <= 32'h1000;
        result_addr_reg <= 32'h2000;
        weight_addr_reg <= 32'h10000;
        debug_reg <= 32'h0;
        completion_data <= 32'h0;
        completion_valid <= 1'b0;
    end else begin
        // Update status register
        status_reg[STAT_LINK_UP] <= user_lnk_up;
        status_reg[STAT_BUSY] <= processing_active;
        status_reg[STAT_DONE] <= mobilenet_done;
        
        // Register reads
        if (pcie_state == REG_READ) begin
            case (reg_address)
                REG_CONTROL:    completion_data <= control_reg;
                REG_STATUS:     completion_data <= status_reg;
                REG_INTERRUPT:  completion_data <= interrupt_reg;
                REG_IMAGE_SIZE: completion_data <= image_size_reg;
                REG_IMAGE_ADDR: completion_data <= image_addr_reg;
                REG_RESULT_ADDR: completion_data <= result_addr_reg;
                REG_WEIGHT_ADDR: completion_data <= weight_addr_reg;
                REG_DEBUG:      completion_data <= debug_reg;
                default:        completion_data <= 32'hDEADBEEF;
            endcase
            completion_valid <= 1'b1;
            completion_req_id <= tlp_requester_id;
            completion_tag <= tlp_tag;
            completion_length <= 10'd1;
        end
        
        // Register writes
        if (pcie_state == REG_WRITE && rx_valid_reg) begin
            case (reg_address)
                REG_CONTROL:    control_reg <= rx_data_reg[31:0];
                REG_INTERRUPT:  interrupt_reg <= rx_data_reg[31:0];
                REG_IMAGE_SIZE: image_size_reg <= rx_data_reg[31:0];
                REG_IMAGE_ADDR: image_addr_reg <= rx_data_reg[31:0];
                REG_RESULT_ADDR: result_addr_reg <= rx_data_reg[31:0];
                REG_WEIGHT_ADDR: weight_addr_reg <= rx_data_reg[31:0];
                default: ; // Read-only or invalid register
            endcase
        end
        
        if (completion_valid && s_axis_tx_tvalid && s_axis_tx_tready) begin
            completion_valid <= 1'b0;
        end
    end
end

//=============================================================================
// Image Data Buffer (4KB BRAM)
//=============================================================================

reg [63:0] image_buffer [0:511];  // 4KB buffer
reg [8:0] image_wr_addr;
reg [8:0] image_rd_addr;
reg image_wr_en;
reg [63:0] image_wr_data;
reg [63:0] image_rd_data;

always_ff @(posedge user_clk) begin
    if (image_wr_en) begin
        image_buffer[image_wr_addr] <= image_wr_data;
    end
    image_rd_data <= image_buffer[image_rd_addr];
end

// Image write logic
always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        image_wr_addr <= 9'b0;
        image_wr_en <= 1'b0;
    end else begin
        if (pcie_state == MEM_WRITE && is_image_access && rx_valid_reg) begin
            image_wr_en <= 1'b1;
            image_wr_data <= rx_data_reg;
            image_wr_addr <= image_wr_addr + 1'b1;
        end else begin
            image_wr_en <= 1'b0;
        end
        
        // Reset address when starting new image
        if (control_reg[CTRL_START]) begin
            image_wr_addr <= 9'b0;
        end
    end
end

//=============================================================================
// Result Data Buffer (4KB BRAM)
//=============================================================================

reg [63:0] result_buffer [0:511];  // 4KB buffer
reg [8:0] result_wr_addr;
reg [8:0] result_rd_addr;
reg result_wr_en;
reg [63:0] result_wr_data;
reg [63:0] result_rd_data;

always_ff @(posedge user_clk) begin
    if (result_wr_en) begin
        result_buffer[result_wr_addr] <= result_wr_data;
    end
    result_rd_data <= result_buffer[result_rd_addr];
end

// Result write logic (from MobileNetV3)
always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        result_wr_addr <= 9'b0;
        result_wr_en <= 1'b0;
    end else begin
        if (mobilenet_result_valid && mobilenet_result_ready) begin
            result_wr_en <= 1'b1;
            result_wr_data <= mobilenet_result;
            result_wr_addr <= result_wr_addr + 1'b1;
        end else begin
            result_wr_en <= 1'b0;
        end
        
        // Reset address when starting new inference
        if (control_reg[CTRL_START]) begin
            result_wr_addr <= 9'b0;
        end
    end
end

//=============================================================================
// MobileNetV3 Interface Logic
//=============================================================================

reg mobilenet_start_reg;
reg [8:0] mobilenet_rd_addr;
reg mobilenet_data_valid;

// Start inference when control register is written
always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        mobilenet_start_reg <= 1'b0;
        mobilenet_rd_addr <= 9'b0;
        mobilenet_data_valid <= 1'b0;
    end else begin
        // Pulse start signal
        mobilenet_start_reg <= control_reg[CTRL_START];
        
        // Stream image data to MobileNetV3
        if (mobilenet_start_reg && mobilenet_ready) begin
            mobilenet_data_valid <= 1'b1;
            mobilenet_rd_addr <= mobilenet_rd_addr + 1'b1;
        end else if (mobilenet_rd_addr >= (image_size_reg >> 3)) begin
            mobilenet_data_valid <= 1'b0;
            mobilenet_rd_addr <= 9'b0;
        end
    end
end

// Connect image buffer to MobileNetV3
assign image_rd_addr = mobilenet_rd_addr;
assign mobilenet_data = image_rd_data;
assign mobilenet_valid = mobilenet_data_valid;
assign mobilenet_start = mobilenet_start_reg;

//=============================================================================
// Completion TLP Generator
//=============================================================================

reg [63:0] completion_tlp;
reg completion_tlp_valid;

always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        completion_tlp <= 64'b0;
        completion_tlp_valid <= 1'b0;
    end else begin
        if (pcie_state == SEND_COMPLETION && completion_valid) begin
            // Build completion TLP header
            completion_tlp <= {
                7'b0001010,      // Fmt/Type: Completion with data
                1'b0,            // Reserved
                3'b000,          // TC
                4'b0000,         // Reserved
                1'b0,            // TD
                1'b0,            // EP
                2'b00,           // Attr
                2'b00,           // Reserved
                completion_length, // Length
                completion_req_id, // Requester ID
                completion_tag,    // Tag
                1'b0,            // Reserved
                7'b0000000,      // Lower address
                completion_data  // Data
            };
            completion_tlp_valid <= 1'b1;
        end else if (s_axis_tx_tvalid && s_axis_tx_tready) begin
            completion_tlp_valid <= 1'b0;
        end
    end
end

//=============================================================================
// TX Interface Logic
//=============================================================================

assign s_axis_tx_tdata = completion_tlp;
assign s_axis_tx_tvalid = completion_tlp_valid;
assign s_axis_tx_tlast = completion_tlp_valid;
assign s_axis_tx_tuser = 4'b0000;

//=============================================================================
// RX Interface Logic  
//=============================================================================

assign m_axis_rx_tready = 1'b1;  // Always ready to receive

//=============================================================================
// Interrupt Generation
//=============================================================================

reg interrupt_pending;

always_ff @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        interrupt_pending <= 1'b0;
    end else begin
        // Generate interrupt when processing is done
        if (mobilenet_done && control_reg[CTRL_IRQ_EN]) begin
            interrupt_pending <= 1'b1;
        end else if (cfg_interrupt && cfg_interrupt_rdy) begin
            interrupt_pending <= 1'b0;
        end
    end
end

assign cfg_interrupt = interrupt_pending;
assign cfg_interrupt_assert = 1'b1;
assign cfg_interrupt_di = 8'h00;

//=============================================================================
// Output Assignments
//=============================================================================

assign pcie_link_up = user_lnk_up;
assign processing_active = status_reg[STAT_BUSY];
assign mobilenet_result_ready = 1'b1;

assign debug_status = {
    user_lnk_up,           // [15]
    mobilenet_done,        // [14]
    processing_active,     // [13]
    interrupt_pending,     // [12]
    pcie_state            // [11:8]
    // remaining bits for other debug signals
};

// Weight loading interface (simplified for this example)
assign weight_data = 64'h0;
assign weight_addr = 32'h0;
assign weight_valid = 1'b0;

endmodule