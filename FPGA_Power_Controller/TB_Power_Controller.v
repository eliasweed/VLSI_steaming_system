`timescale 1ns/1ps

//============================================================
// File        : TB_Power_Controller.v
// Testbench   : TB_Power_Controller
// Description : Testbench for Power_Controller
//
// Test scenario:
//   1. Generate fast clock = 100 MHz.
//   2. Apply reset.
//   3. Send activity using iInValid = 1.
//   4. Stop activity for more than 10 clock cycles.
//   5. Check that oClkEn goes LOW.
//   6. Send activity again.
//   7. Check that oClkEn goes HIGH again.
//
// Note:
//   The altclkctrl model at the end of this file is only for
//   ModelSim simulation if Intel/Altera simulation libraries
//   are not connected.
//============================================================

module TB_Power_Controller;

    //--------------------------------------------------------
    // Parameters
    //--------------------------------------------------------
    localparam integer IDLE_TIMEOUT_TB = 10;

    //--------------------------------------------------------
    // Testbench signals
    //--------------------------------------------------------
    reg  iFastClk;
    reg  iResetN;
    reg  iInValid;

    wire oClkEn;
    wire oGatedFastClk;

    //--------------------------------------------------------
    // DUT instantiation
    //--------------------------------------------------------
    Power_Controller
    #(
        .IDLE_TIMEOUT(IDLE_TIMEOUT_TB)
    )
    dut
    (
        .iFastClk      (iFastClk),
        .iResetN       (iResetN),
        .iInValid      (iInValid),
        .oClkEn        (oClkEn),
        .oGatedFastClk (oGatedFastClk)
    );

    //--------------------------------------------------------
    // Fast clock generation
    //
    // Period = 10 ns
    // Frequency = 100 MHz
    //--------------------------------------------------------
    initial begin
        iFastClk = 1'b0;
        forever #5 iFastClk = ~iFastClk;
    end

    //--------------------------------------------------------
    // Main stimulus
    //--------------------------------------------------------
    initial begin

        //----------------------------------------------------
        // Create VCD dump file for waveform viewing
        //----------------------------------------------------
        $dumpfile("TB_Power_Controller.vcd");
        $dumpvars(0, TB_Power_Controller);

        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------
        iResetN  = 1'b0;
        iInValid = 1'b0;

        //----------------------------------------------------
        // Reset phase
        //----------------------------------------------------
        repeat (5) @(posedge iFastClk);
        iResetN = 1'b1;

        repeat (2) @(posedge iFastClk);

        //----------------------------------------------------
        // Check reset result
        //----------------------------------------------------
        if (oClkEn !== 1'b1) begin
            $display("ERROR at %0t: oClkEn should be HIGH after reset.", $time);
        end
        else begin
            $display("PASS  at %0t: oClkEn is HIGH after reset.", $time);
        end

        //----------------------------------------------------
        // Activity phase
        //
        // iInValid = 1 should keep oClkEn high and reload
        // the internal idle counter.
        //----------------------------------------------------
        repeat (4) begin
            @(posedge iFastClk);
            iInValid = 1'b1;
        end

        @(posedge iFastClk);
        iInValid = 1'b0;

        $display("INFO  at %0t: Activity stopped. Waiting for idle timeout.", $time);

        //----------------------------------------------------
        // Idle phase
        //
        // After IDLE_TIMEOUT cycles without iInValid,
        // oClkEn should go LOW.
        //----------------------------------------------------
        repeat (IDLE_TIMEOUT_TB + 2) @(posedge iFastClk);
        #1;

        if (oClkEn !== 1'b0) begin
            $display("ERROR at %0t: oClkEn did not go LOW after idle timeout.", $time);
        end
        else begin
            $display("PASS  at %0t: oClkEn went LOW after idle timeout.", $time);
        end

        //----------------------------------------------------
        // Wake-up phase
        //
        // When iInValid goes high again, oClkEn should return
        // HIGH immediately on the next fast clock edge.
        //----------------------------------------------------
        @(posedge iFastClk);
        iInValid = 1'b1;

        @(posedge iFastClk);
        #1;

        if (oClkEn !== 1'b1) begin
            $display("ERROR at %0t: oClkEn did not return HIGH after iInValid.", $time);
        end
        else begin
            $display("PASS  at %0t: oClkEn returned HIGH after iInValid.", $time);
        end

        //----------------------------------------------------
        // Go idle again to verify second shutdown
        //----------------------------------------------------
        @(posedge iFastClk);
        iInValid = 1'b0;

        repeat (IDLE_TIMEOUT_TB + 2) @(posedge iFastClk);
        #1;

        if (oClkEn !== 1'b0) begin
            $display("ERROR at %0t: oClkEn did not go LOW in second idle phase.", $time);
        end
        else begin
            $display("PASS  at %0t: oClkEn went LOW in second idle phase.", $time);
        end

        //----------------------------------------------------
        // End simulation
        //----------------------------------------------------
        repeat (10) @(posedge iFastClk);

        $display("Power_Controller testbench finished.");
        $finish;
    end

endmodule


//============================================================
// Behavioral altclkctrl model for simulation only
//
// Use this only if ModelSim does not recognize Intel's
// altclkctrl primitive.
//
// This is NOT the hardware implementation.
// The real synthesis implementation is the Intel/Altera
// ALTCLKCTRL primitive inside Quartus.
//============================================================

module altclkctrl
(
    input  wire [3:0] inclk,
    input  wire [1:0] clkselect,
    input  wire       ena,
    output wire       outclk
);

    wire selected_clk;

    assign selected_clk = inclk[clkselect];

    assign outclk = ena ? selected_clk : 1'b0;

endmodule