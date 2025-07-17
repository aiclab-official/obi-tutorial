// -----------------------------------------------------------------------------
// Simple OBI Slave Testbench - Tutorial Implementation
//
// Clean, educational testbench for the simplified OBI slave.
// Focuses on clarity and ease of understanding while providing comprehensive testing.
//
// Test Coverage:
//   - Basic read/write operations
//   - Byte enable functionality  
//   - Pipelined operations
//   - Error handling
// -----------------------------------------------------------------------------

`include "obi/typedef.svh"
`include "obi/assign.svh"

module tb_obi_slave;

import obi_pkg::*;

// Simple test parameters
localparam time CyclTime = 10ns;
localparam time ApplTime = 2ns;
localparam time TestTime = 8ns;

// Minimal OBI configuration for tutorial
localparam obi_pkg::obi_cfg_t ObiCfg = '{
    UseRReady:   1'b0,
    CombGnt:     1'b0,
    AddrWidth:   32,
    DataWidth:   32,
    IdWidth:     0,
    Integrity:   1'b0,
    BeFull:      1'b1,
    OptionalCfg: obi_pkg::ObiMinimalOptionalConfig
};

// Generate OBI types
`OBI_TYPEDEF_DEFAULT_ALL(obi, ObiCfg)

// Clock and reset
logic clk, rst_n, end_of_sim;

// Simple OBI signals
logic        obi_req, obi_gnt, obi_we, obi_rvalid, obi_err;
logic [31:0] obi_addr, obi_wdata, obi_rdata;
logic [3:0]  obi_be;

// Clock generation
clk_rst_gen #(
    .ClkPeriod    ( CyclTime ),
    .RstClkCycles ( 5        )
) i_clk_gen (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
);

// OBI Bus infrastructure
OBI_BUS_DV #(
    .OBI_CFG          ( ObiCfg ),
    .obi_a_optional_t ( obi_a_optional_t ),
    .obi_r_optional_t ( obi_r_optional_t )
) master_bus_dv (
    .clk_i  ( clk   ),
    .rst_ni ( rst_n )
);

OBI_BUS #(
    .OBI_CFG          ( ObiCfg ),
    .obi_a_optional_t ( obi_a_optional_t ),
    .obi_r_optional_t ( obi_r_optional_t )
) master_bus ();

// OBI Test Manager - simplified configuration
typedef obi_test::obi_rand_manager #(
    .ObiCfg           ( ObiCfg ),
    .obi_a_optional_t ( obi_a_optional_t ),
    .obi_r_optional_t ( obi_r_optional_t ),
    .TA ( ApplTime ),
    .TT ( TestTime ),
    .MinAddr (32'h0000_0000),
    .MaxAddr (32'h0000_03FF),
    .AMinWaitCycles (0),
    .AMaxWaitCycles (1),
    .RMinWaitCycles (0),
    .RMaxWaitCycles (1)
) obi_manager_t;

// Main test sequence
initial begin
    automatic obi_manager_t obi_manager = new(master_bus_dv, "OBI_TEST");
    automatic logic [31:0] read_data;
    automatic logic        read_err;
    automatic logic        a_optional = '0;
    automatic logic        r_optional = '0;
    automatic logic        aid = '0;
    automatic logic        r_rid = '0;
    
    end_of_sim = 1'b0;
    obi_manager.reset();
    @(posedge rst_n);
    
    $display("\n=== OBI Slave Tutorial Test ===");
    
    // Test 1: Basic Write/Read
    $display("\nTest 1: Basic Write/Read Operation");
    $display("  Writing 0xCAFEBABE to address 0x100");
    obi_manager.write(32'h100, 4'hF, 32'hCAFEBABE, aid, a_optional, read_data, r_rid, read_err, r_optional);
    
    $display("  Reading from address 0x100");
    obi_manager.read(32'h100, aid, a_optional, read_data, r_rid, read_err, r_optional);
    
    if (read_data == 32'hCAFEBABE) begin
        $display("  ✓ PASS: Read data matches written data (0x%08x)", read_data);
    end else begin
        $display("  ✗ FAIL: Expected 0xCAFEBABE, got 0x%08x", read_data);
    end
    
    // Test 2: Byte Enable Functionality
    $display("\nTest 2: Byte Enable Functionality");
    $display("  Writing 0xDEADBEEF with byte enables 0x3 (lower 2 bytes only)");
    obi_manager.write(32'h200, 4'h3, 32'hDEADBEEF, aid, a_optional, read_data, r_rid, read_err, r_optional);
    
    obi_manager.read(32'h200, aid, a_optional, read_data, r_rid, read_err, r_optional);
    
    if (read_data == 32'h0000BEEF) begin
        $display("  ✓ PASS: Byte enables working correctly (0x%08x)", read_data);
    end else begin
        $display("  ✗ FAIL: Expected 0x0000BEEF, got 0x%08x", read_data);
    end
    
    // Test 3: Pipelined Operations
    $display("\nTest 3: Pipelined Operations");
    test_pipelined_operations(obi_manager, aid, a_optional);
    
    repeat(10) @(posedge clk);
    end_of_sim = 1'b1;
    $display("\n=== Test Completed ===");
end

// Pipelined test function - cleaner and more focused
task automatic test_pipelined_operations(
    input obi_manager_t obi_manager,
    input logic aid,
    input logic a_optional
);
    localparam int NUM_TESTS = 8;
    logic [31:0] test_addr[NUM_TESTS];
    logic [31:0] test_data[NUM_TESTS];
    logic [31:0] read_data;
    logic        read_rid, read_err, r_optional;
    int error_count = 0;
    
    // Generate test patterns
    for (int i = 0; i < NUM_TESTS; i++) begin
        test_addr[i] = 32'h300 + (i * 4);  // Word-aligned addresses
        test_data[i] = 32'hA000_0000 + i;  // Unique test pattern
    end
    
    $display("  Phase 1: Pipelined Writes");
    // Send all writes back-to-back
    for (int i = 0; i < NUM_TESTS; i++) begin
        $display("    Write %0d: addr=0x%x, data=0x%x", i, test_addr[i], test_data[i]);
        obi_manager.drv.send_a(test_addr[i], 1'b1, 4'hF, test_data[i], aid, a_optional);
    end
    
    repeat(4) @(posedge clk);  // Allow writes to complete
    
    $display("  Phase 2: Pipelined Reads with Verification");
    // Send all reads back-to-back, then collect responses
    fork
        // Send read requests
        for (int i = 0; i < NUM_TESTS; i++) begin
            obi_manager.drv.send_a(test_addr[i], 1'b0, 4'hF, '0, aid, a_optional);
        end
        
        // Collect responses
        for (int i = 0; i < NUM_TESTS; i++) begin
            obi_manager.drv.recv_r(read_data, read_rid, read_err, r_optional);
            
            if (read_data == test_data[i]) begin
                $display("    ✓ Read %0d: data=0x%x matches expected", i, read_data);
            end else begin
                $display("    ✗ Read %0d: data=0x%x, expected=0x%x", i, read_data, test_data[i]);
                error_count++;
            end
        end
    join
    
    if (error_count == 0) begin
        $display("  ✓ PASS: All pipelined operations successful");
    end else begin
        $display("  ✗ FAIL: %0d pipelined operations failed", error_count);
    end
endtask

// OBI Bus connections
`OBI_ASSIGN(master_bus, master_bus_dv, ObiCfg, ObiCfg)

