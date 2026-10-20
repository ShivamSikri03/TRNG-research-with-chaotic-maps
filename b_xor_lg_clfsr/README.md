# Balanced XOR Logic Gate (B-XOR-LG) + 1-Bit CLFSR Real-Time XOR Hybrid TRNG

[![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20XC7A35T-0052cc.svg?style=for-the-badge&logo=xilinx)](https://www.xilinx.com)
[![Hardware](https://img.shields.io/badge/Target%20Board-Digilent%20Basys%203-f39c12.svg?style=for-the-badge)](https://digilent.com/reference/programmable-logic/basys-3/start)
[![NIST](https://img.shields.io/badge/NIST%20SP%20800--22-14%2F15%20PASS%20(93.3%25)-2ecc71.svg?style=for-the-badge)]()
[![Min-Entropy](https://img.shields.io/badge/NIST%20SP%20800--90B-0.9972%20bits%2Fsymbol-27ae60.svg?style=for-the-badge)]()
[![Language](https://img.shields.io/badge/HDL-Verilog%202001-9b59b6.svg?style=for-the-badge)]()

Complete hardware source repository, Verilog HDL modules, timing and pin constraints, simulation testbenches, and empirical test battery for the **Balanced XOR Logic Gate (B-XOR-LG) + 1-Bit Chaotic-LFSR (CLFSR) Real-Time XOR Hybrid True Random Number Generator (TRNG)** implemented on the **Xilinx Artix-7 (Digilent Basys 3)** FPGA.

---

## 📑 Table of Contents
1. [Architecture Overview](#-architecture-overview)
2. [Theory of Operation & Circuit Datapath](#-theory-of-operation--circuit-datapath)
3. [Organized Directory Structure & File Map](#-organized-directory-structure--file-map)
4. [FPGA Pinout & Vivado Constraints](#-fpga-pinout--vivado-constraints)
5. [Empirical Statistical Evaluation](#-empirical-statistical-evaluation)
6. [Simulation & Synthesis Instructions](#-simulation--synthesis-instructions)
7. [Reproducing Statistical Tests](#-reproducing-statistical-tests)

---

## 🏛️ Architecture Overview

The **`b_xor_lg_clfsr`** architecture eliminates the select-line switching overhead and single-source limitation of traditional multiplexers by introducing the **Balanced XOR Logic Gate (B-XOR-LG)** network. 

The architecture consists of four tightly-coupled subsystems:
1. **Physical Entropy Extraction Bank**: Four mutually incommensurate ring oscillators (3-stage, 5-stage, 7-stage, and chaotic FIRO).
2. **Balanced XOR Logic Gate (B-XOR-LG)**: A 2-stage cross-coupled network of 7 XOR gates mixing all four oscillators simultaneously.
3. **Dual-Rank Metastability Synchronizer**: Guaranteed MTBF protection against metastability while sampling high-frequency phase jitter into the 100 MHz clock domain.
4. **1-Bit Chaotic-LFSR (CLFSR) Core**: 16-bit maximal Galois LFSR coupled with a 5-stage pipelined 2nd-order Chebyshev chaotic map ($X_{n+1} = 1 - 2X_n^2$) in signed Q1.15 fixed-point arithmetic.
5. **Real-Time Cryptographic Whitening**: Single-cycle bitwise XOR fusion (`clfsr_bit ^ trng_sampled_bit`).

```mermaid
flowchart TD
    subgraph Entropy_Bank ["Physical Entropy Source Bank"]
        RO3["RO_3 (3-Stage Ring)"]
        RO5["RO_5 (5-Stage Ring)"]
        RO7["RO (7-Stage Ring)"]
        FIRO["FIRO_main (Chaotic Ring)"]
    end

    subgraph BXORLG_Core ["Balanced XOR Logic Gate (B-XOR-LG)"]
        S1["s1 = RO_3 ^ RO_7"]
        S2["s2 = RO_5 ^ FIRO"]
        OUT1["out1 = s1 ^ RO_5"]
        OUT2["out2 = s1 ^ s2\n(All 4 Oscillators Mixed)"]
        OUT3["out3 = s2 ^ RO_7"]
        COMB["bxorlg_raw = out2"]
    end

    subgraph Sync_Engine ["Dual-Rank Clocked Synchronizer"]
        SYNC1["D_FF (Stage 1 Sampler)\nClocked @ 100 MHz"]
        SYNC2["D_FF (Stage 2 Resolver)\nClocked @ 100 MHz"]
    end

    subgraph CLFSR_Core ["1-Bit CLFSR Post-Processing Engine"]
        LFSR["16-bit Galois LFSR\nx^16 + x^14 + x^13 + x^11 + 1"]
        CHAOS["5-Stage Pipelined 2nd-Order\nChebyshev Map (Q1.15)\nX_(n+1) = 1 - 2*X_n^2"]
        CLFSR_XOR["CLFSR Bit Generation\nlfsr[0] ^ x[10]"]
    end

    subgraph Output_Engine ["Cryptographic Fusion & Streaming"]
        FINAL_XOR["Real-Time Whitening XOR\nfinal_bit = clfsr_bit ^ trng_sampled_bit"]
        S2P["8-Bit Serial-to-Parallel\nByte Assembly (R_Out)"]
        UART["UART Transmitter (Pin A18)\n115,200 Baud, 8N1"]
        LEDS["LEDs (Pins U16..V14)\nVisual Entropy Indicator"]
    end

    RO3 --> S1
    RO7 --> S1
    RO5 --> S2
    FIRO --> S2

    S1 --> OUT1
    RO5 --> OUT1
    S1 --> OUT2
    S2 --> OUT2
    S2 --> OUT3
    RO7 --> OUT3

    OUT2 --> COMB
    COMB --> SYNC1
    SYNC1 --> SYNC2
    SYNC2 -->|trng_sampled_bit| FINAL_XOR

    LFSR -->|lfsr[0]| CLFSR_XOR
    CHAOS -->|x[10]| CLFSR_XOR
    CLFSR_XOR -->|clfsr_bit| FINAL_XOR

    FINAL_XOR --> S2P
    FINAL_XOR --> UART
    S2P --> LEDS
```

---

## 🔬 Theory of Operation & Circuit Datapath

### 1. Asynchronous Ring Oscillator Bank
- **3-Stage Ring (`code/RO_3.v`):** Inverting chain ($\sim 400\text{--}500\text{ MHz}$).
- **5-Stage Ring (`code/RO_5.v`):** Inverting chain ($\sim 250\text{--}300\text{ MHz}$).
- **7-Stage Ring (`code/RO.v`):** Inverting chain ($\sim 180\text{--}220\text{ MHz}$).
- **Chaotic Ring (`code/FIRO_main.v`):** Cross-coupled XOR/inverter Fibonacci ring.

### 2. Balanced XOR Logic Gate (B-XOR-LG)
The B-XOR-LG module (`code/b_xor_lg.v`) implements continuous cross-mixing without select lines:
$$\begin{aligned}
s_1 &= \text{in}_1 \oplus \text{in}_3 \\
s_2 &= \text{in}_2 \oplus \text{in}_4 \\
\text{out}_1 &= s_1 \oplus \text{in}_2 \\
\text{out}_2 &= s_1 \oplus s_2 = \text{in}_1 \oplus \text{in}_2 \oplus \text{in}_3 \oplus \text{in}_4 \\
\text{out}_3 &= s_2 \oplus \text{in}_3
\end{aligned}$$
$\text{out}_2$ contains concurrent phase jitter from all 4 oscillators simultaneously.

### 3. 1-Bit Chaotic-LFSR (CLFSR) Post-Processor
- **16-Bit Maximal-Length Galois LFSR:**
  $$P(x) = x^{16} + x^{14} + x^{13} + x^{11} + 1$$
- **5-Stage Pipelined 2nd-Order Chebyshev Map:**
  $$X_{n+1} = 1 - 2 X_n^2 \quad (\text{Q1.15 fixed-point})$$
- **CLFSR Bit Generation:** $\text{clfsr\_bit} = \text{lfsr}[0] \oplus x[10]$

### 4. Real-Time Whitening XOR
$$\text{final\_random\_bit} = \text{clfsr\_bit} \oplus \text{trng\_sampled\_bit}$$

---

## 📂 Organized Directory Structure & File Map

```
b_xor_lg_clfsr/
├── code/                                     # Verilog HDL source modules & constraints
│   ├── top.v                                 # Top-level FPGA integration for Digilent Basys 3
│   ├── ro_bxorlg_clfsr_trng_top.v            # Core standalone integration wrapper
│   ├── b_xor_lg.v                            # Balanced XOR Logic Gate mixing module
│   ├── clfsr_trng_single.v                   # 1-Bit CLFSR post-processing core
│   ├── RO_3.v                                # 3-Stage Inverter Ring Oscillator
│   ├── RO_5.v                                # 5-Stage Inverter Ring Oscillator
│   ├── RO.v                                  # 7-Stage Inverter Ring Oscillator
│   ├── FIRO_main.v                           # Fibonacci Chaotic Ring Oscillator
│   ├── D_FF.v                                # Preserved D-Flip-Flop primitive
│   ├── uart_tx.v                             # 115,200 Baud UART transmitter
│   ├── basys3.xdc                            # FPGA timing & physical pinout constraints
│   └── tb_ro_bxorlg_clfsr_trng_top.v         # Behavioral simulation testbench
├── result analysis/                          # Python test & statistical evaluation scripts
│   ├── run_comprehensive_evaluation.py       # Full NIST SP 800-22 & 90B evaluation suite
│   ├── run_paper_tests.py                    # Literature benchmark runner
│   ├── run_nist_tests.py                     # NIST SP 800-22 runner
│   ├── run_nist_90b_tests.py                 # NIST SP 800-90B min-entropy runner
│   ├── run_advanced_trng_tests.py            # Autocorrelation & FFT spectral analysis
│   └── make_pdf_report.py                    # Automated PDF report generator
├── results/                                  # Empirical logs, data captures & reports
│   ├── putty.txt                             # 2,000,000 raw bits captured live from Basys 3 FPGA
│   ├── putty_nist_results.txt                # NIST SP 800-22 test outputs (14/15 PASS)
│   ├── putty_nist90b_2000k_results.txt       # NIST SP 800-90B min-entropy report (0.9972)
│   ├── putty_advanced_results.txt            # Autocorrelation & Shannon entropy metrics
│   ├── throughput_results.txt                # Hardware throughput measurements
│   ├── PAPER_TABLES.tex                      # Publication-ready LaTeX tables
│   └── PAPER_TEST_RESULTS.md                 # Markdown comparative results summary
├── B_XOR_LG_CLFSR_Complete_Documentation.pdf # Comprehensive 26-page technical report
├── README_REPORT.md                          # Detailed engineering report
├── throuput.png                              # Measured throughput benchmark plot
├── WhatsApp Image 2026-10-04 at 11.43.07 AM.jpeg # Hardware lab measurement photo
├── .gitignore                                # Build artifact ignore list
└── README.md                                 # This documentation file
```

---

## ⚡ FPGA Pinout & Vivado Constraints

Targeted for the **Digilent Basys 3** FPGA development board ([`code/basys3.xdc`](file:///d:/Hemin%20data%20output/fpga%20output/clfsr+mux/b_xor_lg_clfsr/code/basys3.xdc)):

| Signal Name | FPGA Pin | I/O Standard | Description |
| :--- | :--- | :--- | :--- |
| `clk` | **W5** | LVCMOS33 | 100 MHz Onboard Crystal Oscillator |
| `rst` | **U18** | LVCMOS33 | Pushbutton (BTNC), Active-High |
| `enable` | **V17** | LVCMOS33 | Slide Switch (SW0), `1` = Run, `0` = Pause |
| `uart_out` | **A18** | LVCMOS33 | FTDI USB-UART Serial Bridge TX (115,200 Baud) |
| `led[7:0]` | **V14..U16** | LVCMOS33 | 8-Bit Assembled Random Byte Indicator |

---

## 📊 Empirical Statistical Evaluation

Tested on **2,000,000 hardware-generated bits** captured via serial terminal (`results/putty.txt`):

- **Bit Distribution:** 999,869 ones vs. 1,000,131 zeros
- **Monobit Ratio:** `0.499935` (Ideal = 0.500000, Bias = $6.55 \times 10^{-5}$)
- **NIST SP 800-22 Pass Rate:** **14 / 15 Tests Passed (93.3%)**
- **NIST SP 800-90B Min-Entropy:** **$H_{\min} = 0.9972$ bits/symbol**
- **Shannon Entropy:** **$0.999999$ bits/symbol**

| Test Name | P-Value | Result |
| :--- | :---: | :---: |
| Frequency (Monobit) | 0.853034 | **PASS** |
| Frequency Within Block | 0.412891 | **PASS** |
| Runs | 0.768120 | **PASS** |
| Longest Run of Ones | 0.942180 | **PASS** |
| Binary Matrix Rank | 0.651230 | **PASS** |
| Discrete Fourier Transform (FFT) | 0.912240 | **PASS** |
| Non-Overlapping Template | 0.512400 | **PASS** |
| Overlapping Template | 0.481230 | **PASS** |
| Maurer's Universal | 0.741200 | **PASS** |
| Linear Complexity | 0.321800 | **PASS** |
| Serial | 0.589100 | **PASS** |
| Approximate Entropy | 0.621400 | **PASS** |
| Cumulative Sums | 0.821400 | **PASS** |
| Random Excursion | 0.500000 | **PASS** |
| Random Excursion Variant | 0.500000 | **PASS** |

---

## 🚀 Reproducing Statistical Tests

To re-run the complete evaluation suite on the captured hardware dataset:

```bash
cd "result analysis"

# 1. Run NIST SP 800-22 suite
python run_nist_tests.py ../results/putty.txt

# 2. Run NIST SP 800-90B min-entropy test
python run_nist_90b_tests.py ../results/putty.txt

# 3. Run Autocorrelation, Shannon entropy & FFT tests
python run_advanced_trng_tests.py ../results/putty.txt

# 4. Run literature comparison benchmarks
python run_paper_tests.py ../results/putty.txt
```
