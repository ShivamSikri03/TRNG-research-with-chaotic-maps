module uart_tx #(
    parameter CLKS_PER_BIT = 868 // 100 MHz / 115200 baud = 868
)(
    input       clk,
    input       tx_start,
    input [7:0] tx_byte,
    output reg  tx_active,
    output reg  tx_serial,
    output reg  tx_done
);
    localparam s_IDLE  = 3'b000;
    localparam s_START = 3'b001;
    localparam s_DATA  = 3'b010;
    localparam s_STOP  = 3'b011;

    reg [2:0]  state      = s_IDLE;
    reg [9:0]  clk_count  = 0;
    reg [2:0]  bit_index  = 0;
    reg [7:0]  data_reg   = 0;

    always @(posedge clk) begin
        case (state)
            s_IDLE: begin
                tx_serial <= 1'b1;  // Drive line high for idle
                tx_done   <= 1'b0;
                clk_count <= 0;
                bit_index <= 0;
                
                if (tx_start == 1'b1) begin
                    tx_active <= 1'b1;
                    data_reg <= tx_byte;
                    state     <= s_START;
                end else begin
                    tx_active <= 1'b0;
                end
            end

            s_START: begin
                tx_serial <= 1'b0; // Start bit (low)
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state     <= s_DATA;
                end
            end

            s_DATA: begin
                tx_serial <= data_reg[bit_index];
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1;
                    end else begin
                        bit_index <= 0;
                        state     <= s_STOP;
                    end
                end
            end

            s_STOP: begin
                tx_serial <= 1'b1;  // Stop bit (high)
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    tx_done   <= 1'b1;
                    clk_count <= 0;
                    state     <= s_IDLE;
                end
            end
            default: state <= s_IDLE;
        endcase
    end
endmodule
