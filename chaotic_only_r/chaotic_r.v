// ============================================================================
// File: chaotic_r.v
// Module: chaotic_r
// Description: Standalone Chaotic Random Number Generator (R-Channel Only, No LFSR)
//              Implements a 5-Stage Pipelined 2nd-Order Chebyshev Chaotic Map:
//                  X(n+1) = 1 - 2 * X(n)^2   in signed Q1.15 fixed-point arithmetic.
//
// Key Features:
//   1. Standalone Chaotic Map: Completely eliminates LFSR feedback logic, shift registers,
//      and LFSR seed dependencies, focusing exclusively on chaotic dynamical dynamics.
//   2. Dedicated R-Channel: Uses the Q1.15 chaotic state 'x' with default seed 16'sh7EF0.
//   3. Dual Random Outputs:
//      - 'chaotic_bit': 1-bit chaotic output (x[10]) available on every clock cycle.
//      - 'R_out': 8-bit chaotic random byte (x[10:3]) updated with 'key_ready' strobe.
//   4. 5-Stage Pipeline: Ensures high clock frequency capability on FPGA architectures.
// ============================================================================

`timescale 1ns/1ps

module chaotic_r #(
    parameter signed [15:0] CHAOTIC_INIT_SEED = 16'sh7EF0  // Q1.15 initial seed in [-1.0, +1.0]
)(
    input  wire        clk,         // System clock
    input  wire        rst,         // Asynchronous active-high reset
    input  wire        enable,      // Enable generator (1 = run, 0 = freeze)
    
    // Outputs
    output wire        chaotic_bit, // 1-bit chaotic output available every clock cycle
    output reg  [7:0]  R_out,       // 8-bit chaotic output byte (from chaotic state x[10:3])
    output reg         key_ready,   // 1-cycle active-high strobe when R_out is updated
    output wire signed [15:0] x_state // Raw 16-bit Q1.15 chaotic state (optional/debug)
);

    // ------------------------------------------------------------------------
    // 1. 5-Stage Pipelined 2nd-Order Chebyshev Chaotic Map
    //    Equation: X_(n+1) = 1 - 2 * (X_n)^2   in signed Q1.15 fixed-point
    // ------------------------------------------------------------------------
    reg signed [15:0] x;             // State variable (Q1.15)
    reg signed [31:0] x_square;      // Stage 1: x * x (Q2.30)
    reg signed [31:0] x_mult;        // Stage 2: 2 * x^2 (Q1.31)
    reg signed [15:0] x_section;     // Stage 3: Extract bits [30:15] -> back to Q1.15
    reg signed [15:0] x_sub;         // Stage 4: 1.0 - (2 * x^2) where 1.0 ~= 16'sh7FFF

    // ------------------------------------------------------------------------
    // 2. Bit Counter for 8-bit Byte Handshake
    // ------------------------------------------------------------------------
    reg [2:0] bit_counter;           // Counts 0 to 7 (8 clock cycles per byte)

    // Continuous 1-bit chaotic output & full state
    assign chaotic_bit = x[10];
    assign x_state     = x;

    // ------------------------------------------------------------------------
    // 3. Sequential Logic (Clocked Process)
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset Chaotic Pipeline
            x           <= CHAOTIC_INIT_SEED;
            x_square    <= 32'sh0;
            x_mult      <= 32'sh0;
            x_section   <= 16'sh0;
            x_sub       <= CHAOTIC_INIT_SEED;

            // Reset Output Registers
            R_out       <= 8'h00;
            key_ready   <= 1'b0;
            bit_counter <= 3'b000;

        end else if (enable) begin
            // --- Update Chaotic Map (5-Stage Pipeline) ---
            x_square    <= x * x;                       // Stage 1: Square (Q2.30)
            x_mult      <= x_square <<< 1;              // Stage 2: Multiply by 2 (Q1.31)
            x_section   <= x_mult[30:15];               // Stage 3: Re-scale to Q1.15
            x_sub       <= 16'sh7FFF - x_section;       // Stage 4: Subtract from ~1.0
            x           <= x_sub;                       // Stage 5: State feedback

            // --- 8-Bit Byte Assembly & Handshake ---
            if (bit_counter == 3'b111) begin
                key_ready   <= 1'b1;
                R_out       <= x[10:3];                 // 8-bit output directly from chaotic state
                bit_counter <= 3'b000;
            end else begin
                key_ready   <= 1'b0;
                bit_counter <= bit_counter + 1'b1;
            end

        end else begin
            // When enable is 0, freeze ready strobe
            key_ready <= 1'b0;
        end
    end

endmodule
