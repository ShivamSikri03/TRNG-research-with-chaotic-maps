// ============================================================================
// File: tb_top.v
// Description: Testbench for CLFSR + MUX Hybrid TRNG Top Module
//              Simulates the full design and outputs random bits to a file.
// ============================================================================

`timescale 1ns/1ps

module tb_top;

    // ---- Clock and Control Signals ----
    reg clk    = 1'b0;
    reg rst    = 1'b0;
    reg enable = 1'b0;
    wire uart_out;

    // 100 MHz clock: 10ns period
    always #5 clk = ~clk;

    // ---- DUT Instantiation ----
    top uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .uart_out(uart_out)
    );

    // ---- Random Bit Capture ----
    // Tap into internal sync2 signal for direct bit capture (faster than UART)
    integer bit_file;
    integer bit_count = 0;
    integer total_bits = 2_000_000;  // Collect 2M bits for NIST testing

    initial begin
        bit_file = $fopen("clfsr_mux_2m_bits.txt", "w");
        if (bit_file == 0) begin
            $display("ERROR: Could not open output file!");
            $finish;
        end
    end

    // Sample the synchronized random bit every clock cycle when enabled
    always @(posedge clk) begin
        if (enable && !rst && bit_count < total_bits) begin
            $fwrite(bit_file, "%b", uut.sync2);
            bit_count = bit_count + 1;
            
            if (bit_count % 100_000 == 0)
                $display("[%0t] Collected %0d / %0d bits", $time, bit_count, total_bits);
        end
    end

    // ---- Simulation Sequence ----
    initial begin
        $display("============================================================");
        $display(" CLFSR + MUX Hybrid TRNG Testbench");
        $display(" Architecture: RO(8) + CLFSR + RO(5) + RO(3) → 4x1 MUX");
        $display(" FIRO (RO_16) replaced by Chaotic LFSR (clfsr_trng_single)");
        $display("============================================================");
        
        // Reset phase
        rst    = 1'b1;
        enable = 1'b0;
        #100;
        
        rst    = 1'b0;
        #50;
        
        // Enable and run
        enable = 1'b1;
        $display("[%0t] Generator ENABLED. Collecting %0d bits...", $time, total_bits);
        
        // Wait until all bits collected
        wait (bit_count >= total_bits);
        
        #100;
        $fclose(bit_file);
        
        $display("============================================================");
        $display(" Collection complete: %0d bits saved to clfsr_mux_2m_bits.txt", bit_count);
        $display("============================================================");
        
        // Print some statistics from internal signals
        $display(" Final LFSR state:    0x%04h", uut.clfsr_inst.lfsr);
        $display(" Final Chaotic X:     0x%04h", uut.clfsr_inst.x);
        $display("============================================================");
        
        $finish;
    end

    // ---- Timeout Safety ----
    initial begin
        #(total_bits * 10 * 5);  // Generous timeout
        $display("ERROR: Simulation timeout!");
        $fclose(bit_file);
        $finish;
    end

endmodule
