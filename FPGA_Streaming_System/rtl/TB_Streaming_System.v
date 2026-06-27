`timescale 1ns/1ps

//============================================================
// File        : TB_Streaming_System.v
// Testbench   : TB_Streaming_System
// Description : Integration testbench for the clean top-level.
//
// Test sequence:
//   1. Generate asynchronous fast and slow clocks.
//   2. Apply reset.
//   3. Send first block of samples.
//   4. Wait long enough for the power controller to gate the
//      fast processing clock.
//   5. Send second block of samples to wake the system.
//   6. Let UART transmit FIFO data.
//   7. Dump simulation_dump.vcd for waveform/power analysis.
//
// Important:
//   The top-level has clean ports only.
//   Internal signals are observed in this TB using hierarchical
//   references such as:
//      dut.wClkEn
//      dut.wFifoEmpty
//      dut.wFirValid
//============================================================

module TB_Streaming_System;

    //--------------------------------------------------------
    // Simulation parameters
    //--------------------------------------------------------
    localparam integer FIFO_ADDR_WIDTH_TB = 4;
    localparam integer BAUD_HALF_DIV_TB   = 5;   // Short simulation value
    localparam integer IDLE_TIMEOUT_TB    = 10;

    //--------------------------------------------------------
    // DUT ports
    //--------------------------------------------------------
    reg         iFastClk;
    reg         iSlowClk;
    reg         iResetN;

    reg  [7:0]  iDataIn;
    reg         iValidIn;

    wire        oSerialTx;
    wire        oBusyTx;

    //--------------------------------------------------------
    // Test counters
    //--------------------------------------------------------
    integer idx;
    integer gated_clk_count;
    integer fifo_read_count;

    //--------------------------------------------------------
    // DUT
    //--------------------------------------------------------
    Streaming_System
    #(
        .FIFO_ADDR_WIDTH (FIFO_ADDR_WIDTH_TB),
        .BAUD_HALF_DIV   (BAUD_HALF_DIV_TB),
        .IDLE_TIMEOUT    (IDLE_TIMEOUT_TB),
        .SIM_MODE        (1)                 // ModelSim simulation mode
    )
    dut
    (
        .iFastClk  (iFastClk),
        .iSlowClk  (iSlowClk),
        .iResetN   (iResetN),

        .iDataIn   (iDataIn),
        .iValidIn  (iValidIn),

        .oSerialTx (oSerialTx),
        .oBusyTx   (oBusyTx)
    );

    //--------------------------------------------------------
    // Fast clock: 100 MHz, period = 10 ns.
    //--------------------------------------------------------
    initial begin
        iFastClk = 1'b0;
        forever #5 iFastClk = ~iFastClk;
    end

    //--------------------------------------------------------
    // Slow clock: 10 MHz, period = 100 ns.
    //--------------------------------------------------------
    initial begin
        iSlowClk = 1'b0;
        forever #50 iSlowClk = ~iSlowClk;
    end

    //--------------------------------------------------------
    // Count gated clock rising edges for debug.
    //--------------------------------------------------------
    always @(posedge dut.wGatedFastClk or negedge iResetN) begin
        if (!iResetN)
            gated_clk_count <= 0;
        else
            gated_clk_count <= gated_clk_count + 1;
    end

    //--------------------------------------------------------
    // Count FIFO reads issued by the UART.
    //--------------------------------------------------------
    always @(posedge iSlowClk or negedge iResetN) begin
        if (!iResetN)
            fifo_read_count <= 0;
        else if (dut.wFifoRinc)
            fifo_read_count <= fifo_read_count + 1;
    end

    //--------------------------------------------------------
    // Send a block of input samples.
    //
    // The valid signal is held high for multiple fast-clock
    // cycles. This lets the power controller wake the gated
    // fast domain before the whole block is finished.
    //--------------------------------------------------------
    task Send_Block;
        input [7:0] base_value;
        input integer sample_count;
        begin
            for (idx = 0; idx < sample_count; idx = idx + 1) begin
                @(posedge iFastClk);
                iDataIn  <= base_value + idx[7:0];
                iValidIn <= 1'b1;
            end

            @(posedge iFastClk);
            iDataIn  <= 8'd0;
            iValidIn <= 1'b0;
        end
    endtask

    //--------------------------------------------------------
    // Main stimulus
    //--------------------------------------------------------
    initial begin
        //----------------------------------------------------
        // Required VCD file for waveform/toggle-rate analysis.
        //----------------------------------------------------
        $dumpfile("simulation_dump.vcd");
        $dumpvars(0, TB_Streaming_System);

        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------
        iResetN         = 1'b0;
        iDataIn         = 8'd0;
        iValidIn        = 1'b0;
        gated_clk_count = 0;
        fifo_read_count = 0;

        //----------------------------------------------------
        // Reset
        //----------------------------------------------------
        repeat (8) @(posedge iFastClk);
        iResetN = 1'b1;

        repeat (20) @(posedge iFastClk);

        //----------------------------------------------------
        // First input block
        //----------------------------------------------------
        $display("INFO: Sending first input block at time %0t", $time);
        Send_Block(8'd1, 20);

        //----------------------------------------------------
        // Wait so FIR writes can cross FIFO and UART can start.
        //----------------------------------------------------
        repeat (100) @(posedge iSlowClk);

        //----------------------------------------------------
        // Long idle interval. This should force clock gating.
        //----------------------------------------------------
        $display("INFO: Entering idle interval at time %0t", $time);
        repeat (80) @(posedge iFastClk);

        #1;
        if (dut.wClkEn !== 1'b0) begin
            $display("ERROR: Clock enable did not go LOW after idle timeout. time=%0t", $time);
        end
        else begin
            $display("PASS : Clock enable went LOW after idle timeout. time=%0t", $time);
        end

        //----------------------------------------------------
        // Second input block. This should wake the gated clock.
        //----------------------------------------------------
        $display("INFO: Sending second input block at time %0t", $time);
        Send_Block(8'd50, 20);

        repeat (5) @(posedge iFastClk);
        #1;
        if (dut.wClkEn !== 1'b1) begin
            $display("ERROR: Clock enable did not wake after second block. time=%0t", $time);
        end
        else begin
            $display("PASS : Clock enable woke after second block. time=%0t", $time);
        end

        //----------------------------------------------------
        // Let UART drain the FIFO.
        //----------------------------------------------------
        repeat (800) @(posedge iSlowClk);

        //----------------------------------------------------
        // Final status
        //----------------------------------------------------
        $display("INFO: Final status:");
        $display("      dut.wClkEn        = %0b", dut.wClkEn);
        $display("      dut.wFifoFull     = %0b", dut.wFifoFull);
        $display("      dut.wFifoEmpty    = %0b", dut.wFifoEmpty);
        $display("      oBusyTx           = %0b", oBusyTx);
        $display("      gated_clk_count   = %0d", gated_clk_count);
        $display("      fifo_read_count   = %0d", fifo_read_count);

        $display("TB_Streaming_System finished.");
        $finish;
    end

endmodule