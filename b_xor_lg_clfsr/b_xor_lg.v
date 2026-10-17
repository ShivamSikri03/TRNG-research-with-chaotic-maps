// ============================================================================
// File: b_xor_lg.v
// Module: b_xor_lg
// Description: Proposed B-XOR-LG (Balanced XOR Logic Gate) Module
//              Based on Figure 5 of the reference paper.
//
//              This module replaces the 4:1 MUX in the traditional TRNG design.
//              Instead of selecting ONE oscillator at a time (MUX behavior),
//              the B-XOR-LG mixes ALL 4 oscillator outputs simultaneously
//              through a cross-coupled XOR network, producing 3 independent
//              output streams.
//
// Architecture (2-Stage Cross-Coupled XOR Network):
//
//   Stage 1 (Cross-Connected Pairs):
//     s1 = in1 XOR in3   (diagonal cross-coupling)
//     s2 = in2 XOR in4   (diagonal cross-coupling)
//
//   Stage 2 (Output Mixing):
//     out1 = s1 XOR in2  = in1 XOR in2 XOR in3         (3-input mix)
//     out2 = s1 XOR s2   = in1 XOR in2 XOR in3 XOR in4 (4-input mix)
//     out3 = s2 XOR in3  = in2 XOR in3 XOR in4         (3-input mix)
//
// Properties:
//   - 4 inputs  → 3 outputs
//   - 5 XOR gates total (2 in Stage 1 + 3 in Stage 2)
//   - Every output depends on at least 3 inputs → superior entropy mixing
//   - Purely combinational (no clock, no select lines, no feedback loops)
//   - Each output has a different combination of inputs → decorrelated outputs
//
// Inputs:
//   in1 = RO_3  output (3-stage ring oscillator)
//   in2 = RO_5  output (5-stage ring oscillator)
//   in3 = RO    output (7-stage ring oscillator)
//   in4 = FIRO  output (chaotic free-running inverter ring oscillator)
//
// Outputs:
//   out1 = in1 ^ in2 ^ in3         (RO_3 ^ RO_5 ^ RO_7)
//   out2 = in1 ^ in2 ^ in3 ^ in4  (all four oscillators mixed)
//   out3 = in2 ^ in3 ^ in4         (RO_5 ^ RO_7 ^ FIRO)
// ============================================================================

`timescale 1ns/1ps

module b_xor_lg (
    input  wire in1,    // Entropy source 1 (e.g., RO_3 output)
    input  wire in2,    // Entropy source 2 (e.g., RO_5 output)
    input  wire in3,    // Entropy source 3 (e.g., RO_7 output)
    input  wire in4,    // Entropy source 4 (e.g., FIRO output)
    output wire out1,   // Mixed output 1: in1 ^ in2 ^ in3
    output wire out2,   // Mixed output 2: in1 ^ in2 ^ in3 ^ in4
    output wire out3    // Mixed output 3: in2 ^ in3 ^ in4
);

    // ========================================================================
    // Stage 1: Cross-Connected Diagonal XOR Pairs
    //          Creates intermediate signals by XOR-ing non-adjacent inputs
    // ========================================================================
    wire s1, s2;

    assign s1 = in1 ^ in3;    // Cross-couple: input 1 with input 3
    assign s2 = in2 ^ in4;    // Cross-couple: input 2 with input 4

    // ========================================================================
    // Stage 2: Output XOR Gates (Mix Stage 1 with remaining inputs)
    //          Each output combines a unique subset of the 4 inputs
    // ========================================================================
    assign out1 = s1 ^ in2;   // = in1 ^ in2 ^ in3
    assign out2 = s1 ^ s2;    // = in1 ^ in2 ^ in3 ^ in4
    assign out3 = s2 ^ in3;   // = in2 ^ in3 ^ in4

endmodule
