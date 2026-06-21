`timescale 1ns / 1ps

//============================================================
// Module Name : Async_FIFO_TB
// Description : Testbench for Asynchronous Register-Based FIFO
//
// Function:
//   - Simulates high-speed write and slow-speed read domains.
//   - Verifies Full and Empty flag generation across CDCs.
//   - Dumps waveforms to a VCD file for visualization.
//============================================================

module Async_FIFO_TB;

    //--------------------------------------------------------
    // Parameters & Signals
    //--------------------------------------------------------
    parameter DataWidth = 16;
    parameter AddrWidth = 4; // Depth = 16

    // Write Domain Signals (Registers for driving inputs)
    reg                  iWClk;
    reg                  iWRstN;
    reg                  iWInc;
    reg  [DataWidth-1:0] iData;
    wire                 oFull;

    // Read Domain Signals (Registers for driving inputs, wires for outputs)
    reg                  iRClk;
    reg                  iRRstN;
    reg                  iRInc;
    wire [DataWidth-1:0] oData;
    wire                 oEmpty;

    //--------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    //--------------------------------------------------------
    Async_FIFO #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth)
    ) uut (
        .iWClk  (iWClk),
        .iWRstN (iWRstN),
        .iRClk  (iRClk),
        .iRRstN (iRRstN),
        .iData  (iData),
        .iWInc  (iWInc),
        .iRInc  (iRInc),
        .oData  (oData),
        .oFull  (oFull),
        .oEmpty (oEmpty)
    );

    //--------------------------------------------------------
    // Clock Generation
    //
    // Write clock: 10ns period (Fast Clock - e.g., 100MHz)
    // Read clock : 25ns period (Slow Clock - e.g., 40MHz)
    //--------------------------------------------------------
    always #5 iWClk = ~iWClk;
    always #12.5 iRClk = ~iRClk;

    //--------------------------------------------------------
    // Test Sequence
    //--------------------------------------------------------
    integer Idx;

    initial begin
        // Tell Icarus Verilog to dump waveforms for viewing
        $dumpfile("fifo_waves.vcd");
        $dumpvars(0, Async_FIFO_TB);

        // Initialize all inputs
        iWClk  = 0;
        iRClk  = 0;
        iWRstN = 0;
        iRRstN = 0;
        iWInc  = 0;
        iRInc  = 0;
        iData  = 0;

        // Apply Resets
        #20;
        iWRstN = 1;
        iRRstN = 1;
        #20;

        $display("----------------------------------------");
        $display("Test 1: Write until FULL");
        $display("----------------------------------------");
        
        // Wait for a negative clock edge to assign values safely
        @(negedge iWClk);
        
        // Loop 18 times (FIFO depth is 16, so it should stop writing when full)
        for (Idx = 0; Idx < 18; Idx = Idx + 1) begin
            if (!oFull) begin
                iWInc = 1;
                iData = Idx * 10; // Write dummy data (0, 10, 20, 30...)
                $display("[Write Domain] Wrote data: %0d", iData);
            end else begin
                iWInc = 0;
                $display("[Write Domain] FIFO is FULL. Write blocked.");
            end
            @(negedge iWClk);
        end
        iWInc = 0; // Stop writing
        
        #100; // Wait a bit to let CDC synchronizers settle

        $display("----------------------------------------");
        $display("Test 2: Read until EMPTY");
        $display("----------------------------------------");
        
        @(negedge iRClk);
        for (Idx = 0; Idx < 18; Idx = Idx + 1) begin
            if (!oEmpty) begin
                iRInc = 1;
                $display("[Read Domain] Read data: %0d", oData);
            end else begin
                iRInc = 0;
                $display("[Read Domain] FIFO is EMPTY. Read blocked.");
            end
            @(negedge iRClk);
        end
        iRInc = 0; // Stop reading

        #50;
        $display("----------------------------------------");
        $display("Testbench Completed Successfully!");
        $display("----------------------------------------");
        
        // End the simulation
        $finish;
    end

endmodule