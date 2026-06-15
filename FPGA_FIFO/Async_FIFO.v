module async_fifo #(
    parameter addr_width = 4, // 16 entries (2^4)
    parameter data_width = 16
)(
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire [data_width-1:0] wdata,
    input  wire                  winc,
    input  wire                  rinc,
    output wire [data_width-1:0] rdata,
    output reg                   wfull,
    output reg                   rempty
);

    // 1. register-based memory array
    localparam depth = 1 << addr_width;
    reg [data_width-1:0] mem [0:depth-1];

    // internal binary and gray pointers (width is addr_width + 1 for msb full/empty tracking)
    reg  [addr_width:0] wptr_bin, rptr_bin;
    reg  [addr_width:0] wptr_gray, rptr_gray;
    wire [addr_width:0] wptr_gray_next, rptr_gray_next;
    wire [addr_width:0] wptr_bin_next, rptr_bin_next;

    // synchronizer registers
    reg [addr_width:0] wq1_rptr, wq2_rptr; // read pointer synced to write domain
    reg [addr_width:0] rq1_wptr, rq2_wptr; // write pointer synced to read domain

    // ---------------------------------------------------------
    // memory write & read
    // ---------------------------------------------------------
    always @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[wptr_bin[addr_width-1:0]] <= wdata;
        end
    end

    // continuous assignment for read data (combinatorial read from register array)
    assign rdata = mem[rptr_bin[addr_width-1:0]];

    // ---------------------------------------------------------
    // write domain: binary pointer & gray code generation
    // ---------------------------------------------------------
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= 0;
            wptr_gray <= 0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    assign wptr_bin_next  = wptr_bin + (winc & ~wfull);
    assign wptr_gray_next = wptr_bin_next ^ (wptr_bin_next >> 1); // binary to gray

    // ---------------------------------------------------------
    // read domain: binary pointer & gray code generation
    // ---------------------------------------------------------
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= 0;
            rptr_gray <= 0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    assign rptr_bin_next  = rptr_bin + (rinc & ~rempty);
    assign rptr_gray_next = rptr_bin_next ^ (rptr_bin_next >> 1); // binary to gray

    // ---------------------------------------------------------
    // 2-ff synchronizers (cdc)
    // ---------------------------------------------------------
    // sync read pointer into write domain
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wq1_rptr <= 0;
            wq2_rptr <= 0;
        end else begin
            wq1_rptr <= rptr_gray;
            wq2_rptr <= wq1_rptr;
        end
    end

    // sync write pointer into read domain
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr <= 0;
            rq2_wptr <= 0;
        end else begin
            rq1_wptr <= wptr_gray;
            rq2_wptr <= rq1_wptr;
        end
    end

    // ---------------------------------------------------------
    // full and empty logic
    // ---------------------------------------------------------
    // empty condition: synced write pointer equals current read gray pointer
    wire rempty_val = (rptr_gray_next == rq2_wptr);
    
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) rempty <= 1'b1;
        else         rempty <= rempty_val;
    end

    // full condition: synced read pointer has inverted 2 msb bits, but identical lsb bits
    wire wfull_val = (wptr_gray_next == {~wq2_rptr[addr_width:addr_width-1], wq2_rptr[addr_width-2:0]});
    
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= wfull_val;
    end

endmodule