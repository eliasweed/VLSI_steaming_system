//============================================================
// Module Name : FIR_Filter
// Description : 4-Tap Weighted FIR Filter
// Coefficients : h = [1, 2, 3, 4]
//
// Function:
//   - Holds the last 4 valid input samples.
//   - Calculates the weighted sum combinatorially.
//   - oDataOut is available immediately from the current
//     input sample and the previous stored samples.
//   - oValidOut follows iValidIn combinatorially.
//
// Important:
//   This version removes the registered output delay.
//   It is suitable when oValidOut is connected directly to
//   the FIFO write enable and oDataOut to FIFO write data.
//============================================================

module FIR_Filter (
    input  wire        iClkFast,   // Fast domain clock
    input  wire        iRstN,      // Asynchronous active-low reset
    input  wire [7:0]  iDataIn,    // Streaming input data sample
    input  wire        iValidIn,   // Indicates current input is valid

    output wire [15:0] oDataOut,   // Combinational weighted sum output
    output wire        oValidOut   // Combinational valid output
);

    //--------------------------------------------------------
    // Shift Register
    //
    // rX0 = newest stored sample
    // rX1 = one-cycle delayed sample
    // rX2 = two-cycle delayed sample
    // rX3 = three-cycle delayed sample
    //--------------------------------------------------------
    reg [7:0] rX0;
    reg [7:0] rX1;
    reg [7:0] rX2;
    reg [7:0] rX3;

    //--------------------------------------------------------
    // FIR calculation
    //
    // Current input sample is used directly as x[0].
    // Stored registers are used as x[1], x[2], x[3].
    //
    // Formula:
    //   y[n] = x[n]*1 + x[n-1]*2 + x[n-2]*3 + x[n-3]*4
    //--------------------------------------------------------
    wire [15:0] wX0;
    wire [15:0] wX1;
    wire [15:0] wX2;
    wire [15:0] wX3;

    assign wX0 = {8'd0, iDataIn};
    assign wX1 = {8'd0, rX0};
    assign wX2 = {8'd0, rX1};
    assign wX3 = {8'd0, rX2};

    //--------------------------------------------------------
    // Multiplication by constants using shift/add
    //--------------------------------------------------------
    wire [15:0] wTerm0;
    wire [15:0] wTerm1;
    wire [15:0] wTerm2;
    wire [15:0] wTerm3;

    assign wTerm0 = wX0;                 // x[0] * 1
    assign wTerm1 = wX1 << 1;            // x[1] * 2
    assign wTerm2 = (wX2 << 1) + wX2;    // x[2] * 3
    assign wTerm3 = wX3 << 2;            // x[3] * 4

    //--------------------------------------------------------
    // Combinational output
    //
    // No output register here.
    // This removes the extra clock delay.
    //--------------------------------------------------------
    assign oDataOut  = wTerm0 + wTerm1 + wTerm2 + wTerm3;
    assign oValidOut = iValidIn;

    //--------------------------------------------------------
    // Shift-register update
    //
    // Registers update only when iValidIn is high.
    // Use nonblocking assignments in sequential logic.
    //--------------------------------------------------------
    always @(posedge iClkFast or negedge iRstN) begin
        if (!iRstN) begin
            rX0 <= 8'd0;
            rX1 <= 8'd0;
            rX2 <= 8'd0;
            rX3 <= 8'd0;
        end
        else begin
            if (iValidIn) begin
                rX0 <= iDataIn;
                rX1 <= rX0;
                rX2 <= rX1;
                rX3 <= rX2;
            end
        end
    end

endmodule