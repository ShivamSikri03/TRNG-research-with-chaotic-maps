// ============================================================================
// File: tb_ro_mux_chaotic_trng_top.v
// Module: tb_ro_mux_chaotic_trng_top
// Description: Testbench for the Multi-Oscillator 4:1 MUX + Standalone Chaotic TRNG Core (No LFSR).
//              Verifies MUX dynamic selection, D-FF metastability sampling,
//              5-stage Chebyshev chaotic pipeline, 1-bit XOR generation,
//              and collects random bits into a file for statistical/NIST testing.
// ============================================================================

`timescale 1ns/1ps

`include "RO_3.v"
`include "RO_5.v"
`include "RO.v"
`include "FIRO_main.v"
`include "D_FF.v"
`include "chaotic_trng_single.v"
`include "ro_mux_chaotic_trng_top.v"

module tb_ro_mux_chaotic_trng_top;

    parameter TOTAL_BYTES = 125000; // 125,000 bytes * 8 = 1,000,000 bits (set to 250000 for 2M bits)
    parameter CLK_PERIOD  = 10;     // 10 ns (100 MHz clock)

    reg clk;
    reg rst;
    reg enable;

    wire        final_random_bit;
    wire        chaotic_bit_raw;
    wire        trng_sampled_bit;
    wire        mux_raw_out;
    wire [1:0]  mux_sel;
    wire [7:0]  R_Out;
    wire        key_ready;
    wire signed [15:0] x_state;

    integer file_id;
    integer byte_count = 0;

    // Instantiate Top-Level Device Under Test
    ro_mux_chaotic_trng_top #(
        .CHAOTIC_INIT_SEED (16'sh7EF0)
    ) dut (
        .clk               (clk),
        .rst               (rst),
        .enable            (enable),
        .final_random_bit  (final_random_bit),
        .chaotic_bit_raw   (chaotic_bit_raw),
        .trng_sampled_bit  (trng_sampled_bit),
        .mux_raw_out       (mux_raw_out),
        .mux_sel           (mux_sel),
        .R_Out             (R_Out),
        .key_ready         (key_ready),
        .random_byte       (),
        .byte_ready        (),
        .x_state           (x_state)
    );

    // 100 MHz clock generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $display("============================================================================");
        $display(" Starting Simulation: 4:1 MUX (RO_3, RO_5, RO, FIRO) + Standalone Chaotic TRNG");
        $display(" Architecture: Chaotic Only (No LFSR) XOR 4:1 Multi-Oscillator MUX");
        $display(" Select Lines: MSB = clk, LSB = D_FF(mux_out)");
        $display(" Target: Collect random bitstream into 'chotic_mux_trng_1m_bits.txt'");
        $display("============================================================================");

        file_id = $fopen("chotic_mux_trng_1m_bits.txt", "w");
        if (file_id == 0) begin
            $display("[ERROR] Could not open output file.");
            $finish;
        end

        // Initial setup
        clk        = 0;
        rst        = 1;
        enable     = 1;
        byte_count = 0;

        #(CLK_PERIOD * 4);
        rst = 0;
        $display("[TB] Reset released at %0t ns. Free-running oscillators active...", $time);
    end

    // Log first 15 cycles of signals for verification
    integer bit_idx = 0;
    always @(posedge clk) begin
        if (!rst && enable && bit_idx < 15) begin
            $display("  [%0t ns] Cycle #%02d | MUX Sel=%02b | Raw MUX=%0b | TRNG Sampled=%0b | Chaotic Bit=%0b | Fused Bit=%0b | x_state=0x%04h",
                     $time, bit_idx + 1, mux_sel, mux_raw_out, trng_sampled_bit, chaotic_bit_raw, final_random_bit, x_state);
            bit_idx <= bit_idx + 1;
        end
    end

    // Collect 8-bit bytes upon key_ready strobe
    always @(posedge clk) begin
        if (!rst && enable && key_ready && byte_count < TOTAL_BYTES) begin
            $fwrite(file_id, "%08b", R_Out);
            byte_count <= byte_count + 1;

            if ((byte_count + 1) % 25000 == 0) begin
                $display("  [%0t ns] Collected %0d / %0d bytes (%0d%% complete)...",
                         $time, byte_count + 1, TOTAL_BYTES, ((byte_count + 1) * 100) / TOTAL_BYTES);
            end

            if (byte_count + 1 == TOTAL_BYTES) begin
                $display("============================================================================");
                $display(" [SUCCESS] Collected %0d bits into 'chotic_mux_trng_1m_bits.txt'!", TOTAL_BYTES * 8);
                $display("============================================================================");
                $fclose(file_id);
                $finish;
            end
        end
    end

endmodule
