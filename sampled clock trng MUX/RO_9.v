// ============================================================================
// File: RO_9.v
// Module: RO_9
// Description: 9-Stage Ring Oscillator (1 NAND + 8 Inverters)
//              Features simulation jitter model and Vivado synthesis attributes.
// ============================================================================

`timescale 1ns/1ps

(* KEEP_HIERARCHY = "TRUE" *)
module RO_9 (
    input  wire enable,
    (* DONT_TOUCH = "TRUE" *) output wire out
);

`ifndef SYNTHESIS
    // Simulation Model with randomized jitter and oscillation kickstart
    (* DONT_TOUCH = "TRUE" *) wire w1, w2, w3, w4, w5, w6, w7, w8, w_nand;
    integer d1 = 1, d2 = 1, d3 = 1, d4 = 1, d5 = 1, d6 = 1, d7 = 1, d8 = 1, d_nand = 1;

    always begin
        #4;
        d1     = 1 + ({$urandom} % 3);
        d2     = 1 + ({$urandom} % 3);
        d3     = 1 + ({$urandom} % 3);
        d4     = 1 + ({$urandom} % 3);
        d5     = 1 + ({$urandom} % 3);
        d6     = 1 + ({$urandom} % 3);
        d7     = 1 + ({$urandom} % 3);
        d8     = 1 + ({$urandom} % 3);
        d_nand = 1 + ({$urandom} % 3);
    end

    assign #(d1) w1 = ~w_nand;
    assign #(d2) w2 = ~w1;
    assign #(d3) w3 = ~w2;
    assign #(d4) w4 = ~w3;
    assign #(d5) w5 = ~w4;
    assign #(d6) w6 = ~w5;
    assign #(d7) w7 = ~w6;
    assign #(d8) w8 = ~w7;
    assign #(d_nand) w_nand = ~(w8 & enable);
    assign out = w_nand;

    initial begin
        force w_nand = 1'b0;
        #10;
        release w_nand;
    end

`else
    // Hardware Synthesis Model for Xilinx Artix-7 FPGA
    (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) wire w1, w2, w3, w4, w5, w6, w7, w8, w_nand;

    assign w1     = ~w_nand;
    assign w2     = ~w1;
    assign w3     = ~w2;
    assign w4     = ~w3;
    assign w5     = ~w4;
    assign w6     = ~w5;
    assign w7     = ~w6;
    assign w8     = ~w7;
    assign w_nand = ~(w8 & enable);
    assign out    = w_nand;

`endif

endmodule
