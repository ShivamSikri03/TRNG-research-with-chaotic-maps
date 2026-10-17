// ============================================================================
// File: tb_clfsr_trng_single.v
// Module: tb_clfsr_trng_single
// Description: Testbench for single-channel Chaotic-LFSR (CLFSR) R-Channel.
//              Collects 2,000,000 bits (250,000 bytes) via the 8-bit R_Out
//              output on each key_ready pulse, exactly matching the complete
//              RandomNumberGenerator architecture.
// ============================================================================

`timescale 1ns/1ps
`include "clfsr_trng_single.v"

module tb_clfsr_trng_single;

    parameter TOTAL_BYTES = 250000; // 250,000 bytes * 8 bits = 2,000,000 bits
    parameter CLK_PERIOD  = 10;     // 10 ns = 100 MHz clock

    reg clk;
    reg rst;
    reg enable;
    reg trng_in;

    wire [7:0] R_Out;
    wire       key_ready;
    wire       random_bit;

    integer file_id;
    integer byte_count = 0;

    // Instantiate Unit Under Test
    clfsr_trng_single #(
        .LFSR_INIT_SEED(16'hA3C5),
        .CHAOTIC_INIT_SEED(16'sh7EF0)
    ) uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .trng_in(trng_in),
        .R_Out(R_Out),
        .key_ready(key_ready),
        .random_bit(random_bit)
    );

    // 100 MHz clock generation (10 ns period)
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $display("============================================================================");
        $display(" Starting Simulation: Single-Channel Chaotic-LFSR (CLFSR) R-Channel");
        $display(" Mode: 8-bit parallel (R_Out) with key_ready handshake");
        $display(" Target: 2,000,000 bits (250,000 bytes) into 'clfsr_r_2m_bits.txt'");
        $display("============================================================================");

        file_id = $fopen("clfsr_r_2m_bits.txt", "w");
        if (file_id == 0) begin
            $display("[ERROR] Could not open output file 'clfsr_r_2m_bits.txt'");
            $finish;
        end

        // 1. Initialize & Reset (matches tb_RandomNumberGenerator)
        clk        = 0;
        rst        = 1;
        enable     = 1;
        trng_in    = 0; // Deterministic CLFSR mode
        byte_count = 0;

        #(CLK_PERIOD * 3);
        rst = 0;

        $display("[TB] Reset released. Starting collection of R 8-bit stream...");
    end

    // On each key_ready strobe (every 8 clock cycles), write the 8 bits of R_Out
    always @(posedge clk) begin
        if (!rst && enable && key_ready && byte_count < TOTAL_BYTES) begin
            $fwrite(file_id, "%08b", R_Out);
            byte_count <= byte_count + 1;

            if (byte_count < 5) begin
                $display("  [Debug Preview] Byte #%0d: R_Out = 0x%02h (%08b)", 
                         byte_count + 1, R_Out, R_Out);
            end

            if ((byte_count + 1) % 25000 == 0) begin
                $display("  [%0t ns] Collected %0d / %0d bytes (%0d bits, %0d%%)...", 
                         $time, byte_count + 1, TOTAL_BYTES, (byte_count + 1) * 8, 
                         ((byte_count + 1) * 100) / TOTAL_BYTES);
            end

            if (byte_count + 1 == TOTAL_BYTES) begin
                $display("\n============================================================================");
                $display("  [SUCCESS] Collected all 2,000,000 bits into 'clfsr_r_2m_bits.txt'!");
                $display("============================================================================");
                $fclose(file_id);
                $finish;
            end
        end
    end

endmodule
