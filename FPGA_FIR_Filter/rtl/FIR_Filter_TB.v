`timescale 1ns / 1ps

//============================================================
// Module Name : FIR_Filter_TB
// Description : Testbench for the 4-Tap Weighted FIR Filter
//
// Function:
//   - Verifies the sliding window and shift-add multiplication.
//   - Drives iValidIn to test pipeline stalls/holds.
//   - Dumps waveforms to a VCD file for visualization.
//============================================================

module FIR_Filter_TB;

    //--------------------------------------------------------
    // Parameters & Signals
    //--------------------------------------------------------
    // Inputs to the DUT (Registers in TB)
    reg         iClkFast;
    reg         iRstN;
    reg  [7:0]  iDataIn;
    reg         iValidIn;

    // Outputs from the DUT (Wires in TB)
    wire [15:0] oDataOut;
    wire        oValidOut;

    //--------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    //--------------------------------------------------------
    FIR_Filter uut (
        .iClkFast  (iClkFast),
        .iRstN     (iRstN),
        .iDataIn   (iDataIn),
        .iValidIn  (iValidIn),
        .oDataOut  (oDataOut),
        .oValidOut (oValidOut)
    );

    //--------------------------------------------------------
    // Clock Generation
    //
    // 10ns period -> 100MHz fast processing clock
    //--------------------------------------------------------
    always #5 iClkFast = ~iClkFast;

    //--------------------------------------------------------
    // Test Sequence
    //--------------------------------------------------------
    integer Idx;

    initial begin
        // Setup waveform dumping for VSCode WaveTrace/GTKWave
        $dumpfile("fir_waves.vcd");
        $dumpvars(0, FIR_Filter_TB);

        // Initialize inputs
        iClkFast = 0;
        iRstN    = 0;
        iDataIn  = 0;
        iValidIn = 0;

        // Apply asynchronous reset
        #20;
        iRstN = 1;
        #20;

        $display("----------------------------------------");
        $display("Starting Weighted FIR Filter Data Stream Test");
        $display("----------------------------------------");

        // Test 1: Ramp up with valid data (Sequence: 10, 20, 30, 40, 50...)
        @(negedge iClkFast);
        iValidIn = 1;
        for (Idx = 1; Idx <= 5; Idx = Idx + 1) begin
            iDataIn = Idx * 10;
            @(negedge iClkFast);
            $display("Time: %0t | Valid In: %b | Data In: %3d || Valid Out: %b | Data Out: %4d", 
                     $time, iValidIn, iDataIn, oValidOut, oDataOut);
        end

        $display("----------------------------------------");
        $display("Test 2: Pause Stream (iValidIn = 0)");
        $display("Filter should hold state and oValidOut should drop to 0");
        $display("----------------------------------------");
        iValidIn = 0;
        iDataIn  = 99; // Put garbage on the bus to ensure it's ignored
        for (Idx = 0; Idx < 3; Idx = Idx + 1) begin
            @(negedge iClkFast);
            $display("Time: %0t | Valid In: %b | Data In: %3d || Valid Out: %b | Data Out: %4d", 
                     $time, iValidIn, iDataIn, oValidOut, oDataOut);
        end

        $display("----------------------------------------");
        $display("Test 3: Resume Stream with Constant Data (10)");
        $display("Output should eventually stabilize at 10*1 + 10*2 + 10*3 + 10*4 = 100");
        $display("----------------------------------------");
        iValidIn = 1;
        for (Idx = 0; Idx < 5; Idx = Idx + 1) begin
            iDataIn = 10;
            @(negedge iClkFast);
            $display("Time: %0t | Valid In: %b | Data In: %3d || Valid Out: %b | Data Out: %4d", 
                     $time, iValidIn, iDataIn, oValidOut, oDataOut);
        end

        $display("----------------------------------------");
        $display("Test 4: Flushing the filter (Zeros)");
        $display("----------------------------------------");
        for (Idx = 0; Idx < 4; Idx = Idx + 1) begin
            iDataIn = 0;
            @(negedge iClkFast);
            $display("Time: %0t | Valid In: %b | Data In: %3d || Valid Out: %b | Data Out: %4d", 
                     $time, iValidIn, iDataIn, oValidOut, oDataOut);
        end
        
        iValidIn = 0; // End of stream

        #50;
        $display("----------------------------------------");
        $display("Testbench Completed Successfully!");
        $display("----------------------------------------");
        $finish;
    end

endmodule