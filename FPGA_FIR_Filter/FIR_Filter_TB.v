`timescale 1ns / 1ps

//============================================================
// Module Name : FIR_Filter_TB
// Description : Testbench for the 4-Tap Moving Average FIR Filter
//
// Function:
//   - Verifies the sliding window shift register and averaging logic.
//   - Feeds a continuous stream of 8-bit data into the filter.
//   - Dumps waveforms to a VCD file for visualization.
//============================================================

module FIR_Filter_TB;

    //--------------------------------------------------------
    // Parameters & Signals
    //--------------------------------------------------------
    parameter DataWidth = 8;

    // Inputs to the DUT (Registers in TB)
    reg                  iClk;
    reg                  iRstN;
    reg  [DataWidth-1:0] iData;

    // Outputs from the DUT (Wires in TB)
    wire [DataWidth-1:0] oData;

    //--------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    //--------------------------------------------------------
    FIR_Filter #(
        .DataWidth(DataWidth)
    ) uut (
        .iClk  (iClk),
        .iRstN (iRstN),
        .iData (iData),
        .oData (oData)
    );

    //--------------------------------------------------------
    // Clock Generation
    //
    // 10ns period -> 100MHz fast processing clock
    //--------------------------------------------------------
    always #5 iClk = ~iClk;

    //--------------------------------------------------------
    // Test Sequence
    //--------------------------------------------------------
    integer Idx;

    initial begin
        // Setup waveform dumping for VSCode WaveTrace/GTKWave
        $dumpfile("fir_waves.vcd");
        $dumpvars(0, FIR_Filter_TB);

        // Initialize inputs
        iClk  = 0;
        iRstN = 0;
        iData = 0;

        // Apply asynchronous reset
        #20;
        iRstN = 1;
        #20;

        $display("----------------------------------------");
        $display("Starting FIR Filter Data Stream Test");
        $display("----------------------------------------");

        // Test 1: Ramp up (Sequence: 10, 20, 30, 40, 50...)
        @(negedge iClk);
        for (Idx = 1; Idx <= 8; Idx = Idx + 1) begin
            iData = Idx * 10;
            @(negedge iClk);
            $display("Time: %0t | Input Data: %3d | Output Average: %3d", $time, iData, oData);
        end

        $display("----------------------------------------");
        $display("Test 2: Constant Data (Wait for filter to stabilize)");
        $display("----------------------------------------");
        // Test 2: Feed constant data (100)
        for (Idx = 0; Idx < 5; Idx = Idx + 1) begin
            iData = 100;
            @(negedge iClk);
            $display("Time: %0t | Input Data: %3d | Output Average: %3d", $time, iData, oData);
        end

        $display("----------------------------------------");
        $display("Test 3: Flushing the filter (Zeros)");
        $display("----------------------------------------");
        // Test 3: Feed zeros to flush the shift registers
        for (Idx = 0; Idx < 5; Idx = Idx + 1) begin
            iData = 0;
            @(negedge iClk);
            $display("Time: %0t | Input Data: %3d | Output Average: %3d", $time, iData, oData);
        end

        #50;
        $display("----------------------------------------");
        $display("Testbench Completed Successfully!");
        $display("----------------------------------------");
        $finish;
    end

endmodule