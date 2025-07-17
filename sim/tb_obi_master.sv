// -----------------------------------------------------------------------------
// Project:      OBI Tutorial
// Company:      AICLAB
//
// Module:       obi_master_custom
// Description:
//   Testbench for custom OBI Master vs PULP OBI Slave
// -----------------------------------------------------------------------------

`include "obi/typedef.svh"
`include "obi/assign.svh"

module tb_obi_master;

import obi_pkg::*;

// Test parameters
localparam time CyclTime = 10ns;
localparam time ApplTime = 2ns;
localparam time TestTime = 8ns;

// OBI Configuration for memory (default minimal configuration)
localparam obi_pkg::obi_cfg_t ObiCfg = '{
    UseRReady:      1'b0,  // Default OBI doesn't use rready in req struct
    CombGnt:        1'b0,
    AddrWidth:        32,
    DataWidth:        32,
    IdWidth:           0,  // No ID signals for minimal implementation
    Integrity:      1'b0,
    BeFull:         1'b1,
    OptionalCfg: obi_pkg::ObiMinimalOptionalConfig
};

// Generate OBI types using default (minimal) configuration
`OBI_TYPEDEF_DEFAULT_ALL(obi, ObiCfg)

// Clock and reset
logic clk, rst_n;

// Master status signals
logic        busy;
logic        test_done;
logic        test_pass;
logic [7:0]  error_count;

// OBI signals between master and memory
logic                obi_req;
logic                obi_gnt;
logic [31:0]         obi_addr;
logic                obi_we;
logic [3:0]          obi_be;
logic [31:0]         obi_wdata;
logic                obi_rvalid;
logic [31:0]         obi_rdata;
logic                obi_err;

// Convert to OBI types
obi_req_t mem_req;
obi_rsp_t mem_rsp;

// Clock generation
clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
);

// Custom OBI Master (Autonomous)
obi_master_custom #(
    .NUM_TEST_WORDS ( 16        ),  // Test more words
    .BASE_ADDR      ( 32'h1000  ),  // Start address
    .TEST_PATTERN   ( 32'hA5A5A5A5 )
) i_custom_master (
    .clk_i          ( clk        ),
    .rst_ni         ( rst_n      ),
    .busy_o         ( busy       ),
    .test_done_o    ( test_done  ),
    .test_pass_o    ( test_pass  ),
    .error_count_o  ( error_count),
    .obi_req_o      ( obi_req    ),
    .obi_gnt_i      ( obi_gnt    ),
    .obi_addr_o     ( obi_addr   ),
    .obi_we_o       ( obi_we     ),
    .obi_be_o       ( obi_be     ),
    .obi_wdata_o    ( obi_wdata  ),
    .obi_rvalid_i   ( obi_rvalid ),
    .obi_rdata_i    ( obi_rdata  )
);

// Convert simple ports to OBI struct format for default OBI memory model
always_comb begin
    mem_req.a.addr       = obi_addr;
    mem_req.a.we         = obi_we;
    mem_req.a.be         = obi_be;
    mem_req.a.wdata      = obi_wdata;
    mem_req.a.aid        = '0;      // Address ID (zero for minimal config)
    mem_req.a.a_optional = '0;      // Minimal optional (just logic)
    mem_req.req          = obi_req;
    
    obi_gnt              = mem_rsp.gnt;
    obi_rvalid           = mem_rsp.rvalid;
    obi_rdata            = mem_rsp.r.rdata;
    obi_err              = mem_rsp.r.err;  //! Not used

end

// PULP OBI Memory Model
obi_sim_mem #(
    .ObiCfg            ( ObiCfg    ),
    .obi_req_t         ( obi_req_t ),
    .obi_rsp_t         ( obi_rsp_t ),
    .obi_r_chan_t      ( obi_r_chan_t ),
    .WarnUninitialized ( 1'b1     ),  // Enable warnings
    .ApplDelay         ( 0ps      ),  // Remove delays to avoid race conditions
    .AcqDelay          ( 0ps      )   // Remove delays to avoid race conditions
) i_sim_mem (
    .clk_i       ( clk     ),
    .rst_ni      ( rst_n   ),
    .obi_req_i   ( mem_req ),
    .obi_rsp_o   ( mem_rsp ),
    .mon_valid_o ( ),
    .mon_we_o    ( ),
    .mon_addr_o  ( ),
    .mon_wdata_o ( ),
    .mon_be_o    ( ),
    .mon_id_o    ( )
);

// Debug: Monitor master status and OBI transactions
always @(posedge clk) begin
    if (busy && !$past(busy)) begin
        $display("Master started autonomous test sequence");
    end
    
    if (obi_req && obi_gnt) begin
        if (obi_we) begin
            $display("Write: addr=0x%x, data=0x%x", obi_addr, obi_wdata);
        end else begin
            $display("Read:  addr=0x%x", obi_addr);
        end
    end
    
    if (obi_rvalid && !obi_we) begin
        $display("Read response: data=0x%x", obi_rdata);
    end
    
    if (test_done && !$past(test_done)) begin
        if (test_pass) begin
            $display("SUCCESS: All memory tests passed!");
        end else begin
            $display("FAILURE: %0d errors detected", error_count);
        end
    end
end

// Simple test monitor - just wait for completion
initial begin
    // Wait for reset
    @(posedge rst_n);
    
    $display("=== Autonomous OBI Master Memory Test ===");
    
    // Wait for test completion
    wait(test_done);
    
    repeat(10) @(posedge clk);
    
    // Report final results
    $display("=== Test Results ===");
    if (test_pass) begin
        $display("✓ Memory test PASSED - All data verified correctly");
        $display("✓ Master performed autonomous write/read sequence successfully");
    end else begin
        $display("✗ Memory test FAILED - %0d verification errors", error_count);
    end
    
    $display("Test completed at time %0t", $time);
    $finish;
end

// Timeout
initial begin
    #(10000 * CyclTime);  // Longer timeout for autonomous operation
    $error("Test timeout!");
    $finish;
end

endmodule
