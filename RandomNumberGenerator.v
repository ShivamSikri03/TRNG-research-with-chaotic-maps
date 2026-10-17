`timescale 1ns/1ps
module RandomNumberGenerator(
    input wire clk,
    input wire rst,
    output reg [7:0] R_Out,
    output reg [7:0] G_Out,
    output reg [7:0] B_Out,

    output reg key_ready
);

// lfsr    
    reg [15:0] R_lfsr;
    reg [15:0] G_lfsr;
    reg [15:0] B_lfsr;
    reg [7:0] R_lfsr_out;
    reg [7:0] G_lfsr_out;
    reg [7:0] B_lfsr_out;

// bit counter    
    reg [2:0] bit_counter;                                  // 3-bit counter for 8 bits (0-7)
    
// Chaotic map variables
    reg signed [15:0] x;                                    // Current chaotic state
    reg signed [31:0] x_square;                             // x squared (32-bit intermediate) - Stage 1
    reg signed [31:0] x_mult;                               // 2*x^2 (32-bit intermediate) - Stage 2
    reg signed [15:0] x_section;                            // Section extraction - Stage 3
    reg signed [15:0] x_sub;                                // Subtraction result - Stage 4

    reg signed [15:0] y;
    reg signed [31:0] y_square;
    reg signed [31:0] y_mult;
    reg signed [15:0] y_section;
    reg signed [15:0] y_sub;

    reg signed [15:0] z;
    reg signed [31:0] z_square;
    reg signed [31:0] z_mult;
    reg signed [15:0] z_section;
    reg signed [15:0] z_sub;
//  feedback
    wire Rfeedback_lfsr = R_lfsr[15] ^ R_lfsr[13] ^ R_lfsr[12] ^ R_lfsr[10];
    wire Gfeedback_lfsr = G_lfsr[15] ^ G_lfsr[14] ^ G_lfsr[12] ^ G_lfsr[3];
    wire Bfeedback_lfsr = B_lfsr[15] ^ B_lfsr[14] ^ B_lfsr[7] ^ B_lfsr[3];
//

    always @(posedge clk or posedge rst) begin
        if (rst) begin
/// initial 
    // lfsr seed
            R_lfsr <= 16'hA3C5;                  // seed
            G_lfsr <= 16'hA3F5;                  // seed
            B_lfsr <= 16'h03C5;                  // seed

            R_lfsr_out <= 8'h0;  // YAHA PER CHANGE KIYA THA
            G_lfsr_out <= 8'h0;  // YAHA PER CHANGE KIYA THA
            B_lfsr_out <= 8'h0;  // YAHA PER CHANGE KIYA THA

    // bit couter key_ready
            key_ready <= 1'b0;
            bit_counter <= 3'b0;                            // Reset bit counter

    // Initialize chaotic state and pipeline properly
            x <= 16'sh7EF0;        
            x_square <= 32'sh0;                             // Initialize to zero to avoid X
            x_mult <= 32'sh0;                               // Initialize to zero to avoid X
            x_section <= 16'sh0;                            // Initialize to zero to avoid X
            x_sub <= 16'sh7EF0;                             // Initialize with initial value

            y <= 16'sh7AF0;
            y_square <= 32'sh0;
            y_mult <= 32'sh0;
            y_section <= 16'sh0;
            y_sub <= 16'sh7AF0;

            z <= 16'sh3EF0;
            z_square <= 32'sh0;
            z_mult <= 32'sh0;
            z_section <= 16'sh0;
            z_sub <= 16'sh3EF0;
///             
/// logic else             

        end else begin
    // Update LFSRs
            R_lfsr <= {R_lfsr[14:0], Rfeedback_lfsr};
            G_lfsr <= {G_lfsr[14:0], Gfeedback_lfsr};
            B_lfsr <= {B_lfsr[14:0], Bfeedback_lfsr};

            
    // Store LFSR outputs (8-bit from 16-bit LFSRs)
            R_lfsr_out <= {R_lfsr_out[6:0], R_lfsr[0]};                   
            G_lfsr_out <= {G_lfsr_out[6:0], G_lfsr[0]};                   
            B_lfsr_out <= {B_lfsr_out[6:0], B_lfsr[0]};                   
            
    // Update chaotic sequence - pipeline stages
            x_square <= x * x;                              // Stage 1: square
            x_mult <= x_square <<< 1;                       // Stage 2: multiply by 2
            x_section <= x_mult[30:15];                     // Stage 3: extract section
            x_sub <= 16'sh7FFF - x_section;                 // Stage 4: subtract from max
            x <= x_sub;                                     // Stage 5: update x

            y_square <= y * y;
            y_mult <= y_square <<< 1;      
            y_section <= y_mult[30:15];    
            y_sub <= 16'sh7FFF - y_section;
            y <= y_sub;                    

            z_square <= z * z;         
            z_mult <= z_square <<< 1;      
            z_section <= z_mult[30:15];    
            z_sub <= 16'sh7FFF - z_section;
            z <= z_sub;          

    // Check if 8 bits (1 byte) are ready
            if (bit_counter == 3'b111) begin                // When counter reaches 7 (8th bit)
                key_ready <= 1'b1;
                // Generate 8-bit outputs by XORing stored LFSR outputs with chaotic values
                R_Out <= R_lfsr_out ^ x[10:3];                 // stored LFSR XOR chaotic[7:0]
                G_Out <= G_lfsr_out ^ y[10:3];                 // stored LFSR XOR chaotic[7:0]
                B_Out <= B_lfsr_out ^ z[10:3];                 // stored LFSR XOR chaotic[7:0]
                bit_counter <= 3'b0;                        // Reset counter to start collecting next byte
            end else begin
                key_ready <= 1'b0;                          // Not ready yet
                bit_counter <= bit_counter + 1'b1;          // Increment counter
            end
        end
/// end else    
    end

endmodule
