import os
import sys
import pypdf
from io import BytesIO
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Preformatted, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

# Colors
C_PRIMARY = colors.HexColor("#1A365D")   # Deep navy
C_SECONDARY = colors.HexColor("#2B6CB0") # Slate blue
C_DARK = colors.HexColor("#2D3748")      # Charcoal
C_ACCENT = colors.HexColor("#2B6CB0")    # Accent blue
C_BORDER = colors.HexColor("#CBD5E0")
C_BG_CODE = colors.HexColor("#F8FAFC")
C_BG_CARD = colors.HexColor("#F7FAFC")

class PrecisionNumberedCanvas(canvas.Canvas):
    """
    Two-pass canvas to calculate total page count accurately,
    accounting for inserted schematic pages.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        # We know 1 schematic page will be spliced after Page 3
        total_pages = len(self._saved_page_states) + 1
        
        for state in self._saved_page_states:
            self.__dict__.update(state)
            current_page = self._pageNumber
            
            # If current_page >= 4 (after inserted schematic on page 4),
            # its physical page in final document is (current_page + 1)
            actual_page_num = current_page if current_page <= 3 else current_page + 1
            
            if actual_page_num > 1:
                self.saveState()
                self.setFont("Helvetica", 8)
                self.setFillColor(colors.HexColor("#4A5568"))
                
                # Top Header
                self.drawString(54, 750, "CLFSR + 4x1 MUX Hybrid TRNG — Implementation & Verification Report")
                self.setStrokeColor(C_BORDER)
                self.setLineWidth(0.5)
                self.line(54, 742, 558, 742)
                
                # Bottom Footer
                self.line(54, 45, 558, 45)
                self.drawString(54, 32, "Target: Digilent Basys 3 (Artix-7 XC7A35T) | 100 MHz System Clock")
                page_str = f"Page {actual_page_num} of {total_pages}"
                self.drawRightString(558, 32, page_str)
                self.restoreState()
                
            super().showPage()
        super().save()


def build_text_report(output_filename):
    doc = SimpleDocTemplate(
        output_filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=23,
        leading=27,
        textColor=C_PRIMARY,
        spaceAfter=8
    )

    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11.5,
        leading=16,
        textColor=C_SECONDARY,
        spaceAfter=20
    )

    meta_label = ParagraphStyle(
        'MetaLabel',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=12,
        textColor=C_PRIMARY
    )
    
    meta_val = ParagraphStyle(
        'MetaValue',
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=C_DARK
    )

    h1_style = ParagraphStyle(
        'H1_Custom',
        fontName='Helvetica-Bold',
        fontSize=13.5,
        leading=17,
        textColor=C_PRIMARY,
        spaceBefore=12,
        spaceAfter=6,
        keepWithNext=True
    )

    h2_style = ParagraphStyle(
        'H2_Custom',
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=C_SECONDARY,
        spaceBefore=10,
        spaceAfter=5,
        keepWithNext=True
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        fontName='Helvetica',
        fontSize=8.5,
        leading=12.5,
        textColor=C_DARK,
        spaceAfter=5
    )

    bullet_style = ParagraphStyle(
        'Bullet_Custom',
        fontName='Helvetica',
        fontSize=8.2,
        leading=11.5,
        textColor=C_DARK,
        leftIndent=12,
        spaceAfter=3
    )

    callout_style = ParagraphStyle(
        'Callout_Text',
        fontName='Helvetica-Oblique',
        fontSize=8.2,
        leading=11.5,
        textColor=colors.HexColor("#2C5282")
    )

    code_title_style = ParagraphStyle(
        'CodeTitle',
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.white,
        alignment=1
    )

    table_cell_style = ParagraphStyle(
        'TableCell',
        fontName='Helvetica',
        fontSize=7.8,
        leading=10,
        textColor=C_DARK
    )

    table_cell_center = ParagraphStyle(
        'TableCellCenter',
        fontName='Helvetica',
        fontSize=7.8,
        leading=10,
        textColor=C_DARK,
        alignment=1
    )

    story = []

    # -------------------------------------------------------------
    # PAGE 1: COVER PAGE
    # -------------------------------------------------------------
    story.append(Spacer(1, 15))
    story.append(Paragraph("DIGITAL HARDWARE SECURITY & TRNG EVALUATION", ParagraphStyle('TopLabel', fontName='Helvetica-Bold', fontSize=9.5, textColor=C_SECONDARY, spaceAfter=6)))
    story.append(Paragraph("CLFSR + 4x1 MUX Hybrid True Random Number Generator", title_style))
    story.append(Paragraph("Full Hardware Implementation, RTL Source Code, Timing Constraints, Schematic & NIST Statistical Test Suite Results", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=C_PRIMARY, spaceBefore=0, spaceAfter=12))

    metadata_data = [
        [Paragraph("Target FPGA Device:", meta_label), Paragraph("Xilinx Artix-7 XC7A35T-1CPG236C (Basys 3)", meta_val),
         Paragraph("System Clock Freq:", meta_label), Paragraph("100 MHz (10.00 ns period)", meta_val)],
        [Paragraph("Entropy Architecture:", meta_label), Paragraph("4-to-1 Chaotic MUX with 3 ROs + 1 CLFSR", meta_val),
         Paragraph("Communication Port:", meta_label), Paragraph("USB-UART @ 115,200 Baud (8N1 ASCII)", meta_val)],
        [Paragraph("Test Standard Suite:", meta_label), Paragraph("NIST SP 800-22 Rev 1a & SP 800-90B", meta_val),
         Paragraph("Evaluation Date:", meta_label), Paragraph("10/09/2026", meta_val)],
    ]
    meta_table = Table(metadata_data, colWidths=[110, 155, 110, 129])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), C_BG_CARD),
        ('BOX', (0,0), (-1,-1), 1, C_BORDER),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 12))

    exec_summary_text = (
        "<b>Executive Summary:</b> This technical report compiles the complete hardware implementation, synthesis constraints, "
        "and empirical NIST statistical test results for the <b>CLFSR + MUX Hybrid TRNG</b> design targeted for the Xilinx Artix-7 FPGA. "
        "The architecture combines three distinct Ring Oscillators (8-stage, 5-stage, and 3-stage) with a 5-stage pipelined 2nd-Order "
        "Chebyshev Chaotic LFSR into a 4x1 multiplexer with dynamic self-feedback selection. The bitstream output is sampled at 100 MHz, "
        "debiased via XOR post-processing, and transmitted over UART at 115,200 baud. Comprehensive testing under NIST SP 800-22 and "
        "SP 800-90B suites is presented alongside the complete synthesizable Verilog HDL codebase."
    )
    summary_table = Table([[Paragraph(exec_summary_text, callout_style)]], colWidths=[504])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EBF8FF")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#90CDF4")),
        ('PADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 12))

    story.append(Paragraph("<b>Table of Contents & Document Guide</b>", h2_style))
    toc_items = [
        "<b>Section 1: System Architecture & Hardware Specification</b> — Principles of operation, entropy harvesting, and pipeline.",
        "<b>Section 2: Synthesized RTL Hardware Schematic</b> — High-resolution gate-level schematic generated by Xilinx Vivado.",
        "<b>Section 3: Synthesizable Verilog HDL Source Codes</b> — Full RTL codes (<code>top.v</code>, <code>clfsr_trng_single.v</code>, <code>RO.v</code>, <code>RO_5.v</code>, <code>RO_3.v</code>, <code>uart_tx.v</code>).",
        "<b>Section 4: Xilinx Design Constraints (XDC)</b> — Physical pin mapping, timing exclusions, and loop allowances (<code>basys3.xdc</code>).",
        "<b>Section 5: NIST SP 800-22 Rev 1a Statistical Test Results</b> — 15 standard tests evaluated on 2,000,000 hardware bits.",
        "<b>Section 6: NIST SP 800-90B Entropy Assessment & Continuous Health Tests</b> — Min-entropy estimates, RCT, and APT.",
        "<b>Section 7: Engineering Analysis & Diagnostic Observations</b> — In-depth analysis of hardware entropy dynamics and recommendations."
    ]
    for item in toc_items:
        story.append(Paragraph(f"• {item}", bullet_style))

    story.append(PageBreak())

    # -------------------------------------------------------------
    # PAGE 2: SECTION 1 - SYSTEM ARCHITECTURE
    # -------------------------------------------------------------
    story.append(Paragraph("1. System Architecture & Hardware Specification", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    
    story.append(Paragraph(
        "The <b>CLFSR + MUX Hybrid TRNG</b> is a multi-source cryptographic entropy generator combining physical phase jitter "
        "from free-running asynchronous ring oscillators with the deterministic pseudo-random diffusion of a digital chaotic map and a Galois LFSR. "
        "This design replaces conventional Fibonacci/Galois Ring Oscillators (FIRO/GARO) with a dedicated <b>Chaotic Linear Feedback Shift Register (CLFSR)</b>.",
        body_style
    ))

    story.append(Paragraph("1.1 Subsystem Functional Descriptions", h2_style))
    story.append(Paragraph(
        "<b>1. Multi-Stage Ring Oscillators (RO, RO_5, RO_3):</b><br/>"
        "Three distinct free-running inverter chains are implemented with prime/odd stage counts to prevent mode-locking and cross-talk injection: "
        "an 8-stage oscillator (NAND + 4 NOT + 3 buffer NOTs), a 5-stage oscillator (NAND + 4 NOT), and a 3-stage oscillator (NAND + 2 NOT). "
        "Thermal and power-supply noise introduce continuous phase jitter into the oscillating edges.",
        bullet_style
    ))
    story.append(Paragraph(
        "<b>2. Single-Channel Chaotic LFSR (CLFSR):</b><br/>"
        "Combines a 16-bit maximal-length LFSR (polynomial: <i>x<sup>16</sup> + x<sup>14</sup> + x<sup>13</sup> + x<sup>11</sup> + 1</i>) with a "
        "5-stage pipelined 2nd-Order Chebyshev Chaotic Map (<i>X<sub>n+1</sub> = 1 - 2X<sub>n</sub><sup>2</sup></i> in signed Q1.15 fixed-point). "
        "The physical jitter from <code>RO_3</code> is fed directly into the LFSR feedback tap (<code>trng_in</code>), continuously perturbing the internal state.",
        bullet_style
    ))
    story.append(Paragraph(
        "<b>3. 4x1 Chaotic Multiplexer with Dynamic Self-Feedback:</b><br/>"
        "The MUX selects dynamically between the 4 entropy streams using <code>sel = {clk, mux_out}</code>. "
        "By feeding back the instantaneous MUX output into its own selection line combined with the system clock, "
        "the multiplexer exhibits non-linear state-dependent switching dynamics.",
        bullet_style
    ))
    story.append(Paragraph(
        "<b>4. Sampling, Post-Processing & UART Interface:</b><br/>"
        "The MUX output (<code>mux_out</code>) and the 8-stage RO output (<code>ro1_out</code>) are sampled synchronously on the 100 MHz rising clock edge into flip-flops <code>q1</code> and <code>q2</code>. "
        "An XOR gate performs von Neumann-style de-biasing: <code>random_bit = q1 ^ q2</code>. "
        "A 2-stage D-Flip-Flop synchronizer protects against metastability before data is serialized into ASCII '0'/'1' packets via UART at 115,200 baud.",
        bullet_style
    ))

    story.append(Spacer(1, 6))
    
    arch_table_data = [
        [Paragraph("<b>Component</b>", table_header_style), Paragraph("<b>Implementation / Specs</b>", table_header_style), Paragraph("<b>Role / Purpose</b>", table_header_style)],
        [Paragraph("<b>RO (8-stage)</b>", table_cell_style), Paragraph("NAND + 4 inverters + 3 buffers", table_cell_style), Paragraph("Primary entropy source & XOR de-biasing reference", table_cell_style)],
        [Paragraph("<b>RO_5 (5-stage)</b>", table_cell_style), Paragraph("NAND + 4 inverters", table_cell_style), Paragraph("High-frequency physical jitter generation", table_cell_style)],
        [Paragraph("<b>RO_3 (3-stage)</b>", table_cell_style), Paragraph("NAND + 2 inverters", table_cell_style), Paragraph("Ultra-high frequency jitter & CLFSR perturbation", table_cell_style)],
        [Paragraph("<b>CLFSR Module</b>", table_cell_style), Paragraph("16-bit LFSR + 5-stage Chebyshev map", table_cell_style), Paragraph("Deterministic non-linear expansion & diffusion", table_cell_style)],
        [Paragraph("<b>4x1 MUX</b>", table_cell_style), Paragraph("<code>sel = {clk, mux_out}</code>", table_cell_style), Paragraph("Chaotic non-linear signal multiplexing", table_cell_style)],
        [Paragraph("<b>Post-Processing</b>", table_cell_style), Paragraph("XOR gate + 2-Stage D-FF Sync", table_cell_style), Paragraph("De-biasing and metastability protection", table_cell_style)],
        [Paragraph("<b>UART Transmitter</b>", table_cell_style), Paragraph("115,200 Baud, 8N1, 100MHz clock", table_cell_style), Paragraph("Live hardware bitstream acquisition via USB", table_cell_style)],
    ]
    arch_table = Table(arch_table_data, colWidths=[95, 195, 214])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_PRIMARY),
        ('GRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_BG_CARD]),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(arch_table)

    story.append(PageBreak())

    # -------------------------------------------------------------
    # PAGE 3: SECTION 2 - SCHEMATIC INTRO (Schematic will be page 4)
    # -------------------------------------------------------------
    story.append(Paragraph("2. Synthesized RTL Hardware Schematic", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    story.append(Paragraph(
        "The gate-level synthesized RTL schematic of the <b>CLFSR + MUX Hybrid TRNG</b> generated directly by Xilinx Vivado "
        "for the Artix-7 (XC7A35T) FPGA architecture is presented on the following page (Page 4).",
        body_style
    ))
    story.append(Paragraph(
        "<b>Key Schematic Features:</b><br/>"
        "• <b>Entropy Generation Core:</b> Shows the parallel placement of <code>RO_inst</code>, <code>RO_5_inst</code>, and <code>RO_3_inst</code> alongside the pipelined <code>clfsr_inst</code>.<br/>"
        "• <b>Feedback Multiplexer:</b> Demonstrates the dynamic feedback wiring from <code>mux_out</code> back into the select multiplexer logic.<br/>"
        "• <b>Sampling & Synchronizer Registers:</b> Depicts <code>q1</code>, <code>q2</code>, XOR logic, and the dual-stage shift register <code>sync1</code> / <code>sync2</code>.<br/>"
        "• <b>UART Serialization:</b> Connects the synchronized stream to <code>uart_inst</code> for live serial transmission.",
        body_style
    ))
    story.append(Spacer(1, 10))
    story.append(Paragraph("<i>(See next page for the full-page high-resolution Vivado RTL schematic.)</i>", callout_style))
    story.append(PageBreak())

    # -------------------------------------------------------------
    # CODE LISTINGS (PAGES 5+)
    # -------------------------------------------------------------
    def format_code_block_chunked(title, file_path, chunk_size=38):
        content = []
        header_table = Table([[Paragraph(f"<b>Source Code: {title}</b> (<code>{os.path.basename(file_path)}</code>)", code_title_style)]], colWidths=[504])
        header_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), C_PRIMARY),
            ('TOPPADDING', (0,0), (-1,-1), 3.5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
            ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ]))
        content.append(header_table)

        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        code_style = ParagraphStyle(
            'CodeStyle',
            fontName='Courier',
            fontSize=6.2,
            leading=7.8,
            textColor=colors.HexColor("#1A202C")
        )

        for chunk_start in range(0, len(lines), chunk_size):
            chunk_lines = lines[chunk_start : chunk_start + chunk_size]
            numbered = [f"{i+1:3d} | {line}" for i, line in enumerate(chunk_lines, start=chunk_start)]
            code_text = "".join(numbered)
            
            chunk_table = Table([[Preformatted(code_text, code_style)]], colWidths=[504])
            chunk_table.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,-1), C_BG_CODE),
                ('BOX', (0,0), (-1,-1), 0.75, C_BORDER),
                ('TOPPADDING', (0,0), (-1,-1), 2.5),
                ('BOTTOMPADDING', (0,0), (-1,-1), 2.5),
                ('LEFTPADDING', (0,0), (-1,-1), 4),
                ('RIGHTPADDING', (0,0), (-1,-1), 4),
            ]))
            content.append(chunk_table)
            content.append(Spacer(1, 3))

        content.append(Spacer(1, 6))
        return content

    story.append(Paragraph("3. Synthesizable Verilog HDL Source Codes", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    story.append(Paragraph(
        "All hardware description modules in the <code>mux+clfsr</code> directory are documented below in full. "
        "Simulation testbench files (<code>tb_top.v</code>) have been excluded.",
        body_style
    ))
    story.append(Spacer(1, 4))

    src_dir = r"d:\Hemin data output\fpga output\clfsr+mux\mux+clfsr"
    
    # 3.1 top.v
    for elem in format_code_block_chunked("Top-Level Controller & System Integrator", os.path.join(src_dir, "top.v")):
        story.append(elem)

    # 3.2 clfsr_trng_single.v
    for elem in format_code_block_chunked("Single-Channel Chaotic-LFSR (CLFSR)", os.path.join(src_dir, "clfsr_trng_single.v")):
        story.append(elem)

    # 3.3 RO.v
    for elem in format_code_block_chunked("8-Stage Ring Oscillator Module", os.path.join(src_dir, "RO.v")):
        story.append(elem)

    # 3.4 RO_5.v
    for elem in format_code_block_chunked("5-Stage Ring Oscillator Module", os.path.join(src_dir, "RO_5.v")):
        story.append(elem)

    # 3.5 RO_3.v
    for elem in format_code_block_chunked("3-Stage Ring Oscillator Module", os.path.join(src_dir, "RO_3.v")):
        story.append(elem)

    # 3.6 uart_tx.v
    for elem in format_code_block_chunked("UART Serial Transmitter Module (115200 Baud)", os.path.join(src_dir, "uart_tx.v")):
        story.append(elem)

    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 4: CONSTRAINTS FILE
    # -------------------------------------------------------------
    story.append(Paragraph("4. Xilinx Design Constraints (XDC)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    story.append(Paragraph(
        "The constraint file <code>basys3.xdc</code> defines the physical pin assignments for the Digilent Basys 3 board, "
        "clock period definitions, voltage standards, and critical synthesis directives: "
        "<code>ALLOW_COMBINATORIAL_LOOPS</code> and <code>set_false_path</code> required to allow ring oscillator loops without Vivado timing DRC errors.",
        body_style
    ))
    story.append(Spacer(1, 4))

    for elem in format_code_block_chunked("Basys 3 Physical & Timing Constraints", os.path.join(src_dir, "basys3.xdc")):
        story.append(elem)

    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 5: NIST SP 800-22 RESULTS
    # -------------------------------------------------------------
    story.append(Paragraph("5. NIST SP 800-22 Rev 1a Statistical Test Results", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    
    story.append(Paragraph(
        "The hardware bitstream captured from the FPGA via PuTTY (<code>putty.txt</code>, 2,000,000 continuous bits) "
        "was evaluated against all 15 statistical tests in <b>NIST SP 800-22 Rev 1a</b>. "
        "A p-value &ge; 0.01 indicates passing at the 99% statistical confidence interval.",
        body_style
    ))

    nist_res_path = os.path.join(src_dir, "putty_nist_results.txt")
    with open(nist_res_path, 'r') as f:
        nist_lines = f.readlines()

    nist_table_data = [
        [Paragraph("<b>#</b>", table_header_style),
         Paragraph("<b>NIST SP 800-22 Test Name</b>", table_header_style),
         Paragraph("<b>P-Value</b>", table_header_style),
         Paragraph("<b>Threshold (&alpha;)</b>", table_header_style),
         Paragraph("<b>Status</b>", table_header_style)]
    ]

    import re
    for line in nist_lines:
        line = line.strip()
        if not line or line.startswith("NIST") or line.startswith("Input") or line.startswith("Ones") or line.startswith("=") or line.startswith("-") or line.startswith("SUMMARY"):
            continue
        m = re.match(r'^\s*(\d+)\.\s+(.*?)\s+([0-9\.]+)\s+(PASS|FAIL)', line)
        if m:
            idx, name, pval, status = m.groups()
            is_pass = (status == "PASS")
            badge_color = "#2E7D32" if is_pass else "#C62828"
            status_p = Paragraph(f"<font color='{badge_color}'><b>{status}</b></font>", table_cell_center)
            nist_table_data.append([
                Paragraph(str(idx), table_cell_center),
                Paragraph(name.strip(), table_cell_style),
                Paragraph(f"<b>{pval}</b>", table_cell_center),
                Paragraph("0.010000", table_cell_center),
                status_p
            ])

    nist_table = Table(nist_table_data, colWidths=[25, 239, 80, 80, 80])
    nist_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_PRIMARY),
        ('GRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_BG_CARD]),
        ('TOPPADDING', (0,0), (-1,-1), 2.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 2.5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(nist_table)
    story.append(Spacer(1, 8))

    summary_box_text = (
        "<b>NIST SP 800-22 Test Summary:</b><br/>"
        "• <b>Dataset:</b> 2,000,000 bits captured from hardware UART (<code>putty.txt</code>)<br/>"
        "• <b>Bit Distribution:</b> Ones = 915,215 (45.76%), Zeros = 1,084,785 (54.24%)<br/>"
        "• <b>Overall Result:</b> <b>4 / 15 Tests Passed</b> (Binary Matrix Rank, Linear Complexity, Random Excursion, Random Excursion Variant passed)."
    )
    summary_box = Table([[Paragraph(summary_box_text, body_style)]], colWidths=[504])
    summary_box.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#FFF5F5")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#FEB2B2")),
        ('PADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(summary_box)

    story.append(Spacer(1, 10))

    # -------------------------------------------------------------
    # SECTION 6: NIST SP 800-90B RESULTS
    # -------------------------------------------------------------
    story.append(Paragraph("6. NIST SP 800-90B Entropy Assessment & Health Tests", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    
    story.append(Paragraph(
        "NIST SP 800-90B provides guidelines for min-entropy (<i>H<sub>min</sub></i>) estimation "
        "and online health tests (Repetition Count Test and Adaptive Proportion Test) for noise sources.",
        body_style
    ))

    n90b_table_data = [
        [Paragraph("<b>Evaluation Category</b>", table_header_style),
         Paragraph("<b>Estimator / Metric</b>", table_header_style),
         Paragraph("<b>Measured Value</b>", table_header_style),
         Paragraph("<b>Criteria / Limit</b>", table_header_style),
         Paragraph("<b>Result / Status</b>", table_header_style)],
        
        [Paragraph("<b>Min-Entropy Estimation</b>", table_cell_style),
         Paragraph("Most Common Value (MCV)", table_cell_style),
         Paragraph("0.880179 bits/symbol", table_cell_center),
         Paragraph("Target &ge; 0.90", table_cell_center),
         Paragraph("<font color='#2B6CB0'><b>Evaluated</b></font>", table_cell_center)],
        
        [Paragraph("<b>Min-Entropy Estimation</b>", table_cell_style),
         Paragraph("Collision Estimate", table_cell_style),
         Paragraph("0.492534 bits/symbol", table_cell_center),
         Paragraph("Target &ge; 0.90", table_cell_center),
         Paragraph("<font color='#C62828'><b>Bottleneck</b></font>", table_cell_center)],

        [Paragraph("<b>Min-Entropy Estimation</b>", table_cell_style),
         Paragraph("Markov Estimate", table_cell_style),
         Paragraph("0.878576 bits/symbol", table_cell_center),
         Paragraph("Target &ge; 0.90", table_cell_center),
         Paragraph("<font color='#2B6CB0'><b>Evaluated</b></font>", table_cell_center)],

        [Paragraph("<b>Overall Assessed Entropy</b>", table_cell_style),
         Paragraph("<b>Minimum (H_min)</b>", table_cell_style),
         Paragraph("<b>0.492534 bits/symbol</b>", table_cell_center),
         Paragraph("Min of all estimators", table_cell_center),
         Paragraph("<font color='#D97706'><b>0.4925</b></font>", table_cell_center)],

        [Paragraph("<b>Continuous Health Test</b>", table_cell_style),
         Paragraph("Repetition Count Test (RCT)", table_cell_style),
         Paragraph("Max: 23 (28 Failures)", table_cell_center),
         Paragraph("Threshold C = 19", table_cell_center),
         Paragraph("<font color='#C62828'><b>FAIL</b></font>", table_cell_center)],

        [Paragraph("<b>Continuous Health Test</b>", table_cell_style),
         Paragraph("Adaptive Proportion Test (APT)", table_cell_style),
         Paragraph("Max: 318 (0 Failures)", table_cell_center),
         Paragraph("Threshold C = 332 (W=512)", table_cell_center),
         Paragraph("<font color='#2E7D32'><b>PASS</b></font>", table_cell_center)],
    ]
    n90b_table = Table(n90b_table_data, colWidths=[110, 134, 100, 90, 70])
    n90b_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), C_PRIMARY),
        ('GRID', (0,0), (-1,-1), 0.5, C_BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, C_BG_CARD]),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ]))
    story.append(n90b_table)

    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 7: ENGINEERING ANALYSIS
    # -------------------------------------------------------------
    story.append(Paragraph("7. Engineering Analysis & Key Takeaways", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=C_SECONDARY, spaceBefore=2, spaceAfter=8))
    
    analysis_paragraphs = [
        ("<b>7.1 Comparison: Hardware Output vs. Standalone Algorithmic Simulation</b>",
         "When evaluated purely in simulation (<code>clfsr_r_2m_bits.txt</code>), the standalone CLFSR module passed <b>14 out of 15 NIST SP 800-22 tests</b> with an optimal 50.03% ones/zeros balance (0.500359). "
         "However, the physical hardware stream captured from FPGA (<code>putty.txt</code>) exhibited a 0-bias (45.76% ones, 54.24% zeros), causing failures in frequency, runs, and template tests."),
        
        ("<b>7.2 Root Cause Analysis in FPGA Implementation</b>",
         "1. <b>Combinational Feedback MUX Selection Hazard:</b> In <code>top.v</code>, the multiplexer select lines are driven by <code>sel = {clk, mux_out}</code>. "
         "Feeding back the asynchronous MUX output into its own select line creates an unclocked combinational loop and glitching races inside FPGA LUTs.<br/>"
         "2. <b>Vivado Synthesis Optimization of Inverter Chains:</b> In behavioral Verilog, cascaded inverters (<code>w1=~w_nand; w2=~w1; ...</code>) in <code>RO.v</code>, <code>RO_5.v</code>, and <code>RO_3.v</code> "
         "are susceptible to logic minimization into single LUTs or even static levels unless primitive-level instantiations (<code>LUT1</code> / <code>LUT6</code>) or rigid <code>DONT_TOUCH / KEEP</code> attributes are mapped to every intermediate net.<br/>"
         "3. <b>Under-Sampling & Decimation Ratio:</b> The UART baud-rate generator samples 1 bit every 8,680 clock cycles (at 100 MHz, 115200 baud). If oscillator frequencies phase-lock to harmonics of the 100 MHz clock, periodic sampling induces deterministic duty-cycle skew."),

        ("<b>7.3 Recommended Improvements for High-Performance Cryptographic TRNG</b>",
         "• <b>Instantiate Xilinx Primitive LUTs:</b> Replace behavioral inverter equations in <code>RO.v</code> with explicit <code>LUT1</code> primitives with fixed INIT masks and RLOC placement constraints.<br/>"
         "• <b>Synchronous MUX Control:</b> Register the MUX select line <code>sel</code> in a clocked register rather than creating an asynchronous feedback loop.<br/>"
         "• <b>Hardware Post-Processor (Von Neumann / SHA-256 / XOR Tree):</b> Implement a hardware Von Neumann extractor or XOR accumulator before the UART FIFO to eliminate residual DC bias.")
    ]

    for title, text in analysis_paragraphs:
        story.append(Paragraph(title, h2_style))
        story.append(Paragraph(text, body_style))
        story.append(Spacer(1, 3))

    doc.build(story, canvasmaker=PrecisionNumberedCanvas)
    print(f"Generated text report: {output_filename}")


def create_schematic_overlay(page_num, total_pages):
    """Creates a 1-page PDF stream containing header and footer for the schematic page."""
    packet = BytesIO()
    can = canvas.Canvas(packet, pagesize=letter)
    
    can.saveState()
    can.setFont("Helvetica", 8)
    can.setFillColor(colors.HexColor("#4A5568"))
    
    # Top Header
    can.drawString(54, 750, "CLFSR + 4x1 MUX Hybrid TRNG — Implementation & Verification Report")
    can.setStrokeColor(C_BORDER)
    can.setLineWidth(0.5)
    can.line(54, 742, 558, 742)
    
    # Bottom Footer
    can.line(54, 45, 558, 45)
    can.drawString(54, 32, "Target: Digilent Basys 3 (Artix-7 XC7A35T) | 100 MHz System Clock")
    page_str = f"Page {page_num} of {total_pages}"
    can.drawRightString(558, 32, page_str)
    can.restoreState()
    
    can.showPage()
    can.save()
    packet.seek(0)
    return packet


def merge_with_schematic(text_pdf, schematic_pdf, final_output):
    reader_text = pypdf.PdfReader(text_pdf)
    reader_schematic = pypdf.PdfReader(schematic_pdf)
    writer = pypdf.PdfWriter()

    total_pages = len(reader_text.pages) + len(reader_schematic.pages)
    schematic_page_num = 4  # Insert after page 3

    # Generate overlay for schematic page
    overlay_stream = create_schematic_overlay(schematic_page_num, total_pages)
    overlay_reader = pypdf.PdfReader(overlay_stream)
    overlay_page = overlay_reader.pages[0]

    # Process pages
    for i, page in enumerate(reader_text.pages):
        writer.add_page(page)
        if i == 2:  # After page 3 (index 2)
            for sch_page in reader_schematic.pages:
                sch_page.merge_page(overlay_page)
                writer.add_page(sch_page)

    with open(final_output, "wb") as f:
        writer.write(f)
    print(f"Successfully generated final merged report at: {final_output}")


if __name__ == "__main__":
    src_dir = r"d:\Hemin data output\fpga output\clfsr+mux\mux+clfsr"
    intermediate_pdf = os.path.join(src_dir, "intermediate_report.pdf")
    schematic_pdf = os.path.join(src_dir, "schematic.pdf")
    final_pdf = os.path.join(src_dir, "CLFSR_MUX_Complete_Documentation.pdf")
    
    build_text_report(intermediate_pdf)
    merge_with_schematic(intermediate_pdf, schematic_pdf, final_pdf)
    
    if os.path.exists(intermediate_pdf):
        os.remove(intermediate_pdf)
    print(f"PDF creation completed successfully: {final_pdf}")
