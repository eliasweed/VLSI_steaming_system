//============================================================
// File        : Power_Controller.v
// Module      : Power_Controller
// Description : Dynamic power controller for fast clock domain
//
// Function:
//   - Monitors iInValid from the FIR input stream.
//   - If iInValid stays low for IDLE_TIMEOUT consecutive
//     iFastClk cycles, oClkEn goes low.
//   - When iInValid becomes high again, oClkEn returns high.
//   - oClkEn controls ALTCLKCTRL.
//
// Important:
//   - The controller itself must stay on iFastClk.
//   - Only the FIR clock should be gated.
//   - Do NOT implement clock gating using:
//         assign gated_clk = clk & enable;
//============================================================

module Power_Controller
#(
    parameter integer IDLE_TIMEOUT = 10
)
(
    input  wire iFastClk,       // Fast clock domain, for example 100 MHz
    input  wire iResetN,        // Asynchronous active-low reset
    input  wire iInValid,       // Activity indication from FIR input stream

    output reg  oClkEn,         // Clock enable control signal
    output wire oGatedFastClk   // Gated fast clock output for FIR
);

    //--------------------------------------------------------
    // Verilog-2001 compatible clog2 function
    //--------------------------------------------------------
    function integer clog2;
        input integer value;
        integer temp;
        begin
            temp = value - 1;
            for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
                temp = temp >> 1;
        end
    endfunction

    //--------------------------------------------------------
    // Counter width
    //--------------------------------------------------------
    localparam integer CNT_W = (IDLE_TIMEOUT <= 2) ? 1 : clog2(IDLE_TIMEOUT + 1);

    //--------------------------------------------------------
    // Reload value for idle counter
    //--------------------------------------------------------
    localparam [CNT_W-1:0] IDLE_RELOAD = IDLE_TIMEOUT[CNT_W-1:0];

    //--------------------------------------------------------
    // Idle down-counter
    //--------------------------------------------------------
    reg [CNT_W-1:0] rIdleCnt;

    //--------------------------------------------------------
    // Power controller logic
    //
    // Behavior:
    //   iInValid = 1:
    //      reload counter and enable clock
    //
    //   iInValid = 0:
    //      count down
    //      when the counter reaches 1, disable clock
    //--------------------------------------------------------
    always @(posedge iFastClk or negedge iResetN) begin
        if (!iResetN) begin
            rIdleCnt <= IDLE_RELOAD;
            oClkEn   <= 1'b1;
        end
        else begin
            if (iInValid) begin
                rIdleCnt <= IDLE_RELOAD;
                oClkEn   <= 1'b1;
            end
            else begin
                if (rIdleCnt != {CNT_W{1'b0}}) begin
                    rIdleCnt <= rIdleCnt - 1'b1;

                    if (rIdleCnt == {{(CNT_W-1){1'b0}}, 1'b1}) begin
                        oClkEn <= 1'b0;
                    end
                end
            end
        end
    end

    //--------------------------------------------------------
    // Intel / Altera ALTCLKCTRL primitive
    //
    // This is the correct FPGA clock-gating method.
    // The fast clock and oClkEn are connected to ALTCLKCTRL.
    //--------------------------------------------------------
    altclkctrl u_altclkctrl
    (
        .inclk     ({3'b000, iFastClk}),
        .clkselect (2'b00),
        .ena       (oClkEn),
        .outclk    (oGatedFastClk)
    );

endmodule