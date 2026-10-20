// ============================================================================
// File: top.v
// Description: CLFSR + MUX Hybrid TRNG Top Module
//              4-input chaotic MUX with 3 Ring Oscillators + 1 CLFSR
//
// Architecture:
//   MUX Input 0 (sel=00): RO   - 8-stage Ring Oscillator (5 NOT + 3 extra)
//   MUX Input 1 (sel=01): CLFSR - Chaotic LFSR (replaces FIRO RO_16)
//   MUX Input 2 (sel=10): RO_5 - 5-stage Ring Oscillator
//   MUX Input 3 (sel=11): RO_3 - 3-stage Ring Oscillator
//
// The CLFSR's trng_in is fed by RO_3 output, creating a hybrid source
// where physical jitter continuously perturbs the chaotic LFSR.
//
// MUX select lines: sel = {clk, mux_out} for chaotic self-feedback selection.
// Final random bit: mux_sampled XOR ro1_sampled (post-processing via XOR)
// Output: UART TX at 115200 baud, sending ASCII '0'/'1' per random bit.
// ============================================================================

module top(
    input wire clk,          // 100 MHz onboard clock (Pin W5)
    input wire rst,          // Reset button (active high)
    input wire enable,       // SW0 enable switch (Pin V17)
    output wire uart_out     // USB-UART TX (Pin A18)
);

    // =========================================================================
    // 1. Entropy Source Instantiations
    // =========================================================================

    // Internal wires for the oscillator outputs
    (* DONT_TOUCH = "TRUE" *) wire ro1_out;
    (* DONT_TOUCH = "TRUE" *) wire clfsr_bit;
    (* DONT_TOUCH = "TRUE" *) wire ro5_out;
    (* DONT_TOUCH = "TRUE" *) wire ro3_out;
    
    // Internal wire for the multiplexer output
    (* DONT_TOUCH = "TRUE" *) wire mux_out;

    // --- MUX Input 0: Ring Oscillator (8-stage: NAND + 4 NOT + 3 extra NOT) ---
    RO RO_inst (
        .enable(enable),
        .RO1_out(ro1_out)
    );

    // --- MUX Input 1: CLFSR Hybrid TRNG (replaces FIRO RO_16) ---
    //     trng_in is fed by RO_3 output for continuous physical entropy injection
    wire [7:0]  clfsr_random_byte;   // 8-bit output (unused in MUX, available for direct use)
    wire        clfsr_byte_ready;    // Byte-ready strobe (unused in MUX)
    wire        clfsr_random_bit;    // 1-bit output used as MUX input

    clfsr_trng_single #(
        .LFSR_INIT_SEED(16'hA3C5),
        .CHAOTIC_INIT_SEED(16'sh7EF0)
    ) clfsr_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .trng_in(ro3_out),           // Physical entropy from RO_3 → hybrid TRNG
        .R_Out(),                     // Not used at top level
        .key_ready(),                 // Not used at top level
        .random_byte(clfsr_random_byte),
        .byte_ready(clfsr_byte_ready),
        .random_bit(clfsr_random_bit)
    );

    assign clfsr_bit = clfsr_random_bit;

    // --- MUX Input 2: Ring Oscillator (5-stage: NAND + 4 NOT) ---
    RO_5 RO_5_inst (
        .enable(enable),
        .out(ro5_out)
    );

    // --- MUX Input 3: Ring Oscillator (3-stage: NAND + 2 NOT) ---
    RO_3 RO_3_inst (
        .enable(enable),
        .out(ro3_out)
    );

    // =========================================================================
    // 2. 4x1 Chaotic MUX with Self-Feedback Selection
    // =========================================================================

    // Multiplexer select lines:
    //   MSB = System Clock (clk)
    //   LSB = MUX output feedback (mux_out) — creates chaotic selection pattern
    (* DONT_TOUCH = "TRUE" *) wire [1:0] sel;
    assign sel = {clk, mux_out};

    // 4x1 Multiplexer: selects between 3 ROs + 1 CLFSR
    assign mux_out = (sel == 2'b00) ? ro1_out   :    // RO 8-stage
                     (sel == 2'b01) ? clfsr_bit :     // CLFSR hybrid
                     (sel == 2'b10) ? ro5_out   :     // RO 5-stage
                                      ro3_out;        // RO 3-stage

    // =========================================================================
    // 3. Sampling & Post-Processing
    // =========================================================================
    
    // Sample the chaotic MUX output and RO1 output on the rising edge of clk
    (* DONT_TOUCH = "TRUE" *) reg q1 = 1'b0;
    (* DONT_TOUCH = "TRUE" *) reg q2 = 1'b0;
    
    always @(posedge clk) begin
        q1 <= mux_out;
        q2 <= ro1_out;
    end

    // XOR post-processing: combines MUX output with RO1 for de-biasing
    wire random_bit;
    assign random_bit = q1 ^ q2;

    // Double flip-flop synchronizer to protect UART logic against metastability
    (* DONT_TOUCH = "TRUE" *) reg sync1 = 1'b0;
    (* DONT_TOUCH = "TRUE" *) reg sync2 = 1'b0;

    always @(posedge clk) begin
        sync1 <= random_bit;
        sync2 <= sync1;
    end

    // =========================================================================
    // 4. UART Transmission Control
    // =========================================================================
    
    reg uart_start = 1'b0;
    reg [7:0] ascii_char = 8'h30;
    wire uart_active;
    wire uart_done;

    // Instantiate UART Transmitter (115200 Baud, 8N1, 100MHz clock)
    uart_tx #(
        .CLKS_PER_BIT(868)
    ) uart_inst (
        .clk(clk),
        .tx_start(uart_start),
        .tx_byte(ascii_char),
        .tx_active(uart_active),
        .tx_serial(uart_out),
        .tx_done(uart_done)
    );

    // Controller: When UART is free and enable is high, send ascii '0' or '1'
    always @(posedge clk) begin
        if (enable) begin
            if (!uart_start && !uart_active) begin
                ascii_char <= sync2 ? 8'h31 : 8'h30; // 8'h31 = '1', 8'h30 = '0'
                uart_start <= 1'b1;
            end else begin
                uart_start <= 1'b0;
            end
        end else begin
            uart_start <= 1'b0;
        end
    end

endmodule
