`timescale 1ns/1ps

//============================================================
// File        : TB_UART_Tx_16bit_With_Divider.v
// Testbench   : TB_UART_Tx_16bit_With_Divider
// Description : Testbench for UART_Tx_16bit
//
// The UART module internally instantiates Baud_Clk_Divider_50.
//
// Test scenario:
//   1. Generate 10 MHz slow clock.
//   2. Reset the design.
//   3. Send first FIFO word: 16'hA55A.
//   4. Check UART frame:
//        Start + 16 data bits LSB first + Stop
//   5. Send second FIFO word: 16'h1234.
//   6. Dump VCD file for ModelSim waveform analysis.
//============================================================

module TB_UART_Tx_16bit_With_Divider;

    //--------------------------------------------------------
    // Testbench parameters
    //
    // For simulation speed:
    //   BAUD_HALF_DIV_TB = 5
    //
    // In the real project with 10 MHz slow clock:
    //   BAUD_HALF_DIV = 520
    //--------------------------------------------------------
    localparam integer BAUD_HALF_DIV_TB = 5;
    localparam integer BAUD_PERIOD_CLKS = 2 * BAUD_HALF_DIV_TB;

    //--------------------------------------------------------
    // Testbench signals
    //--------------------------------------------------------
    reg        iSlowClk;
    reg        iResetN;

    reg        iFifoEmpty;
    reg [15:0] iFifoData;

    wire       oFifoRinc;
    wire       oSerialTx;
    wire       oBusyTx;

    //--------------------------------------------------------
    // DUT instantiation
    //--------------------------------------------------------
    UART_Tx_16bit
    #(
        .BAUD_HALF_DIV(BAUD_HALF_DIV_TB)
    )
    dut
    (
        .iSlowClk   (iSlowClk),
        .iResetN    (iResetN),

        .iFifoEmpty (iFifoEmpty),
        .iFifoData  (iFifoData),

        .oFifoRinc  (oFifoRinc),
        .oSerialTx  (oSerialTx),
        .oBusyTx    (oBusyTx)
    );

    //--------------------------------------------------------
    // 10 MHz slow clock generation
    //
    // Period = 100 ns
    //--------------------------------------------------------
    initial begin
        iSlowClk = 1'b0;
        forever #50 iSlowClk = ~iSlowClk;
    end

    //--------------------------------------------------------
    // Wait one UART bit period
    //--------------------------------------------------------
    task Wait_Baud_Period;
        begin
            repeat (BAUD_PERIOD_CLKS) @(posedge iSlowClk);
            #1;
        end
    endtask

    //--------------------------------------------------------
    // Drive one FIFO word
    //--------------------------------------------------------
    task Drive_Fifo_Word;
        input [15:0] data_word;
        begin
            @(posedge iSlowClk);
            iFifoData  <= data_word;
            iFifoEmpty <= 1'b0;

            //------------------------------------------------
            // Wait until UART reads the FIFO
            //------------------------------------------------
            wait (oFifoRinc == 1'b1);

            @(posedge iSlowClk);
            iFifoEmpty <= 1'b1;
        end
    endtask

    //--------------------------------------------------------
    // Check UART serial frame
    //
    // Expected order:
    //   bit 0  = start bit = 0
    //   bit 1  = data[0]
    //   bit 2  = data[1]
    //   ...
    //   bit 16 = data[15]
    //   bit 17 = stop bit = 1
    //--------------------------------------------------------
    task Check_UART_Frame;
        input [15:0] data_word;

        reg [17:0] expected_frame;
        integer bit_index;

        begin
            expected_frame = {1'b1, data_word, 1'b0};

            //------------------------------------------------
            // Start checking when FIFO read occurs.
            // At this moment, start bit should already be driven.
            //------------------------------------------------
            wait (oFifoRinc == 1'b1);
            #1;

            for (bit_index = 0; bit_index < 18; bit_index = bit_index + 1) begin
                if (oSerialTx !== expected_frame[bit_index]) begin
                    $display("ERROR at time %0t: UART bit %0d mismatch. Expected=%0b, Got=%0b",
                             $time, bit_index, expected_frame[bit_index], oSerialTx);
                end
                else begin
                    $display("PASS  at time %0t: UART bit %0d = %0b",
                             $time, bit_index, oSerialTx);
                end

                Wait_Baud_Period();
            end
        end
    endtask

    //--------------------------------------------------------
    // Main stimulus
    //--------------------------------------------------------
    initial begin
        //----------------------------------------------------
        // VCD dump for waveform viewing
        //----------------------------------------------------
        $dumpfile("TB_UART_Tx_16bit_With_Divider.vcd");
        $dumpvars(0, TB_UART_Tx_16bit_With_Divider);

        //----------------------------------------------------
        // Initial values
        //----------------------------------------------------
        iResetN    = 1'b0;
        iFifoEmpty = 1'b1;
        iFifoData  = 16'h0000;

        //----------------------------------------------------
        // Reset
        //----------------------------------------------------
        repeat (5) @(posedge iSlowClk);
        iResetN = 1'b1;

        repeat (20) @(posedge iSlowClk);

        //----------------------------------------------------
        // First word test
        //----------------------------------------------------
        fork
            Drive_Fifo_Word(16'hA55A);
            Check_UART_Frame(16'hA55A);
        join

        //----------------------------------------------------
        // Wait until UART is fully idle
        //----------------------------------------------------
        wait (oBusyTx == 1'b0);
        repeat (20) @(posedge iSlowClk);

        //----------------------------------------------------
        // Second word test
        //----------------------------------------------------
        fork
            Drive_Fifo_Word(16'h1234);
            Check_UART_Frame(16'h1234);
        join

        wait (oBusyTx == 1'b0);
        repeat (20) @(posedge iSlowClk);

        $display("UART testbench finished.");
        $finish;
    end

endmodule