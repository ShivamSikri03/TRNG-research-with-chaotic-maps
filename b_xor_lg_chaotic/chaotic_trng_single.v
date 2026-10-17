// ============================================================================
// File: chaotic_trng_single.v
// Module: chaotic_trng_single
// Description: Standalone Chaotic-TRNG Hybrid Core (No LFSR)
//              Features:
//              1. 5-Stage Pipelined 2nd-Order Chebyshev Chaotic Map:
//                 X(n+1) = 1 - 2 * X(n)^2  in signed Q1.15 fixed-point.
//                 (LFSR shift registers and feedback logic are completely eliminated)
//              2. Real-Time 1-Bit XOR Fusion:
//                 chaotic_bit = x[10]
//                 random_bit  = chaotic_bit ^ trng_in (physical entropy from MUX)
//              3. Serial-to-Parallel 8-Bit Byte Assembly:
//                 Accumulates 8 consecutive fused random bits into R_Out with key_ready.
// ============================================================================

`timescale 1ns/1ps

module chaotic_trng_single #(
    parameter signed [15:0] CHAOTIC_INIT_SEED = 16'sh7EF0  // Q1.15 initial seed in [-1.0, +1.0]
)(
    input  wire        clk,          // System clock
    input  wire        rst,          // Asynchronous active-high reset
    input  wire        enable,       // Enable generator (1 = run, 0 = freeze/pause)
    input  wire        trng_in,      // Physical TRNG bit from 4:1 MUX
    
    // --- 1-Bit Serial Outputs (Active every clock cycle) ---
    output wire        chaotic_bit,  // Standalone 1-bit chaotic output (x[10], NO LFSR)
    output wire        random_bit,   // 1-bit fused output: (chaotic_bit ^ trng_in)
    
    // --- 8-Bit Parallel Outputs (Assembled every 8 clock cycles) ---
    output reg  [7:0]  R_Out,        // 8-bit assembled byte from XOR-ed stream
    output reg         key_ready,    // 1-cycle active-high strobe when R_Out is valid
    output wire [7:0]  random_byte,  // Compatibility alias for R_Out
    output wire        byte_ready,   // Compatibility alias for key_ready
    output wire signed [15:0] x_state // Raw 16-bit Q1.15 chaotic state (debug/analysis)
);

    // Compatibility aliases
    assign random_byte = R_Out;
    assign byte_ready  = key_ready;
    assign x_state     = x;

    // ------------------------------------------------------------------------
    // 1. 5-Stage Pipelined 2nd-Order Chebyshev Chaotic Map
    //    Equation: X_(n+1) = 1 - 2 * (X_n)^2   in signed Q1.15 fixed-point
    // ------------------------------------------------------------------------
    reg signed [15:0] x;             // State variable (Q1.15)
    reg signed [31:0] x_square;      // Stage 1: x * x (Q2.30)
    reg signed [31:0] x_mult;        // Stage 2: 2 * x^2 (Q1.31)
    reg signed [15:0] x_section;     // Stage 3: Extract bits [30:15] -> Q1.15
    reg signed [15:0] x_sub;         // Stage 4: 1.0 - (2 * x^2) where 1.0 ~= 16'sh7FFF

    // ------------------------------------------------------------------------
    // 2. 1-Bit Chaotic Output & Real-Time MUX TRNG XOR Fusion
    // ------------------------------------------------------------------------
    // Standalone chaotic bit taken from bit [10] of the Chebyshev map (NO LFSR!)
    assign chaotic_bit = x[10];

    // Real-time bitwise XOR of 1-bit Chaotic generator with 1-bit sampled MUX TRNG
    assign random_bit  = chaotic_bit ^ trng_in;

    // ------------------------------------------------------------------------
    // 3. Sequential Logic & 8-Bit Serial-to-Parallel Byte Assembly
    // ------------------------------------------------------------------------
    reg [2:0] bit_counter;
    reg [7:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset Chaotic Map Pipeline
            x           <= CHAOTIC_INIT_SEED;
            x_square    <= 32'sh0;
            x_mult      <= 32'sh0;
            x_section   <= 16'sh0;
            x_sub       <= CHAOTIC_INIT_SEED;

            // Reset Serial-to-Parallel Registers
            bit_counter <= 3'b000;
            shift_reg   <= 8'h00;
            R_Out       <= 8'h00;
            key_ready   <= 1'b0;

        end else if (enable) begin
            // --- Advance Chaotic Map Pipeline (5 Stages) ---
            x_square    <= x * x;                       // Stage 1: Square
            x_mult      <= x_square <<< 1;              // Stage 2: Multiply by 2
            x_section   <= x_mult[30:15];               // Stage 3: Re-scale to Q1.15
            x_sub       <= 16'sh7FFF - x_section;       // Stage 4: 1.0 - 2*x^2
            x           <= x_sub;                       // Stage 5: State feedback

            // --- Accumulate 1-Bit Fused Stream into 8-Bit Shift Register ---
            shift_reg   <= {shift_reg[6:0], random_bit};

            // --- Strobe and Latch Byte every 8 clocks ---
            if (bit_counter == 3'b111) begin
                R_Out       <= {shift_reg[6:0], random_bit}; // Latch full byte
                key_ready   <= 1'b1;
                bit_counter <= 3'b000;
            end else begin
                key_ready   <= 1'b0;
                bit_counter <= bit_counter + 1'b1;
            end
        end else begin
            key_ready <= 1'b0;
        end
    end

endmodule
