//============================================================
// File        : Streaming_System.v
// Top Module  : Streaming_System
// Description : Clean final top-level integration.
//               Only real external system ports are exposed.
//
// System flow:
//   iDataIn/iValidIn
//        -> Power_Controller monitors activity
//        -> ALTCLKCTRL / simulation clock gate
//        -> FIR_Filter
//        -> Async_FIFO
//        -> UART_Tx_16bit
//        -> oSerialTx
//
// Clock domains:
//   iFastClk : fast processing clock, e.g. 100 MHz
//   iSlowClk : UART/FIFO-read clock, e.g. 10 MHz
//
// Notes:
//   SIM_MODE = 0 for Quartus synthesis.
//   SIM_MODE = 1 for ModelSim behavioral simulation.
//============================================================

module Streaming_System
#(
    parameter integer FIFO_ADDR_WIDTH = 4,
    parameter integer BAUD_HALF_DIV   = 520,
    parameter integer IDLE_TIMEOUT    = 10,
    parameter integer SIM_MODE        = 0
)
(
    //--------------------------------------------------------
    // Main clocks and reset
    //--------------------------------------------------------
    input  wire       iFastClk,
    input  wire       iSlowClk,
    input  wire       iResetN,

    //--------------------------------------------------------
    // Input stream
    //--------------------------------------------------------
    input  wire [7:0] iDataIn,
    input  wire       iValidIn,

    //--------------------------------------------------------
    // UART output
    //--------------------------------------------------------
    output wire       oSerialTx,
    output wire       oBusyTx
);

    //--------------------------------------------------------
    // Internal connections
    //--------------------------------------------------------
    wire        wClkEn;
    wire        wGatedFastClk;

    wire [15:0] wFirData;
    wire        wFirValid;

    wire [15:0] wFifoRData;
    wire        wFifoFull;
    wire        wFifoEmpty;
    wire        wFifoRinc;

    //--------------------------------------------------------
    // Power controller
    //
    // The controller itself remains clocked by iFastClk.
    // It only gates the FIR/FIFO-write clock.
    //--------------------------------------------------------
    Power_Controller
    #(
        .IDLE_TIMEOUT (IDLE_TIMEOUT),
        .SIM_MODE     (SIM_MODE)
    )
    u_Power_Controller
    (
        .iFastClk      (iFastClk),
        .iResetN       (iResetN),
        .iInValid      (iValidIn),

        .oClkEn        (wClkEn),
        .oGatedFastClk (wGatedFastClk)
    );

    //--------------------------------------------------------
    // FIR filter
    //
    // Runs in the gated fast clock domain.
    // oValidOut is used as the FIFO write increment.
    //--------------------------------------------------------
    FIR_Filter u_FIR_Filter
    (
        .iClkFast  (wGatedFastClk),
        .iRstN     (iResetN),
        .iDataIn   (iDataIn),
        .iValidIn  (iValidIn),

        .oDataOut  (wFirData),
        .oValidOut (wFirValid)
    );

    //--------------------------------------------------------
    // Asynchronous FIFO
    //
    // Write side: gated fast clock domain.
    // Read side : slow clock domain.
    //--------------------------------------------------------
    Async_FIFO
    #(
        .AddrWidth (FIFO_ADDR_WIDTH),
        .DataWidth (16)
    )
    u_Async_FIFO
    (
        .iWClk  (wGatedFastClk),
        .iWRstN (iResetN),

        .iRClk  (iSlowClk),
        .iRRstN (iResetN),

        .iData  (wFirData),
        .iWInc  (wFirValid),

        .iRInc  (wFifoRinc),
        .oData  (wFifoRData),

        .oFull  (wFifoFull),
        .oEmpty (wFifoEmpty)
    );

    //--------------------------------------------------------
    // UART transmitter
    //
    // Runs in the slow clock domain.
    // Internally instantiates Baud_Clk_Divider_50.
    //--------------------------------------------------------
    UART_Tx_16bit
    #(
        .BAUD_HALF_DIV (BAUD_HALF_DIV)
    )
    u_UART_Tx_16bit
    (
        .iSlowClk   (iSlowClk),
        .iResetN    (iResetN),

        .iFifoEmpty (wFifoEmpty),
        .iFifoData  (wFifoRData),

        .oFifoRinc  (wFifoRinc),
        .oSerialTx  (oSerialTx),
        .oBusyTx    (oBusyTx)
    );

endmodule