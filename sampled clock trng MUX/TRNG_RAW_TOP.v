// ============================================================================
// File: TRNG_RAW_TOP.v
// Module: TRNG_RAW_TOP
// Description: Raw Physical Ring-Oscillator TRNG Core.
//              Cycles through 4 independent physical Ring Oscillators (RO_3,
//              RO_5, RO_7, RO_9) via an unconditioned 4:1 Multiplexer.
//              Produces raw unconditioned entropy bits with metastability
//              protection and a clean 1-cycle valid strobe.
// ============================================================================

`timescale 1ns/1ps

(* KEEP_HIERARCHY = "TRUE" *)
module TRNG_RAW_TOP #(
    // Raw sample rate = clk frequency / SAMPLE_DIV.
    // 100 MHz / 50 = 2.0 MSamples/sec
    parameter integer SAMPLE_DIV = 50,
    parameter integer WARMUP_SAMPLES = 64
) (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       enable,
    output reg        raw_bit,
    output reg        raw_valid,
    output reg [1:0]  source_id
);

    // -------------------------------------------------------------------------
    // Internal Ring Oscillator Interconnects
    // -------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE" *) wire ro3_out;
    (* DONT_TOUCH = "TRUE" *) wire ro5_out;
    (* DONT_TOUCH = "TRUE" *) wire ro7_out;
    (* DONT_TOUCH = "TRUE" *) wire ro9_out;

    // Instantiate the 4 physical ring oscillators
    RO_3 ro_3_inst (.enable(enable), .out(ro3_out));
    RO_5 ro_5_inst (.enable(enable), .out(ro5_out));
    RO_7 ro_7_inst (.enable(enable), .out(ro7_out));
    RO_9 ro_9_inst (.enable(enable), .out(ro9_out));

    // -------------------------------------------------------------------------
    // 4:1 Multiplexer Selection
    // -------------------------------------------------------------------------
    (* DONT_TOUCH = "TRUE" *) reg [1:0] source_sel;
    (* DONT_TOUCH = "TRUE" *) reg       selected_ro;

    always @(*) begin
        case (source_sel)
            2'b00:   selected_ro = ro3_out;
            2'b01:   selected_ro = ro5_out;
            2'b10:   selected_ro = ro7_out;
            default: selected_ro = ro9_out;
        endcase
    end

    // -------------------------------------------------------------------------
    // Sample Timing & Synchronized Metastability Hardening
    // -------------------------------------------------------------------------
    reg [31:0] sample_count;
    reg [31:0] warmup_count;
    wire       sample_strobe;

    assign sample_strobe = (sample_count == SAMPLE_DIV - 1);

    // Metastability barrier registers for sampling asynchronous RO output
    (* ASYNC_REG = "TRUE", DONT_TOUCH = "TRUE" *) reg ro_sample_q1;
    reg [1:0] sample_source_id_q1;
    reg       sample_pending;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sample_count        <= 32'd0;
            warmup_count        <= 32'd0;
            source_sel          <= 2'b00;
            source_id           <= 2'b00;
            raw_bit             <= 1'b0;
            raw_valid           <= 1'b0;
            ro_sample_q1        <= 1'b0;
            sample_source_id_q1 <= 2'b00;
            sample_pending      <= 1'b0;
        end else if (!enable) begin
            sample_count        <= 32'd0;
            warmup_count        <= 32'd0;
            source_sel          <= 2'b00;
            source_id           <= 2'b00;
            raw_bit             <= 1'b0;
            raw_valid           <= 1'b0;
            ro_sample_q1        <= 1'b0;
            sample_source_id_q1 <= 2'b00;
            sample_pending      <= 1'b0;
        end else begin
            // Default: raw_valid is a 1-cycle active-high pulse
            raw_valid <= 1'b0;

            // Pipeline stage 2: Deliver stabilized raw bit & valid strobe
            if (sample_pending) begin
                sample_pending <= 1'b0;
                if (warmup_count < WARMUP_SAMPLES) begin
                    warmup_count <= warmup_count + 1'b1;
                    raw_valid    <= 1'b0;
                end else begin
                    raw_bit   <= ro_sample_q1;
                    source_id <= sample_source_id_q1;
                    raw_valid <= 1'b1;
                end
            end

            // Sample interval counter
            if (sample_strobe) begin
                sample_count        <= 32'd0;
                // Stage 1: Capture asynchronous RO phase jitter
                ro_sample_q1        <= selected_ro;
                sample_source_id_q1 <= source_sel;
                sample_pending      <= 1'b1;
                // Rotate MUX to next ring oscillator for the subsequent sample
                source_sel          <= source_sel + 1'b1;
            end else begin
                sample_count <= sample_count + 1'b1;
            end
        end
    end

endmodule
