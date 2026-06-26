//============================================================
// File        : UART_Tx_16bit.v
// Module      : UART_Tx_16bit
// Description : UART transmitter for 16-bit FIFO data
//
// UART Frame:
//   Start bit : 0
//   Data bits : 16 bits, LSB first
//   Stop bit  : 1
//
// Baud generation:
//   - Uses Baud_Clk_Divider_50 internally.
//   - The divided baud clock is edge-detected.
//   - The FSM advances once per baud period.
//
// FSM encoding:
//   IDLE  = 0
//   START = 1
//   DATA  = 2
//   STOP  = 4
//============================================================

module UART_Tx_16bit
#(
    parameter integer BAUD_HALF_DIV = 520
)
(
    input  wire        iSlowClk,      // slow clock, for example 10 MHz
    input  wire        iResetN,       // async active-low reset

    input  wire        iFifoEmpty,    // connected to FIFO rempty
    input  wire [15:0] iFifoData,     // connected to FIFO rdata[15:0]

    output reg         oFifoRinc,     // FIFO read increment pulse
    output reg         oSerialTx,     // UART serial output
    output reg         oBusyTx        // UART busy indication
);

    //--------------------------------------------------------
    // Internal baud clock divider
    //--------------------------------------------------------
    wire wBaudClk;

    Baud_Clk_Divider_50
    #(
        .HALF_DIV(BAUD_HALF_DIV)
    )
    u_Baud_Clk_Divider_50
    (
        .iClk    (iSlowClk),
        .iResetN (iResetN),
        .oClk    (wBaudClk)
    );

    //--------------------------------------------------------
    // Baud clock rising-edge detector
    //
    // wBaudStep is a one-cycle enable pulse in iSlowClk domain.
    //--------------------------------------------------------
    reg rBaudClkD;

    wire wBaudStep;
    assign wBaudStep = wBaudClk & ~rBaudClkD;

    //--------------------------------------------------------
    // FSM encoding: 0, 1, 2, 4
    //--------------------------------------------------------
    localparam [2:0] ST_IDLE  = 3'b000;
    localparam [2:0] ST_START = 3'b001;
    localparam [2:0] ST_DATA  = 3'b010;
    localparam [2:0] ST_STOP  = 3'b100;

    reg [2:0] rState;

    //--------------------------------------------------------
    // Internal registers
    //--------------------------------------------------------
    reg [15:0] rTxShift;       // data shift register
    reg [4:0]  rBitCnt;        // counts transmitted data bits
    reg        rStopStarted;   // used to hold stop bit for one baud period

    //--------------------------------------------------------
    // UART transmitter logic
    //--------------------------------------------------------
    always @(posedge iSlowClk or negedge iResetN) begin
        if (!iResetN) begin
            rBaudClkD    <= 1'b0;
            rState       <= ST_IDLE;
            rTxShift     <= 16'd0;
            rBitCnt      <= 5'd0;
            rStopStarted <= 1'b0;

            oFifoRinc    <= 1'b0;
            oSerialTx    <= 1'b1;     // UART idle line is high
            oBusyTx      <= 1'b0;
        end
        else begin
            //------------------------------------------------
            // Register baud clock for edge detection
            //------------------------------------------------
            rBaudClkD <= wBaudClk;

            //------------------------------------------------
            // Default value: FIFO read pulse is one slow_clk cycle
            //------------------------------------------------
            oFifoRinc <= 1'b0;

            //------------------------------------------------
            // FSM advances only once per baud period
            //------------------------------------------------
            if (wBaudStep) begin

                case (rState)

                    //------------------------------------------------
                    // IDLE:
                    // Wait until FIFO has data.
                    //------------------------------------------------
                    ST_IDLE: begin
                        oSerialTx    <= 1'b1;
                        oBusyTx      <= 1'b0;
                        rBitCnt      <= 5'd0;
                        rStopStarted <= 1'b0;

                        if (!iFifoEmpty) begin
                            rTxShift  <= iFifoData;
                            oFifoRinc <= 1'b1;

                            //------------------------------------------------
                            // Start bit begins now
                            //------------------------------------------------
                            oSerialTx <= 1'b0;
                            oBusyTx   <= 1'b1;
                            rState    <= ST_START;
                        end
                    end

                    //------------------------------------------------
                    // START:
                    // Start bit has lasted one baud period.
                    // Now transmit data bit 0.
                    //------------------------------------------------
                    ST_START: begin
                        oSerialTx <= rTxShift[0];
                        rTxShift  <= {1'b0, rTxShift[15:1]};
                        rBitCnt   <= 5'd1;
                        rState    <= ST_DATA;
                    end

                    //------------------------------------------------
                    // DATA:
                    // Transmit data bits 1 to 15.
                    //------------------------------------------------
                    ST_DATA: begin
                        oSerialTx <= rTxShift[0];
                        rTxShift  <= {1'b0, rTxShift[15:1]};

                        if (rBitCnt == 5'd15) begin
                            rState <= ST_STOP;
                        end

                        rBitCnt <= rBitCnt + 1'b1;
                    end

                    //------------------------------------------------
                    // STOP:
                    // First baud step: drive stop bit high.
                    // Second baud step: stop bit completed, go IDLE.
                    //------------------------------------------------
                    ST_STOP: begin
                        if (!rStopStarted) begin
                            oSerialTx    <= 1'b1;
                            rStopStarted <= 1'b1;
                        end
                        else begin
                            oSerialTx    <= 1'b1;
                            oBusyTx      <= 1'b0;
                            rStopStarted <= 1'b0;
                            rBitCnt      <= 5'd0;
                            rState       <= ST_IDLE;
                        end
                    end

                    default: begin
                        rState       <= ST_IDLE;
                        oSerialTx    <= 1'b1;
                        oBusyTx      <= 1'b0;
                        rStopStarted <= 1'b0;
                    end

                endcase
            end
        end
    end

endmodule