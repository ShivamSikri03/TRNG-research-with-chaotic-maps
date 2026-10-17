// ============================================================================
// File: tb_RandomNumberGenerator.v
// Module: tb_RandomNumberGenerator
// Description: Testbench for complete 3-channel (RGB) Random Number Generator.
//              Collects 2,000,000 bits (250,000 bytes) for R, G, and B channels.
// ============================================================================

`timescale 1ns/1ps
`include "RandomNumberGenerator.v"

module tb_RandomNumberGenerator;

    parameter TOTAL_BYTES = 250000; // 250,000 bytes * 8 bits = 2,000,000 bits per channel
    parameter CLK_PERIOD  = 10;     // 10 ns = 100 MHz clock

    reg clk;
    reg rst;

    wire [7:0] R_Out;
    wire [7:0] G_Out;
    wire [7:0] B_Out;
    wire       key_ready;

    integer file_r, file_g, file_b;
    integer byte_count = 0;

    // Instantiate Unit Under Test
    RandomNumberGenerator uut (
        .clk(clk),
        .rst(rst),
        .R_Out(R_Out),
        .G_Out(G_Out),
        .B_Out(B_Out),
        .key_ready(key_ready)
    );

    // 100 MHz clock generation
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $display("============================================================================");
        $display(" Starting Simulation: Complete RGB Random Number Generator");
        $display(" Target: 2,000,000 bits (250,000 bytes) per channel (R, G, B)");
        $display("============================================================================");

        file_r = $fopen("R_stream.txt", "w");
        file_g = $fopen("G_stream.txt", "w");
        file_b = $fopen("B_stream.txt", "w");

        if (file_r == 0 || file_g == 0 || file_b == 0) begin
            $display("[ERROR] Could not open output file(s).");
            $finish;
        end

        clk        = 0;
        rst        = 1;
        byte_count = 0;

        #(CLK_PERIOD * 3);
        rst = 0;

        $display("[TB] Reset released. Starting collection of RGB streams...");
    end

    // On each key_ready, write the 8 bits of R, G, B
    always @(posedge clk) begin
        if (!rst && key_ready && byte_count < TOTAL_BYTES) begin
            $fwrite(file_r, "%08b", R_Out);
            $fwrite(file_g, "%08b", G_Out);
            $fwrite(file_b, "%08b", B_Out);
            byte_count <= byte_count + 1;

            if ((byte_count + 1) % 25000 == 0) begin
                $display("  [%0t ns] Collected %0d / %0d bytes (%0d bits, %0d%%)...", 
                         $time, byte_count + 1, TOTAL_BYTES, (byte_count + 1) * 8, 
                         ((byte_count + 1) * 100) / TOTAL_BYTES);
            end

            if (byte_count + 1 == TOTAL_BYTES) begin
                $display("\n============================================================================");
                $display("  [SUCCESS] Collected 2,000,000 bits for R, G, and B!");
                $display("============================================================================");
                $fclose(file_r);
                $fclose(file_g);
                $fclose(file_b);
                $finish;
            end
        end
    end

endmodule
