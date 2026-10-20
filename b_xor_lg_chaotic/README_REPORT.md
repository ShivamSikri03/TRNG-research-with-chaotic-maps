# Technical Report: Multi-Oscillator B-XOR-LG + Standalone Chaotic 1-Bit XOR TRNG (No LFSR)

**Target Device:** Xilinx Artix-7 XC7A35T-1CPG236C (Digilent Basys 3)  
**System Clock:** 100 MHz (10.00 ns period)  
**Communication Port:** USB-UART (Pin A18) @ 115,200 Baud (8N1 ASCII)  
**Evaluation Standards:** NIST SP 800-22 Rev 1a  
**Primary Outcome:** **12 / 15 NIST SP 800-22 Tests Passed (80% Pass Rate)**  

---

## 1. Executive Summary

This report documents the architectural design, Verilog HDL implementation, physical FPGA constraints, and empirical validation of the **`b_xor_lg_chaotic`** True Random Number Generator (TRNG). This design integrates:
1. **Asynchronous Entropy Source Bank:** Three free-running ring oscillators of prime/odd inverter stage lengths (**RO_3**, **RO_5**, **RO** [7-stage]) and a chaotic cross-coupled inverter ring (**FIRO_main**).
2. **Balanced XOR Logic Gate (B-XOR-LG):** A 2-stage cross-coupled XOR network that continuously mixes all four oscillators simultaneously without select lines.
3. **Dual-Rank Synchronizer:** A two-stage D-Flip-Flop chain (`u_dff_sync1`, `u_dff_sync2`) that samples the high-frequency jittered B-XOR-LG signal into the 100 MHz system clock domain.
4. **Standalone 5-Stage Chebyshev Chaotic Core (No LFSR):** Implements the 2nd-order Chebyshev map ($X_{n+1} = 1 - 2X_n^2$) in signed Q1.15 fixed-point arithmetic across five pipeline registers, generating bit 10 of the chaotic attractor state: `chaotic_bit = x[10]`.
5. **Real-Time Bitwise XOR Fusion:** Single-cycle bitwise XOR (`chaotic_bit ^ trng_sampled_bit`) acting as a real-time cryptographic whitener.

Under testing on **1,142,073 hardware-generated bits** captured via serial terminal (`results/putty.txt`), the generator achieved a **12/15 PASS rate** on the NIST SP 800-22 Rev 1a statistical test suite.

---

## 2. Directory Structure

```
b_xor_lg_chaotic/
├── code/                      # Verilog HDL source modules & constraints
├── result analysis/           # Python test & statistical evaluation scripts
├── results/                   # Empirical logs, data captures & reports
├── README_REPORT.md           # This engineering report
├── .gitignore                 # Build artifact ignore list
└── README.md                  # Complete architecture overview
```
