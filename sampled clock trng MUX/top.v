// ============================================================================
// File: top.v
// Module: top
// Description: Basys 3 Top-Level Module for Sampled Clock TRNG MUX
//              Interfaces 4-input Ring Oscillator MUX with 115200 Baud UART TX
//              and Onboard Diagnostic LEDs.
//
// Target Board: Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
//
// Pinout Map:
//   - clk       : Pin W5  (100 MHz Onboard Crystal Oscillator)
//   - rst       : Pin U18 (Center Pushbutton BTNC, Active-High)
//   - enable    : Pin V17 (Slide Switch SW0, 1 = Run, 0 = Pause)
//   - uart_out  : Pin A18 (USB-UART TX Serial to PC @ 115200 Baud, 8N1)
//   - led[7:0]  : Pins U16, E19, U19, V19, W18, U15, U14, V14 (Diagnostic LEDs)
// ============================================================================

`timescale 1ns/1ps

module top (
    input  wire       clk,        // 100 MHz oscillator (Pin W5)
    input  wire       rst,        // Reset button BTNC (Pin U18, Active-High)
    input  wire       enable,     // Enable switch SW0 (Pin V17)
    output wire       uart_out,   // USB-UART TX (Pin A18)
    output wire [7:0] led         // Status LEDs (Pins U16..V14)
);

    // Active-low reset for core modules
    wire reset_n = ~rst;

    // -------------------------------------------------------------------------
    // 1. Instantiate Sampled-Clock TRNG Core
    // -------------------------------------------------------------------------
    wire       raw_bit;
    wire       raw_valid;
    wire [1:0] source_id;

    TRNG_RAW_TOP #(
        .SAMPLE_DIV(50),          // 100 MHz / 50 = 2 MSamples/sec
        .WARMUP_SAMPLES(64)       // 64 warmup samples before output
    ) u_trng_core (
        .clk       (clk),
        .reset_n   (reset_n),
        .enable    (enable),
        .raw_bit   (raw_bit),
        .raw_valid (raw_valid),
        .source_id (source_id)
    );

    // -------------------------------------------------------------------------
    // 2. UART Transmitter (115200 Baud, 8N1 @ 100 MHz)
    // -------------------------------------------------------------------------
    reg        uart_start   = 1'b0;
    reg  [7:0] uart_tx_data = 8'h30;
    wire       uart_active;
    wire       uart_done;

    uart_tx #(
        .CLKS_PER_BIT(868)        // 100,000,000 / 115,200 = 868
    ) u_uart_tx (
        .clk       (clk),
        .tx_start  (uart_start),
        .tx_byte   (uart_tx_data),
        .tx_active (uart_active),
        .tx_serial (uart_out),
        .tx_done   (uart_done)
    );

    // UART Controller: Latch each freshly generated random bit and send as ASCII '0' or '1'
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_start   <= 1'b0;
            uart_tx_data <= 8'h30;
        end else if (enable) begin
            if (!uart_active && !uart_start && raw_valid) begin
                uart_tx_data <= raw_bit ? 8'h31 : 8'h30; // '1'=0x31, '0'=0x30
                uart_start   <= 1'b1;
            end else begin
                uart_start <= 1'b0;
            end
        end else begin
            uart_start <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 3. Visual Diagnostic LEDs on Basys 3 Board
    // -------------------------------------------------------------------------
    // Heartbeat clock divider: ~1.5 Hz blink from 100 MHz
    reg [25:0] heartbeat_cnt = 26'd0;
    always @(posedge clk) begin
        heartbeat_cnt <= heartbeat_cnt + 1'b1;
    end

    // Entropy shift register for visual animation on LEDs [7:5]
    reg [2:0] led_shift = 3'd0;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led_shift <= 3'd0;
        end else if (raw_valid) begin
            led_shift <= {led_shift[1:0], raw_bit};
        end
    end

    assign led[0]   = enable;              // LED0: High when SW0 is ON
    assign led[1]   = uart_active;         // LED1: High while sending serial byte
    assign led[2]   = heartbeat_cnt[25];   // LED2: Heartbeat blink (~1.5 Hz)
    assign led[4:3] = source_id;           // LED[4:3]: Active RO (00=RO3, 01=RO5, 10=RO7, 11=RO9)
    assign led[7:5] = led_shift;           // LED[7:5]: Live random bit shift animation

endmodule
