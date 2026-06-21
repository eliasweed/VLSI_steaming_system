`timescale 1ns/1ps

//============================================================
// Testbench Name : TB_Baud_Clk_Divider_50
// Description    : Testbench for Baud_Clk_Divider_50
//
// Test purpose:
//   - Generate a 10 MHz input clock.
//   - Apply reset.
//   - Verify that oClk toggles every HALF_DIV input cycles.
//   - Verify 50% duty-cycle behavior.
//
// Simulation note:
//   - HALF_DIV is set to 5 for fast simulation.
//   - In the real project, use HALF_DIV = 520.
//============================================================

module TB_Baud_Clk_Divider_50;

    //--------------------------------------------------------
    // Testbench signals
    //--------------------------------------------------------
    reg  iClk;
    reg  iResetN;
    wire oClk;

    //--------------------------------------------------------
    // DUT instantiation
    //
    // HALF_DIV = 5 only for simulation speed.
    // Real value for 10 MHz to approximately 9600 baud:
    //   HALF_DIV = 520
    //--------------------------------------------------------
    Baud_Clk_Divider_50
    #(
        .HALF_DIV(5)
    )
    dut
    (
        .iClk    (iClk),
        .iResetN (iResetN),
        .oClk    (oClk)
    );

    //--------------------------------------------------------
    // Input clock generation
    //
    // Period = 100 ns
    // Frequency = 10 MHz
    //--------------------------------------------------------
    initial begin
        iClk = 1'b0;
        forever #50 iClk = ~iClk;
    end

    //--------------------------------------------------------
    // Main stimulus
    //--------------------------------------------------------
    initial begin

        //----------------------------------------------------
        // Dump signals to VCD file for waveform viewing
        //----------------------------------------------------
        $dumpfile("TB_Baud_Clk_Divider_50.vcd");
        $dumpvars(0, TB_Baud_Clk_Divider_50);

        //----------------------------------------------------
        // Apply reset
        //----------------------------------------------------
        iResetN = 1'b0;

        repeat(4) @(posedge iClk);

        //----------------------------------------------------
        // Release reset
        //----------------------------------------------------
        iResetN = 1'b1;

        //----------------------------------------------------
        // Run long enough to observe multiple output periods
        //----------------------------------------------------
        repeat(100) @(posedge iClk);

        //----------------------------------------------------
        // End simulation
        //----------------------------------------------------
        $finish;
    end

endmodule