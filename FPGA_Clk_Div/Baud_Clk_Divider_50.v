//============================================================
// Module Name : Baud_Clk_Divider_50
// Description : 50% duty-cycle clock divider for UART baud clock
//
// Function:
//   - Divides the input clock by 2*HALF_DIV.
//   - Output clock toggles every HALF_DIV input clock cycles.
//   - Uses a down-counter.
//   - Terminal count is detected using only ONE BIT:
//       wCntDec[CNT_W]
//     This bit becomes '1' when the counter underflows.
//
// Example:
//   If input clock = 10 MHz
//   HALF_DIV = 520
//
//   Output frequency:
//       Fout = 10 MHz / (2 * 520)
//            = 9615.38 Hz
//
// Notes:
//   - For a real 9600 baud UART from 10 MHz, exact integer division
//     is not possible.
//   - This divider gives a close baud clock with 50% duty cycle.
//============================================================

module Baud_Clk_Divider_50
#(
    parameter HALF_DIV = 520
)
(
    input  wire iClk,       // Input clock, for example slow_clk = 10 MHz
    input  wire iResetN,    // Asynchronous active-low reset
    output reg  oClk        // Divided output clock, 50% duty cycle
);

    //--------------------------------------------------------
    // Counter width calculation
    //
    // HALF_DIV+1 is used so the counter has enough bits
    // to hold the reload value and also detect underflow.
    //--------------------------------------------------------
    localparam CNT_W = $clog2(HALF_DIV + 1);

    //--------------------------------------------------------
    // Counter register
    //
    // rCnt is declared with one extra bit:
    //   [CNT_W:0]
    //
    // The extra MSB is used as the underflow indication bit.
    //--------------------------------------------------------
    reg [CNT_W:0] rCnt;

    //--------------------------------------------------------
    // Decremented counter value
    //
    // This wire calculates rCnt - 1 before loading the register.
    // The MSB of this result is used to detect underflow.
    //
    // This avoids using a wide comparator such as:
    //   if (rCnt == 0)
    //
    // Instead, only one bit is checked:
    //   if (wCntDec[CNT_W])
    //--------------------------------------------------------
    wire [CNT_W:0] wCntDec;

    assign wCntDec = rCnt - 1'b1;

    //--------------------------------------------------------
    // Clock divider logic
    //
    // Reset:
    //   - Load the counter with HALF_DIV-1.
    //   - Drive output clock low.
    //
    // Normal operation:
    //   - Counter counts down.
    //   - When underflow is detected, reload counter and toggle oClk.
    //--------------------------------------------------------
    always @(posedge iClk or negedge iResetN) begin
        if (!iResetN) begin
            rCnt <= HALF_DIV - 1'b1;
            oClk <= 1'b0;
        end
        else begin
            if (wCntDec[CNT_W]) begin
                rCnt <= HALF_DIV - 1'b1;
                oClk <= ~oClk;
            end
            else begin
                rCnt <= wCntDec;
            end
        end
    end

endmodule