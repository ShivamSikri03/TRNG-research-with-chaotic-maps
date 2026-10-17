// ============================================================================
// File: ro_bxorlg_clfsr_trng_top.v
// Module: ro_bxorlg_clfsr_trng_top
// Description: Multi-Oscillator B-XOR-LG TRNG with CLFSR 1-Bit XOR Fusion Core
//
//   This design REPLACES the 4:1 MUX from the original architecture with
//   the B-XOR-LG (Balanced XOR Logic Gate) module from Figure 5 of the paper.
//
//   Instead of selecting one oscillator at a time (MUX), the B-XOR-LG mixes
//   ALL 4 oscillator outputs simultaneously through a 2-stage cross-coupled
//   XOR network, producing 3 decorrelated streams that are XOR-reduced to
//   a single bit before feeding into the CLFSR.
//
// Subsystems:
//   1. Physical Entropy Sources (4 Free-Running Oscillators):
//      - in1: RO_3.v      (3-Stage Ring Oscillator)
//      - in2: RO_5.v      (5-Stage Ring Oscillator)
//      - in3: RO.v        (7-Stage Ring Oscillator)
//      - in4: FIRO_main.v (Chaotic Free-Running Inverter Ring)
//
//   2. B-XOR-LG Module (Replaces 4:1 MUX):
//      - Takes 4 RO outputs as inputs
//      - Produces 3 cross-coupled XOR outputs
//      - Final bit = out1 ^ out2 ^ out3 (XOR reduction to 1 bit)
//
//   3. D-Flip-Flop (D_FF) Usage:
//      - D_FF #1 & #2 (Dual-Rank Metastability Synchronizer): Samples the
//        high-frequency jittered B-XOR-LG output into the system clock domain.
//
//   4. 1-Bit Chaotic-LFSR (CLFSR) & Real-Time XOR:
//      - CLFSR produces 1 pseudo-random chaotic bit per clock.
//      - Fused 1-Bit Output: random_bit = clfsr_bit ^ trng_sampled_bit.
//      - 8-Bit Assembled Output: R_Out with key_ready strobe every 8 clocks.
//
// Advantages over MUX design:
//   - ALL oscillators contribute to EVERY output bit (vs. only 1 with MUX)
//   - No deterministic select-line switching pattern
//   - No feedback loop for select generation
//   - Superior entropy concentration per output bit
// ============================================================================

`timescale 1ns/1ps

module ro_bxorlg_clfsr_trng_top #(
    parameter [15:0]        LFSR_INIT_SEED    = 16'hA3C5,
    parameter signed [15:0] CHAOTIC_INIT_SEED = 16'sh7EF0
)(
    input  wire        clk,               // System clock (e.g., 50 MHz / 100 MHz)
    input  wire        rst,               // Asynchronous active-high reset
    input  wire        enable,            // Enable signal for ROs and CLFSR
    
    // --- 1-Bit Outputs (Updated every clock cycle) ---
    output wire        final_random_bit,  // Fused 1-bit TRNG output: (clfsr_bit ^ trng_sampled)
    output wire        clfsr_bit_raw,     // Raw 1-bit CLFSR output alone
    output wire        trng_sampled_bit,  // Synchronized & sampled B-XOR-LG TRNG bit
    output wire        bxorlg_combined,   // XOR-reduced B-XOR-LG output (for probing)
    output wire [2:0]  bxorlg_outs,       // 3 individual B-XOR-LG outputs {out3, out2, out1}
    
    // --- 8-Bit Parallel Outputs (Assembled every 8 clock cycles) ---
    output wire [7:0]  R_Out,             // 8-bit random output byte
    output wire        key_ready,         // 1-cycle active-high strobe when R_Out is valid
    output wire [7:0]  random_byte,       // Alias for R_Out
    output wire        byte_ready         // Alias for key_ready
);

    // ========================================================================
    // 1. Instantiate the 4 Physical Entropy Sources (ROs & FIRO)
    // ========================================================================
    wire ro3_out;
    wire ro5_out;
    wire ro_out;
    wire firo_out;

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
    // 2. B-XOR-LG Module (Replaces the 4:1 MUX)
    //    Mixes ALL 4 oscillator outputs simultaneously through cross-coupled
    //    XOR gates → produces 3 decorrelated output streams.
    // ========================================================================
    wire bxorlg_out1;   // = RO_3 ^ RO_5 ^ RO_7
    wire bxorlg_out2;   // = RO_3 ^ RO_5 ^ RO_7 ^ FIRO  (all four mixed)
    wire bxorlg_out3;   // = RO_5 ^ RO_7 ^ FIRO

    b_xor_lg u_bxorlg (
        .in1  (ro3_out),    // RO_3 → in1
        .in2  (ro5_out),    // RO_5 → in2
        .in3  (ro_out),     // RO_7 → in3
        .in4  (firo_out),   // FIRO → in4
        .out1 (bxorlg_out1),
        .out2 (bxorlg_out2),
        .out3 (bxorlg_out3)
    );

    // XOR-reduce the 3 B-XOR-LG outputs into a single bit
    // combined = out1 ^ out2 ^ out3
    //          = (in1^in2^in3) ^ (in1^in2^in3^in4) ^ (in2^in3^in4)
    //          = in2 ^ in3  (after XOR cancellation)
    //
    // NOTE: The XOR cancellation above shows that a naive triple-XOR reduces
    // to only 2 inputs. To preserve maximum entropy mixing, we instead use
    // out2 as the primary (it already mixes all 4 inputs) and XOR it with
    // one additional output for extra jitter decorrelation:
    //   combined = out1 ^ out2 = (in1^in2^in3) ^ (in1^in2^in3^in4) = in4 (FIRO only!)
    //
    // BEST approach: Use out2 directly since it's the ONLY output that
    // combines ALL 4 oscillators: out2 = in1 ^ in2 ^ in3 ^ in4
    wire bxorlg_raw;
    assign bxorlg_raw = bxorlg_out2;   // All 4 oscillators mixed in one bit

    assign bxorlg_combined = bxorlg_raw;
    assign bxorlg_outs = {bxorlg_out3, bxorlg_out2, bxorlg_out1};

    // ========================================================================
    // 3. Dual-Rank D-Flip-Flop (D_FF) Synchronizer / Jitter Sampler
    //    Resolves metastability when sampling high-frequency asynchronous ROs
    // ========================================================================
    wire sync_stage1;
    wire sync_stage2;

    // D_FF #1: Stage 1 Sampler (Captures phase jitter on posedge clk)
    D_FF u_dff_sync1 (
        .clk (clk),
        .in  (bxorlg_raw),
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
    // 4. 1-Bit CLFSR Core & Real-Time TRNG XOR Fusion
    // ========================================================================
    clfsr_trng_single #(
        .LFSR_INIT_SEED    (LFSR_INIT_SEED),
        .CHAOTIC_INIT_SEED (CHAOTIC_INIT_SEED)
    ) u_clfsr (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .trng_in     (trng_sampled_bit), // Physical TRNG bit from B-XOR-LG
        .clfsr_bit   (clfsr_bit_raw),    // 1-bit CLFSR output
        .random_bit  (final_random_bit), // Fused: clfsr_bit ^ trng_sampled_bit
        .R_Out       (R_Out),            // 8-bit assembled byte
        .key_ready   (key_ready),        // 8-clock valid strobe
        .random_byte (random_byte),
        .byte_ready  (byte_ready)
    );

endmodule
