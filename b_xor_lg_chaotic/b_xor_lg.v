// ============================================================================
// File: b_xor_lg.v
// Module: b_xor_lg
// Description: Proposed B-XOR-LG (Braided / Balanced XOR Logic Gate) Module
//              Faithfully implemented based on FIGURE 5 of the reference paper:
//              "A True Random Number Generator Based on Race Hazard and Jitter 
//               of Braided and Cross-Coupled Logic Gates Using FPGA" (IEEE Access, 2024).
//
// Schematic Structure (Figure 5):
//   - 4 Inputs: in1, in2, in3, in4
//   - 3 Outputs: out1, out2, out3
//   - 7 XOR Gates Total:
//     * Top CCX Pair:
//         Gate 1 (Top-Left XOR) : w_g1 = fb_top ^ in1
//         Gate 2 (Top-Right XOR): w_g2 = w_g1 ^ in4
//         Feedback loop         : fb_top = w_g2
//     * Bottom CCX Pair:
//         Gate 3 (Bot-Left XOR) : w_g3 = in4 ^ fb_bot
//         Gate 4 (Bot-Right XOR): w_g4 = in1 ^ w_g3
//         Feedback loop         : fb_bot = w_g4
//     * Center Routing:
//         in2 routes to Gate 6 and Gate 7
//         in3 routes to Gate 5 and Gate 6
//     * Output Stage (3 XOR Gates):
//         Gate 5 (Top Out) : out1 = w_g2 ^ in3
//         Gate 6 (Mid Out) : out2 = in3 ^ in2
//         Gate 7 (Bot Out) : out3 = in2 ^ w_g4
//
// Combined Output:
//   - out = out1 ^ out2 ^ out3 (XOR reduction of all 3 outputs into 1 output)
// ============================================================================

`timescale 1ns/1ps

module b_xor_lg (
    input  wire in1,      // Oscillator input 1 (e.g., RO_3 output)
    input  wire in2,      // Oscillator input 2 (e.g., RO_5 output)
    input  wire in3,      // Oscillator input 3 (e.g., RO 7-stage output)
    input  wire in4,      // Oscillator input 4 (e.g., FIRO_main output)
    output wire out1,     // Output 1: w_g2 ^ in3
    output wire out2,     // Output 2: in3 ^ in2
    output wire out3,     // Output 3: in2 ^ w_g4
    output wire out       // Fused 1-bit output: out1 ^ out2 ^ out3
);

`ifndef SYNTHESIS
    // ========================================================================
    // Simulation Model with small gate delays & initialization to resolve 
    // combinational feedback loops in event-driven simulators (Icarus / ModelSim)
    // ========================================================================
    wire w_g1, w_g2, fb_top;
    wire w_g3, w_g4, fb_bot;

    // Small inertia delay for simulation
    assign #1 w_g1 = fb_top ^ in1;
    assign #1 w_g2 = w_g1 ^ in4;
    assign #1 fb_top = w_g2;

    assign #1 w_g3 = in4 ^ fb_bot;
    assign #1 w_g4 = in1 ^ w_g3;
    assign #1 fb_bot = w_g4;

    assign #1 out1 = w_g2 ^ in3;
    assign #1 out2 = in3 ^ in2;
    assign #1 out3 = in2 ^ w_g4;

    // Initialize feedback loops on reset/startup to prevent 1'bx latch
    initial begin
        force fb_top = 1'b0;
        force fb_bot = 1'b0;
        #5;
        release fb_top;
        release fb_bot;
    end

`else
    // ========================================================================
    // Synthesizable RTL for Xilinx Vivado Implementation
    // DONT_TOUCH prevents logic trimming and optimization across feedback paths
    // ========================================================================
    (* DONT_TOUCH = "TRUE" *) wire w_g1, w_g2, fb_top;
    (* DONT_TOUCH = "TRUE" *) wire w_g3, w_g4, fb_bot;

    // Top Cross-Coupled XOR Pair (Gate 1 & Gate 2)
    assign w_g1 = fb_top ^ in1;
    assign w_g2 = w_g1 ^ in4;
    assign fb_top = w_g2;

    // Bottom Cross-Coupled XOR Pair (Gate 3 & Gate 4)
    assign w_g3 = in4 ^ fb_bot;
    assign w_g4 = in1 ^ w_g3;
    assign fb_bot = w_g4;

    // Output Stage (Gate 5, Gate 6, Gate 7)
    assign out1 = w_g2 ^ in3;
    assign out2 = in3 ^ in2;
    assign out3 = in2 ^ w_g4;

`endif

    // XOR reduction of the 3 outputs into a single output
    assign out = out1 ^ out2 ^ out3;

endmodule
