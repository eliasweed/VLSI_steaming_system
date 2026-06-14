module digital_filter (
    input  wire         clk_fast ,
    input  wire         rst_n    ,
    input  wire [7:0 ]  data_in  ,
    input  wire         valid_in ,
    output reg  [15:0]  data_out ,
    output reg          valid_out
);

    // shift register
    reg [7:0] x [0:3];

    // zero-padded wires for the next state calculation
    wire [15:0] next_x0 = {8'h00, data_in}; //create 16 bit vector that starts with 8 zeros
    wire [15:0] next_x1 = {8'h00, x[0]};
    wire [15:0] next_x2 = {8'h00, x[1]};
    wire [15:0] next_x3 = {8'h00, x[2]};

    // hardware-efficient multiplication using bit-shifts
    wire [15:0] mult_0 = next_x0;                                     // x[0] * 1
    wire [15:0] mult_1 = {next_x1[14:0], 1'b0};                       // x[1] * 2 (shift left by 1)
    wire [15:0] mult_2 = {next_x2[14:0], 1'b0} + next_x2;             // x[2] * 3 (x[2]*2 + x[2]*1)
    wire [15:0] mult_3 = {next_x3[13:0], 2'b0};                       // x[3] * 4 (shift left by 2)

    // combinatorial sum
    wire [15:0] sum_calc = mult_0 + mult_1 + mult_2 + mult_3;

    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n) begin
            x[0]      <= 8'd0;
            x[1]      <= 8'd0;
            x[2]      <= 8'd0;
            x[3]      <= 8'd0;
            data_out  <= 16'd0;
            valid_out <= 1'b0;
        end else begin
            if (valid_in) begin
                // shift incoming data forward
                x[0] <= data_in;
                x[1] <= x[0];
                x[2] <= x[1];
                x[3] <= x[2];

                // pipeline stage: capture the calculated combinatorial sum
                data_out  <= sum_calc;
                valid_out <= 1'b1;
            end else begin
                // assert valid_out to low when data is not valid
                valid_out <= 1'b0;
            end
        end
    end

endmodule