
// -----------------------------------------------------------------------------
// Project:      OBI Tutorial
// Company:      AICLAB
//
// Simple OBI Slave - Tutorial Implementation
//
// High-performance pipelined OBI slave with immediate combinational responses.
// Optimized for clarity and educational value while maintaining full functionality.
//
// Features:
//   - Immediate single-cycle responses for both reads and writes
//   - Full pipelining support with continuous request acceptance
//   - Simple, clear logic flow without complex state machines
//   - Educational focus with separated concerns for easy understanding
//
// OBI Protocol Support:
//   - Core signals: req/gnt, addr, we, be, wdata, rvalid, rdata, err
//   - Always-grant policy for maximum throughput
//   - Proper error handling for out-of-bounds accesses
// -----------------------------------------------------------------------------

module obi_slave_custom
#(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned MEM_SIZE = 1024  // Memory size in bytes
) (
    input  logic clk_i,
    input  logic rst_ni,

    // OBI interface
    input  logic                    obi_req_i,
    output logic                    obi_gnt_o,
    input  logic [ADDR_WIDTH-1:0]   obi_addr_i,
    input  logic                    obi_we_i,
    input  logic [DATA_WIDTH/8-1:0] obi_be_i,
    input  logic [DATA_WIDTH-1:0]   obi_wdata_i,

    output logic                    obi_rvalid_o,
    output logic [DATA_WIDTH-1:0]   obi_rdata_o,
    output logic                    obi_err_o
);

    // Memory array
    logic [7:0] memory [0:MEM_SIZE-1];

    // Response registers
    logic [DATA_WIDTH-1:0] rdata_q;
    logic                  rvalid_q;
    logic                  err_q;

    // Address validation
    logic addr_valid;
    assign addr_valid = (obi_addr_i <= MEM_SIZE - 4);  // Ensure 32-bit word fits

    // Always grant requests for maximum performance
    assign obi_gnt_o = 1'b1;

    // Output assignments
    assign obi_rvalid_o = rvalid_q;
    assign obi_rdata_o  = rdata_q;
    assign obi_err_o    = err_q;

    // Combinational read logic
    logic [DATA_WIDTH-1:0] read_data;
    always_comb begin
        if (addr_valid) begin
            read_data = {memory[obi_addr_i + 3], 
                        memory[obi_addr_i + 2], 
                        memory[obi_addr_i + 1], 
                        memory[obi_addr_i + 0]};
        end else begin
            read_data = '0;
        end
    end

    // Response generation
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_q <= '0;
            rdata_q  <= '0;
            err_q    <= '0;
            
            // Initialize memory
            for (int i = 0; i < MEM_SIZE; i++) begin
                memory[i] <= 8'h0;
            end
        end else begin
            if (obi_req_i) begin
                // Generate response for every request
                rvalid_q <= 1'b1;
                err_q    <= !addr_valid;
                
                if (obi_we_i) begin
                    rdata_q <= '0;  // Write responses have no data
                end else begin
                    rdata_q <= read_data;  // Read responses return data
                end
            end else begin
                rvalid_q <= 1'b0;  // No response when no request
            end
        end
    end

    // Write handling
    always_ff @(posedge clk_i) begin
        if (obi_req_i && obi_we_i && addr_valid) begin
            // Perform write with byte enables
            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                if (obi_be_i[i]) begin
                    memory[obi_addr_i + i] <= obi_wdata_i[i*8 +: 8];
                end
            end
        end
    end

endmodule
