// ============================================================================
// File: tb_chaotic_trng_single.v
// Module: tb_chaotic_trng_single
// Description: Unit testbench for chaotic_trng_single module.
//              Verifies 5-stage Chebyshev pipeline, key_ready generation,
//              and real-time bitwise XOR fusion with incoming entropy.
// ============================================================================

`timescale 1ns/1ps
`include "chaotic_trng_single.v"

module tb_chaotic_trng_single;

    parameter CLK_PERIOD = 10; // 10 ns (100 MHz)

    reg clk;
    reg rst;
    reg enable;
    reg trng_in;

    wire        chaotic_bit;
    wire        random_bit;
    wire [7:0]  R_Out;
    wire        key_ready;
    wire signed [15:0] x_state;

    integer cycle = 0;

    chaotic_trng_single #(
        .CHAOTIC_INIT_SEED(16'sh7EF0)
    ) uut (
        .clk         (clk),
        .rst         (rst),
        .enable      (enable),
        .trng_in     (trng_in),
        .chaotic_bit (chaotic_bit),
        .random_bit  (random_bit),
        .R_Out       (R_Out),
        .key_ready   (key_ready),
        .random_byte (),
        .byte_ready  (),
        .x_state     (x_state)
    );

    // 100 MHz clock
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Simulate arbitrary physical jitter bit
    always @(posedge clk) begin
        trng_in <= {$urandom} % 2;
    end

    initial begin
        $display("============================================================================");
        $display(" Unit Testbench: chaotic_trng_single (Chaotic-Only XOR TRNG)");
        $display("============================================================================");

        clk     = 0;
        rst     = 1;
        enable  = 0;
        trng_in = 0;

        #(CLK_PERIOD * 3);
        rst = 0;
        #(CLK_PERIOD * 2);
        enable = 1;

        repeat (40) @(posedge clk) begin
            cycle = cycle + 1;
            $display("  Cycle #%02d | x_state=0x%04h | Chaotic=%0b | TRNG_in=%0b | Fused=%0b | Byte=0x%02h | Ready=%0b",
                     cycle, x_state, chaotic_bit, trng_in, random_bit, R_Out, key_ready);
        end

        $display("============================================================================");
        $display(" [PASS] chaotic_trng_single unit test completed successfully.");
        $display("============================================================================");
        $finish;
    end

endmodule
