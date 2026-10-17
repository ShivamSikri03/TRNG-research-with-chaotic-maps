// ============================================================================
// File: D_FF.v
// Module: D_FF
// Description: D Flip-Flop with synthesis DONT_TOUCH protection and simulation delay
// ============================================================================

`timescale 1ns/1ps

module D_FF(
    input  wire clk,
    input  wire in,
    (* DONT_TOUCH = "TRUE" *) output reg out
);
`ifndef SYNTHESIS
always @(posedge clk) begin
   #1 out <= in;
end
`else
always @(posedge clk) begin
   out <= in;
end
`endif
endmodule
