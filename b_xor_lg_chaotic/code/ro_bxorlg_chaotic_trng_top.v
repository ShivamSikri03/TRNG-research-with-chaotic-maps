// ============================================================================
// File: ro_bxorlg_chaotic_trng_top.v
// Module: ro_bxorlg_chaotic_trng_top
// Description: Multi-Oscillator B-XOR-LG TRNG with Standalone Chaotic 1-Bit XOR Core (No LFSR)
//
//   Replaces the 4:1 MUX with the Proposed B-XOR-LG (Braided XOR Logic Gate)
//   module from FIGURE 5 of the reference paper (IEEE Access, 2024).
//   Also replaces the CLFSR with a standalone 5-stage pipelined 2nd-order 
//   Chebyshev chaotic map (NO LFSR!).
//
// Key Subsystems:
//   1. Physical Entropy Sources (4 Free-Running Oscillators):
//      - in1: RO_3.v      (3-Stage Ring Oscillator)
//      - in2: RO_5.v      (5-Stage Ring Oscillator)
//      - in3: RO.v        (7-Stage Ring Oscillator)
//      - in4: FIRO_main.v (Chaotic Cross-Coupled Inverter Ring)
//
//   2. Proposed B-XOR-LG Module (Replaces 4:1 MUX):
//      - Receives 4 oscillator outputs (in1, in2, in3, in4)
//      - Cross-couples them through 7 XOR gates (Figure 5)
//      - Produces 3 outputs (out1, out2, out3)
//      - Fused 1-bit output: bxorlg_combined = out1 ^ out2 ^ out3
//
//   3. Dual-Rank D-Flip-Flop (D_FF) Synchronizer / Jitter Sampler:
//      - D_FF #1 & #2: Samples the high-frequency jittered B-XOR-LG stream
//        into the 100 MHz system clock domain without metastability.
//
//   4. Standalone 5-Stage Chebyshev Chaotic Core & Real-Time XOR (No LFSR):
//      - 5-stage pipelined 2nd-order Chebyshev map: X(n+1) = 1 - 2*X(n)^2
//      - Produces 1 chaotic bit per clock (x[10], completely LFSR-free).
//      - Fused 1-Bit Output: final_random_bit = chaotic_bit ^ trng_sampled_bit.
//      - 8-Bit Assembled Output: R_Out with key_ready strobe every 8 clock cycles.
// ============================================================================