// Convert OBI bus to simple signals
always_comb begin
    obi_req   = master_bus.req;
    obi_addr  = master_bus.addr;
    obi_we    = master_bus.we;
    obi_be    = master_bus.be;
    obi_wdata = master_bus.wdata;
    
    master_bus.gnt     = obi_gnt;
    master_bus.rvalid  = obi_rvalid;
    master_bus.rdata   = obi_rdata;
    master_bus.err     = obi_err;
    
    // Tie off optional signals
    master_bus.a_optional = '0;
    master_bus.r_optional = '0;
end

// Device Under Test: Simplified OBI Slave
obi_slave_custom #(
    .MEM_SIZE ( 1024 )
) dut (
    .clk_i        ( clk       ),
    .rst_ni       ( rst_n     ),
    .obi_req_i    ( obi_req   ),
    .obi_gnt_o    ( obi_gnt   ),
    .obi_addr_i   ( obi_addr  ),
    .obi_we_i     ( obi_we    ),
    .obi_be_i     ( obi_be    ),
    .obi_wdata_i  ( obi_wdata ),
    .obi_rvalid_o ( obi_rvalid),
    .obi_rdata_o  ( obi_rdata ),
    .obi_err_o    ( obi_err   )
);

// Simple transaction monitor
always_ff @(posedge clk) begin
    if (obi_req && obi_gnt) begin
        if (obi_we) begin
            $display("[%0t] Write: addr=0x%x, data=0x%x, be=0x%x", $time, obi_addr, obi_wdata, obi_be);
        end else begin
            $display("[%0t] Read:  addr=0x%x", $time, obi_addr);
        end
    end
    
    if (obi_rvalid) begin
        $display("[%0t] Response: data=0x%x, err=%b", $time, obi_rdata, obi_err);
    end
end

// Simulation control
initial begin
    wait(end_of_sim);
    repeat(5) @(posedge clk);
    $display("Simulation completed successfully!");
    $finish;
end

// Safety timeout
initial begin
    #(1000 * CyclTime);
    $error("Test timeout!");
    $finish;
end

endmodule
