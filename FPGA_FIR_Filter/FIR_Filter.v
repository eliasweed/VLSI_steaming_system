//============================================================
// Module Name : FIR_Filter
// Description : 4-Tap Moving Average FIR Filter
//
// Function:
//   - Implements a shift register to hold the last 4 data samples.
//   - Calculates the average of the 4 samples in a single clock cycle.
//   - Fully pipelined and synchronous.
//
// Example:
//   If iData is an 8-bit stream, the filter keeps a 32-bit history
//   window (4 x 8-bit) and outputs the moving average, preventing
//   overflow and avoiding complex multi-cycle memory accesses.
//============================================================

module FIR_Filter
#(
    parameter DataWidth = 8 // Width of the input and output data bus
)
(
    input  wire                 iClk,   // Main processing clock (Fast Clock)
    input  wire                 iRstN,  // Asynchronous active-low reset
    input  wire [DataWidth-1:0] iData,  // Streaming input data sample
    output reg  [DataWidth-1:0] oData   // Averaged output data
);

    //--------------------------------------------------------
    // Shift Register (Sliding Window)
    //
    // Holds the 4 most recent data samples in a continuous
    // streaming pipeline.
    //--------------------------------------------------------
    reg [DataWidth-1:0] rReg0;
    reg [DataWidth-1:0] rReg1;
    reg [DataWidth-1:0] rReg2;
    reg [DataWidth-1:0] rReg3;

    //--------------------------------------------------------
    // Combinatorial Math (Adder Tree)
    //
    // Sums all 4 registers in parallel. 
    // The width is extended by 2 bits (DataWidth+1 : 0) to 
    // safely hold the maximum possible sum without overflow.
    //--------------------------------------------------------
    wire [DataWidth+1:0] wSum;
    
    assign wSum = rReg0 + rReg1 + rReg2 + rReg3;

    //--------------------------------------------------------
    // Shift and Calculate Logic
    //
    // Reset:
    //   - Clears all registers and output to zero.
    //
    // Normal operation:
    //   - Shifts data down the pipeline.
    //   - Samples the divided sum (average) in the same clock edge.
    //   - Division by 4 is optimized by discarding the 2 LSBs
    //     (taking bits [DataWidth+1 : 2] from wSum).
    //--------------------------------------------------------
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rReg0 <= 0;
            rReg1 <= 0;
            rReg2 <= 0;
            rReg3 <= 0;
            oData <= 0;
        end
        else begin
            // Shift the data stream
            rReg0 <= iData;
            rReg1 <= rReg0;
            rReg2 <= rReg1;
            rReg3 <= rReg2;
            
            // Calculate and register the average (Sum / 4)
            oData <= wSum[DataWidth+1:2];
        end
    end

endmodule