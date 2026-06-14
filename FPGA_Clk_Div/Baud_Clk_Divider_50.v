module Baud_Clk_Divider_50
#(
    parameter HALF_DIV = 520
)
(
    input  wire iClk    ,
    input  wire iResetN ,
    output reg  oClk
);

localparam              CNT_W = $clog2(HALF_DIV+1)  ;
reg         [CNT_W:0]   rCnt                        ;


always @(posedge iClk or negedge iResetN) begin
    if(!iResetN) begin
        rCnt    <= HALF_DIV-1   ;
        oClk    <= 1'b0         ;
    end
    else begin
        rCnt    <= rCnt - 1'b1  ;

        if(rCnt[CNT_W]) begin
            rCnt <= HALF_DIV-1  ;
            oClk <= ~oClk       ;
        end
    end
end

endmodule