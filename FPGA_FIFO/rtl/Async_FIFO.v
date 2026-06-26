//============================================================
// Module Name : Async_FIFO
// Description : Asynchronous Register-Based FIFO with Gray Code CDC
//
// Function:
//   - Safely transfers data between a high-speed write clock domain
//     and a slower read clock domain using 2-flip-flop synchronizers.
//   - Uses Gray code to prevent metastability during pointer transfer.
//   - Full and Empty flags are generated in their respective domains.
//
// Example:
//   If AddrWidth = 4
//   FIFO Depth = 16 entries
//
// Notes:
//   - Pointers are maintained with an extra MSB (N+1 bits) to
//     distinguish between wrap-around (Full) and catch-up (Empty).
//   - Register-based memory is used instead of Block RAM to allow
//     low latency and distributed logic implementation.
//============================================================

module Async_FIFO
#(
    parameter AddrWidth = 4, // Pointer width (defines FIFO depth as 2^AddrWidth)
    parameter DataWidth = 16 // Width of the data bus
)
(
    input  wire                 iWClk,   // Write domain clock
    input  wire                 iWRstN,  // Write domain asynchronous active-low reset
    input  wire                 iRClk,   // Read domain clock
    input  wire                 iRRstN,  // Read domain asynchronous active-low reset
    input  wire [DataWidth-1:0] iData,   // Data input to be written
    input  wire                 iWInc,   // Write increment (enable) signal
    input  wire                 iRInc,   // Read increment (enable) signal
    output wire [DataWidth-1:0] oData,   // Data output being read
    output reg                  oFull,   // FIFO full flag (sync'd to iWClk)
    output reg                  oEmpty   // FIFO empty flag (sync'd to iRClk)
);

    //--------------------------------------------------------
    // Memory Array Initialization
    //
    // Depth is calculated from the parameter AddrWidth.
    // A register array is used for the memory block.
    //--------------------------------------------------------
    localparam Depth = 1 << AddrWidth;
    reg [DataWidth-1:0] Mem [0:Depth-1];

    //--------------------------------------------------------
    // Pointers Declaration
    //
    // Pointers are N+1 bits wide [AddrWidth:0] to handle the 
    // wrap-around condition, allowing distinction between 
    // Full and Empty states.
    //--------------------------------------------------------
    reg  [AddrWidth:0] wPtrBin, rPtrBin;   // Binary pointers for memory addressing
    reg  [AddrWidth:0] wPtrGray, rPtrGray; // Gray code pointers for CDC transfer
    
    wire [AddrWidth:0] wPtrGrayNext, rPtrGrayNext;
    wire [AddrWidth:0] wPtrBinNext, rPtrBinNext;

    // Synchronizer registers (2-FF synchronization chain)
    reg [AddrWidth:0] wQ1RPtr, wQ2RPtr; // Read pointer synchronized into Write domain
    reg [AddrWidth:0] rQ1WPtr, rQ2WPtr; // Write pointer synchronized into Read domain

    //--------------------------------------------------------
    // Memory Write & Read Logic
    //
    // Write operation: Synchronous to iWClk. Only writes if 
    // requested and FIFO is not full.
    // Read operation: Combinatorial assignment directly from 
    // the register array.
    //--------------------------------------------------------
    always @(posedge iWClk) begin
        if (iWInc && !oFull) begin
            Mem[wPtrBin[AddrWidth-1:0]] <= iData;
        end
    end

    assign oData = Mem[rPtrBin[AddrWidth-1:0]];

    //--------------------------------------------------------
    // Write Domain: Pointer Management & Gray Code
    //
    // Calculates the next binary pointer and converts it to 
    // Gray code (G = B XOR (B >> 1)).
    //--------------------------------------------------------
    always @(posedge iWClk or negedge iWRstN) begin
        if (!iWRstN) begin
            wPtrBin  <= 0;
            wPtrGray <= 0;
        end else begin
            wPtrBin  <= wPtrBinNext;
            wPtrGray <= wPtrGrayNext;
        end
    end

    assign wPtrBinNext  = wPtrBin + (iWInc & ~oFull);
    assign wPtrGrayNext = wPtrBinNext ^ (wPtrBinNext >> 1);

    //--------------------------------------------------------
    // Read Domain: Pointer Management & Gray Code
    //
    // Calculates the next binary read pointer and converts it 
    // to Gray code.
    //--------------------------------------------------------
    always @(posedge iRClk or negedge iRRstN) begin
        if (!iRRstN) begin
            rPtrBin  <= 0;
            rPtrGray <= 0;
        end else begin
            rPtrBin  <= rPtrBinNext;
            rPtrGray <= rPtrGrayNext;
        end
    end

    assign rPtrBinNext  = rPtrBin + (iRInc & ~oEmpty);
    assign rPtrGrayNext = rPtrBinNext ^ (rPtrBinNext >> 1);

    //--------------------------------------------------------
    // Clock Domain Crossing (CDC) - 2-FF Synchronizers
    //
    // Safely transfers the Gray code pointers across the clock
    // domains using two stages of flip-flops to mitigate 
    // metastability.
    //--------------------------------------------------------
    always @(posedge iWClk or negedge iWRstN) begin
        if (!iWRstN) begin
            wQ1RPtr <= 0;
            wQ2RPtr <= 0;
        end else begin
            wQ1RPtr <= rPtrGray; 
            wQ2RPtr <= wQ1RPtr;  
        end
    end

    always @(posedge iRClk or negedge iRRstN) begin
        if (!iRRstN) begin
            rQ1WPtr <= 0;
            rQ2WPtr <= 0;
        end else begin
            rQ1WPtr <= wPtrGray; 
            rQ2WPtr <= rQ1WPtr;  
        end
    end

    //--------------------------------------------------------
    // Full & Empty Condition Logic
    //
    // Empty condition is evaluated in the Read domain when 
    // the read pointer catches up to the synchronized write pointer.
    //
    // Full condition is evaluated in the Write domain when 
    // the synchronized read pointer's 2 MSBs are inverted 
    // compared to the write pointer.
    //--------------------------------------------------------
    wire rEmptyVal;
    assign rEmptyVal = (rPtrGrayNext == rQ2WPtr);
    
    always @(posedge iRClk or negedge iRRstN) begin
        if (!iRRstN) oEmpty <= 1'b1;
        else         oEmpty <= rEmptyVal;
    end

    wire wFullVal;
    assign wFullVal = (wPtrGrayNext == {~wQ2RPtr[AddrWidth:AddrWidth-1], wQ2RPtr[AddrWidth-2:0]});
    
    always @(posedge iWClk or negedge iWRstN) begin
        if (!iWRstN) oFull <= 1'b0;
        else         oFull <= wFullVal;
    end

endmodule