`timescale 1ns/1ps

module ro_bxorlg_chaotic_trng_top #(
    parameter signed [15:0] CHAOTIC_INIT_SEED = 16'sh7EF0
)(
    input  wire        clk,               // System clock (100 MHz)
    input  wire        rst,               // Asynchronous active-high reset
    input  wire        enable,            // Enable signal for ROs and Chaotic Core
    
    // --- 1-Bit Outputs (Updated every clock cycle) ---
    output wire        final_random_bit,  // Fused 1-bit TRNG output: (chaotic_bit ^ trng_sampled)
    output wire        chaotic_bit_raw,   // Raw 1-bit chaotic output alone (NO LFSR)
    output wire        trng_sampled_bit,  // Synchronized & sampled B-XOR-LG TRNG bit
    output wire        bxorlg_combined,   // XOR-reduced B-XOR-LG output: out1 ^ out2 ^ out3
    output wire [2:0]  bxorlg_outs,       // 3 individual B-XOR-LG outputs {out3, out2, out1}
    
    // --- 8-Bit Parallel Outputs (Assembled every 8 clock cycles) ---
    output wire [7:0]  R_Out,             // 8-bit random output byte
    output wire        key_ready,         // 1-cycle active-high strobe when R_Out is valid
    output wire [7:0]  random_byte,       // Alias for R_Out
    output wire        byte_ready,        // Alias for key_ready
    output wire signed [15:0] x_state     // Raw 16-bit chaotic state
);

    // ========================================================================
    // 1. Instantiate the 4 Physical Entropy Sources (ROs & FIRO)
    // ========================================================================
    (* DONT_TOUCH = "TRUE" *) wire ro3_out;
    (* DONT_TOUCH = "TRUE" *) wire ro5_out;
    (* DONT_TOUCH = "TRUE" *) wire ro_out;
    (* DONT_TOUCH = "TRUE" *) wire firo_out;

    // RO_3 (3-Stage Inverter Ring)
    RO_3 u_ro3 (
        .enable (enable),
        .out    (ro3_out)
    );

    // RO_5 (5-Stage Inverter Ring)
    RO_5 u_ro5 (
        .enable (enable),
        .out    (ro5_out)
    );

    // RO (7-Stage Inverter Ring)
    RO u_ro (
        .enable   (enable),
        .RO1_out  (ro_out)
    );

    // FIRO_main (Chaotic Cross-Coupled Inverter Ring)
    FIRO_main u_firo (
        .enable (enable),
        .out    (firo_out)
    );

    // ========================================================================
    // 2. Proposed B-XOR-LG Module (Replaces the 4:1 MUX)
    //    4 inputs (in1, in2, in3, in4) -> 3 outputs (out1, out2, out3)
    //    out = out1 ^ out2 ^ out3 (XORs all 3 outputs into 1 combined bit)
    // ========================================================================
    (* DONT_TOUCH = "TRUE" *) wire bxorlg_out1;
    (* DONT_TOUCH = "TRUE" *) wire bxorlg_out2;
    (* DONT_TOUCH = "TRUE" *) wire bxorlg_out3;
    (* DONT_TOUCH = "TRUE" *) wire bxorlg_raw_fused;

    b_xor_lg u_bxorlg (
        .in1  (ro3_out),          // RO_3  -> in1
        .in2  (ro5_out),          // RO_5  -> in2
        .in3  (ro_out),           // RO_7  -> in3
        .in4  (firo_out),         // FIRO  -> in4
        .out1 (bxorlg_out1),
        .out2 (bxorlg_out2),
        .out3 (bxorlg_out3),
        .out  (bxorlg_raw_fused)  // out1 ^ out2 ^ out3
    );

    assign bxorlg_combined = bxorlg_raw_fused;
    assign bxorlg_outs     = {bxorlg_out3, bxorlg_out2, bxorlg_out1};

    // ========================================================================
    // 3. Dual-Rank D-Flip-Flop (D_FF) Synchronizer / Jitter Sampler
    //    Resolves metastability when sampling high-frequency asynchronous B-XOR-LG stream
    // ========================================================================
    (* DONT_TOUCH = "TRUE" *) wire sync_stage1;
    (* DONT_TOUCH = "TRUE" *) wire sync_stage2;

    // D_FF #1: Stage 1 Sampler (Captures phase jitter on posedge clk)
    D_FF u_dff_sync1 (
        .clk (clk),
        .in  (bxorlg_raw_fused),
        .out (sync_stage1)
    );

    // D_FF #2: Stage 2 Metastability Resolver
    D_FF u_dff_sync2 (
        .clk (clk),
        .in  (sync_stage1),
        .out (sync_stage2)
    );

    assign trng_sampled_bit = sync_stage2;

    // ========================================================================
    // 4. Standalone Chaotic Core & Real-Time TRNG XOR Fusion (No LFSR)
    // ========================================================================
    chaotic_trng_single #(
        .CHAOTIC_INIT_SEED (CHAOTIC_INIT_SEED)
    ) u_chaotic_core (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .trng_in     (trng_sampled_bit),  // Physical TRNG bit from B-XOR-LG
        .chaotic_bit (chaotic_bit_raw),   // 1-bit chaotic output (x[10], no LFSR)
        .random_bit  (final_random_bit),  // Fused: chaotic_bit ^ trng_sampled_bit
        .R_Out       (R_Out),             // 8-bit assembled byte
        .key_ready   (key_ready),         // 8-clock valid strobe
        .random_byte (random_byte),
        .byte_ready  (byte_ready),
        .x_state     (x_state)
    );

endmodule
