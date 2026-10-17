# Novel CLFSR + Multi-Oscillator Ring Oscillator (RO) 4:1 MUX Hybrid TRNG

[![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20XC7A35T-blue.svg)](https://www.xilinx.com)
[![Hardware](https://img.shields.io/badge/Board-Digilent%20Basys%203-orange.svg)](https://digilent.com/reference/programmable-logic/basys-3/start)
[![NIST](https://img.shields.io/badge/NIST%20SP%20800--22-15%2F15%20PASS%20(100%25)-brightgreen.svg)]()
[![Min-Entropy](https://img.shields.io/badge/NIST%20SP%20800--90B-0.9967%20bits%2Fsymbol-success.svg)]()
[![Verilog](https://img.shields.io/badge/HDL-Verilog%202001-purple.svg)]()

Hardware design, Verilog HDL source implementations, constraint files, simulation testbenches, and empirical validation suite for a **Novel Hybrid True Random Number Generator (TRNG)** combining an asynchronous multi-stage Ring Oscillator (RO) bank with a dynamically feedback-switched 4:1 Multiplexer and a 1-Bit Chaotic Linear Feedback Shift Register (CLFSR) post-processing core on a **Xilinx Artix-7 (Digilent Basys 3)** FPGA.

---

## 🔬 System Overview & Architecture

The architecture addresses physical entropy extraction challenges, race conditions, duty-cycle bias, and statistical defects observed in standard oscillator-based TRNGs:

1. **Asynchronous Entropy Source Bank:**
   - Three prime/odd inverter stage ring oscillators (`RO_3`, `RO_5`, and 7-stage `RO`).
   - Cross-coupled chaotic inverter ring (`FIRO_main`).
2. **Clocked 4-to-1 Multiplexer with Registered Feedback:**
   - Dynamically selected via `{clk, mux_dff_fb}` where feedback is clocked on the 100 MHz domain to eliminate unclocked combinational race loops.
3. **Dual-Rank Metastability Synchronizer:**
   - Protects downstream logic with guaranteed MTBF against metastability while capturing high-frequency oscillator phase jitter.
4. **1-Bit Chaotic-LFSR (CLFSR) Core:**
   - 16-bit maximal-length Galois LFSR coupled with a 5-stage pipelined 2nd-order Chebyshev chaotic map ($X_{n+1} = 1 - 2X_n^2$) implemented in signed Q1.15 fixed-point arithmetic.
5. **Real-Time XOR Fusion:**
   - Single-cycle bitwise XOR (`clfsr_bit ^ trng_sampled_bit`) acting as a real-time cryptographic whitener.
6. **Parallel UART Streaming:**
   - 8-bit byte assembly engine with a 100 Mbps raw throughput capacity and serial streaming to host via USB-UART (115,200 Baud, 8N1).

---

## 📊 Empirical Validation Results

### 1. NIST SP 800-22 Rev 1a Test Suite
Evaluated over hardware-captured bitstreams (1.64M+ bits captured live via serial port):

| Test Name | P-Value | Result |
| :--- | :--- | :--- |
| **Frequency (Monobit)** | 0.5847 | **PASS** |
| **Block Frequency** | 0.8123 | **PASS** |
| **Cumulative Sums (Forward)** | 0.6412 | **PASS** |
| **Cumulative Sums (Reverse)** | 0.5984 | **PASS** |
| **Runs** | 0.7231 | **PASS** |
| **Longest Run of Ones** | 0.8912 | **PASS** |
| **Rank** | 0.4518 | **PASS** |
| **Discrete Fourier Transform (FFT)** | 0.6729 | **PASS** |
| **Non-Overlapping Template** | 0.5134 (avg) | **PASS** |
| **Overlapping Template** | 0.7812 | **PASS** |
| **Universal Statistical** | 0.6234 | **PASS** |
| **Approximate Entropy** | 0.8415 | **PASS** |
| **Random Excursions** | > 0.01 | **PASS** |
| **Random Excursions Variant** | > 0.01 | **PASS** |
| **Serial (Test 1 & 2)** | 0.6912 / 0.7421 | **PASS** |
| **Linear Complexity** | 0.5183 | **PASS** |

> **Final Outcome:** **15 / 15 Tests Passed (100% Pass Rate)**

### 2. NIST SP 800-90B Min-Entropy
- **Assessed Min-Entropy ($H_{\min}$):** `0.9967 bits / symbol` (ideal is 1.0)
- **Bit Ratio:** `824,523 ones vs. 824,091 zeros` (Ratio: `0.500131`)

---

## 📁 Repository Structure

```
.
├── mux_xor_clfsr/             # Primary architecture: 4:1 MUX + CLFSR Real-Time XOR
│   ├── Basys3_Master.xdc      # FPGA pin assignments & clock constraints
│   ├── top.v                  # Top-level integration module
│   ├── CLFSR_1bit.v           # 1-bit Chaotic-LFSR implementation
│   ├── RO_3.v, RO_5.v, RO.v   # Inverter ring oscillator sources
│   ├── README_REPORT.md       # Comprehensive technical engineering report
│   └── PAPER_TEST_RESULTS.md  # Detailed statistical comparison report
├── b_xor_lg_clfsr/            # Variant: XOR Logic Gate + CLFSR Hybrid
├── b_xor_lg_chaotic/          # Variant: Chaotic Oscillator + XOR Logic Gate
├── chotic_xor_mux/            # Variant: Chaotic Cross-Coupled Ring + 4:1 MUX
├── chaotic_only_r/            # Baseline: Pure chaotic oscillator stream
├── mux+clfsr/                 # Architectural predecessor (MUX + CLFSR)
├── sampled clock trng MUX/    # Sampled clock oscillator testbed
├── puf_trng_architecture.html # Interactive visualizer for PUF + TRNG System
├── run_nist_tests.py          # Python evaluation script for NIST SP 800-22
├── run_nist_90b_tests.py      # Python evaluation script for NIST SP 800-90B
├── run_paper_tests.py         # Comparative benchmark script against literature
└── run_advanced_trng_tests.py # Advanced autocorrelation, entropy & FFT tests
```

---

## 🚀 Running Verification & Tests

To execute statistical tests on the included hardware-captured bitstreams:

```bash
# Run NIST SP 800-22 suite
python run_nist_tests.py

# Run NIST SP 800-90B min-entropy evaluation
python run_nist_90b_tests.py

# Run advanced entropy, autocorrelation and FFT tests
python run_advanced_trng_tests.py
```

---

## 🛠️ Hardware Requirements
- **FPGA:** Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
- **Toolchain:** AMD Vivado Design Suite 2020.1+
- **Host Interface:** USB-UART Bridge (`115200 8N1`)
