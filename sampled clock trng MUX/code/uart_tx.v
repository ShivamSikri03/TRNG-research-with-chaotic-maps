// ============================================================================
// File: uart_tx.v
// Module: uart_tx
// Description: Standard 8N1 UART Transmitter for Basys 3 FPGA
//              Default Baud Rate: 115200 Baud @ 100 MHz System Clock
//              CLKS_PER_BIT = 100,000,000 / 115,200 = 868
// ============================================================================

`timescale 1ns/1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz clock / 115200 baud rate = 868
)(
    input  wire       clk,        // 100 MHz FPGA system clock
    input  wire       tx_start,   // 1-cycle strobe to initiate byte transmission
    input  wire [7:0] tx_byte,    // 8-bit data byte to transmit
    output reg        tx_active,  // High while transmission is in progress
    output reg        tx_serial,  // Serial TX pin (connected to USB-UART A18)
    output reg        tx_done     // 1-cycle strobe when transmission finishes
);

    // State machine states
    localparam [1:0] s_IDLE  = 2'b00;
    localparam [1:0] s_START = 2'b01;
    localparam [1:0] s_DATA  = 2'b10;
    localparam [1:0] s_STOP  = 2'b11;

    reg [1:0]  state     = s_IDLE;
    reg [11:0] clk_count = 12'd0;
    reg [2:0]  bit_index = 3'd0;
    reg [7:0]  data_reg  = 8'h00;

    always @(posedge clk) begin
        case (state)
            s_IDLE: begin
                tx_serial <= 1'b1;  // Idle line is logic High
                tx_done   <= 1'b0;
                clk_count <= 12'd0;
                bit_index <= 3'd0;

                if (tx_start == 1'b1) begin
                    tx_active <= 1'b1;
                    data_reg  <= tx_byte;
                    state     <= s_START;
                end else begin
                    tx_active <= 1'b0;
                end
            end

            s_START: begin
                tx_serial <= 1'b0; // Start bit is logic Low
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1'b1;
                end else begin
                    clk_count <= 12'd0;
                    state     <= s_DATA;
                end
            end

            s_DATA: begin
                tx_serial <= data_reg[bit_index]; // LSB first
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1'b1;
                end else begin
                    clk_count <= 12'd0;
                    if (bit_index < 3'd7) begin
                        bit_index <= bit_index + 1'b1;
                    end else begin
                        bit_index <= 3'd0;
                        state     <= s_STOP;
                    end
                end
            end

            s_STOP: begin
                tx_serial <= 1'b1; // Stop bit is logic High
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1'b1;
                end else begin
                    tx_done   <= 1'b1;
                    tx_active <= 1'b0;
                    clk_count <= 12'd0;
                    state     <= s_IDLE;
                end
            end

            default: begin
                state     <= s_IDLE;
                tx_serial <= 1'b1;
                tx_active <= 1'b0;
                tx_done   <= 1'b0;
            end
        endcase
    end

endmodule
