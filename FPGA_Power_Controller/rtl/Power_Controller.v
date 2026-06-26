//============================================================
// File        : Power_Controller.v
// Module      : Power_Controller
// Description : Dynamic power controller for fast clock domain
//
// Fix:
//   oClkEn is updated on the falling edge of iFastClk.
//   This makes the clock-enable stable before the next rising edge,
//   preventing an extra leaked gated-clock pulse.
//
// Behavior:
//   - If iInValid = 1:
//       counter reloads and clock is enabled.
//   - If iInValid = 0 for IDLE_TIMEOUT cycles:
//       oClkEn goes low before the next rising clock edge.
//============================================================

module Power_Controller
#(
    parameter integer IDLE_TIMEOUT = 10,
    parameter integer SIM_MODE     = 0
)
(
    input  wire iFastClk,
    input  wire iResetN,
    input  wire iInValid,

    output reg  oClkEn,
    output wire oGatedFastClk
);

    //--------------------------------------------------------
    // Verilog-2001 compatible clog2
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

    localparam integer CNT_W = (IDLE_TIMEOUT <= 2) ? 1 : clog2(IDLE_TIMEOUT + 1);

    localparam [CNT_W-1:0] IDLE_RELOAD = IDLE_TIMEOUT[CNT_W-1:0];

    reg [CNT_W-1:0] rIdleCnt;

    //--------------------------------------------------------
    // Internal request signal.
    //
    // This signal is generated on the rising edge.
    // It says whether the clock should remain enabled.
    //--------------------------------------------------------
    reg rClkEnReq;

    //--------------------------------------------------------
    // Activity / idle counter
    //
    // This block counts the number of idle cycles.
    //--------------------------------------------------------
    always @(posedge iFastClk or negedge iResetN) begin
        if (!iResetN) begin
            rIdleCnt  <= IDLE_RELOAD;
            rClkEnReq <= 1'b1;
        end
        else begin
            if (iInValid) begin
                rIdleCnt  <= IDLE_RELOAD;
                rClkEnReq <= 1'b1;
            end
            else begin
                if (rIdleCnt != {CNT_W{1'b0}}) begin
                    rIdleCnt <= rIdleCnt - 1'b1;

                    //------------------------------------------------
                    // When old counter value is 1, this is the
                    // timeout-completing clock edge.
                    //------------------------------------------------
                    if (rIdleCnt == {{(CNT_W-1){1'b0}}, 1'b1}) begin
                        rClkEnReq <= 1'b0;
                    end
                end
                else begin
                    rClkEnReq <= 1'b0;
                end
            end
        end
    end

    //--------------------------------------------------------
    // Clock-gate enable register
    //
    // IMPORTANT:
    // oClkEn is updated on negedge, not posedge.
    //
    // Reason:
    // If oClkEn is updated on posedge, the same rising edge is
    // already passed through the clock gate.
    //
    // Updating on negedge makes oClkEn stable while iFastClk is low,
    // before the next rising edge arrives.
    //--------------------------------------------------------
    always @(negedge iFastClk or negedge iResetN) begin
        if (!iResetN) begin
            oClkEn <= 1'b1;
        end
        else begin
            oClkEn <= rClkEnReq;
        end
    end

    //--------------------------------------------------------
    // Clock gating implementation
    //--------------------------------------------------------
    generate
        if (SIM_MODE != 0) begin : g_SIM_MODEL
            //------------------------------------------------
            // Simulation model only.
            // In synthesis, use ALTCLKCTRL.
            //------------------------------------------------
            assign oGatedFastClk = oClkEn ? iFastClk : 1'b0;
        end
        else begin : g_ALTCLKCTRL
            //------------------------------------------------
            // Intel / Altera clock-control primitive.
            //------------------------------------------------
            altclkctrl u_altclkctrl
            (
                .inclk     ({3'b000, iFastClk}),
                .clkselect (2'b00),
                .ena       (oClkEn),
                .outclk    (oGatedFastClk)
            );
        end
    endgenerate

endmodule