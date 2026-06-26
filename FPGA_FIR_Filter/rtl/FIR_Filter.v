//============================================================
// Module Name : FIR_Filter
// Description : 4-Tap Weighted FIR Filter (Coefficients: 1, 2, 3, 4)
//
// Function:
//   - Implements a shift register to hold the last 4 data samples.
//   - Updates the pipeline and calculates the weighted sum ONLY 
//     when input is valid (iValidIn).
//   - Combinatorial multiplication using shift-and-add logic:
//       oDataOut = (x[0]*1) + (x[1]*2) + (x[2]*3) + (x[3]*4)
//   - Fully pipelined: Valid output is indicated by oValidOut.
//============================================================

module FIR_Filter (
    input  wire        iClkFast,  // Fast domain clock
    input  wire        iRstN,     // Asynchronous active-low reset
    input  wire [7:0]  iDataIn,   // Streaming input data sample
    input  wire        iValidIn,  // Indicates current input is valid
    output reg  [15:0] oDataOut,  // Weighted sum output (Wide to prevent overflow)
    output reg         oValidOut  // Indicates output is ready (Connects to FIFO WE)
);

    //--------------------------------------------------------
    // Shift Register (Sliding Window)
    //--------------------------------------------------------
    reg [7:0] rX0; // Newest sample  (x[0])
    reg [7:0] rX1; // Delayed sample (x[1])
    reg [7:0] rX2; // Delayed sample (x[2])
    reg [7:0] rX3; // Oldest sample  (x[3])

    //--------------------------------------------------------
    // Combinatorial Math (Shift and Add)
    //
    // To achieve a fully pipelined design, we calculate the 
    // NEXT sum combinatorially using the incoming iDataIn 
    // as the new x[0], and the current registers as the rest.
    //--------------------------------------------------------
    wire [15:0] wX0 = iDataIn; // x[0]
    wire [15:0] wX1 = rX0;     // x[1]
    wire [15:0] wX2 = rX1;     // x[2]
    wire [15:0] wX3 = rX2;     // x[3]

    // Multiplications using bit-shifts:
    wire [15:0] wTerm0 = wX0;                        // x[0] * 1
    wire [15:0] wTerm1 = wX1 << 1;                   // x[1] * 2
    wire [15:0] wTerm2 = (wX2 << 1) + wX2;           // x[2] * 3
    wire [15:0] wTerm3 = wX3 << 2;                   // x[3] * 4

    // Combinatorial adder tree
    wire [15:0] wNextSum = wTerm0 + wTerm1 + wTerm2 + wTerm3;

    //--------------------------------------------------------
    // Pipeline Registers and Shift Logic
    //--------------------------------------------------------
    always @(posedge iClkFast or negedge iRstN) begin
        if (!iRstN) begin
            rX0 <= 8'b0;
            rX1 <= 8'b0;
            rX2 <= 8'b0;
            rX3 <= 8'b0;
            oDataOut  <= 16'b0;
            oValidOut <= 1'b0;
        end
        else begin
            // Valid output flag follows valid input with a 1-cycle pipeline delay
            oValidOut <= iValidIn;
            
            // Shift and update math ONLY when input data is valid
            if (iValidIn) begin
                rX0 <= iDataIn;
                rX1 <= rX0;
                rX2 <= rX1;
                rX3 <= rX2;
                
                // Register the calculated weighted sum
                oDataOut <= wNextSum;
            end
            // If !iValidIn, the registers (and oDataOut) safely hold their state.
        end
    end

endmodule