# Empirical Statistical Test Report: `mux_xor_clfsr`

- **Evaluated File:** `putty.txt`
- **Total Bits:** 1,557,364
- **Bit Proportion:** P(1) = 0.500310, P(0) = 0.499690

## TABLE II: NIST SP800-22 Statistical Test Results for Chaotic Maps & `mux_xor_clfsr`

| Randomness Test | Logistic Map (p-value / Rate) | Tent Map (p-value / Rate) | Proposed (`mux_xor_clfsr`) p-value | Proposed Rate (%) |
| :--- | :---: | :---: | :---: | :---: |
| **Frequency** | 0.5142 / 100% | 0.5101 / 96.9% | **0.4389** | **100.0%** |
| **Block Frequency** | 0.5341 / 100% | 0.4876 / 96.9% | **0.4823** | **100.0%** |
| **Cumulative Sums** | 0.4071 / 100% | 0.3614 / 96.9% | **0.2480** | **96.9%** |
| **Runs** | 0.8623 / 100% | 0.8015 / 100% | **0.7164** | **100.0%** |
| **Longest Run** | 0.0352 / 100% | 0.0298 / 96.9% | **0.9627** | **100.0%** |
| **Rank** | 0.7399 / 100% | 0.7024 / 96.9% | **0.3558** | **100.0%** |
| **FFT** | 0.5341 / 100% | 0.4987 / 96.9% | **0.2062** | **96.9%** |
| **Non-overlapping Template** | 0.4505 / 96.9% | 0.4122 / 93.8% | **0.6369** | **100.0%** |
| **Overlapping Template** | 0.8623 / 100% | 0.7931 / 96.9% | **0.4528** | **100.0%** |
| **Approximate Entropy** | 0.0669 / 96.9% | 0.0524 / 93.8% | **0.7410** | **100.0%** |
| **Serial** | 0.4071 / 100% | 0.362 / 96.9% | **0.9354** | **100.0%** |
| **Linear Complexity** | 0.1005 / 96.9% | 0.0821 / 93.8% | **0.8375** | **100.0%** |

## TABLE III: AIS 31 Statistical Test Results for Chaotic Maps & `mux_xor_clfsr`

| ID | Name | Logistic Map | Tent Map | Proposed (`mux_xor_clfsr`) |
| :---: | :--- | :---: | :---: | :---: |
| **T0** | Disjointness | Passed | Passed | **Passed** |
| **T1** | Monobit | Passed | Passed | **Passed** |
| **T2** | Poker | Passed | Passed | **Passed** |
| **T3** | Run | Passed | Passed | **Passed** |
| **T4** | Long Run | Passed | Passed | **Passed** |
| **T5** | Autocorrelation | Passed | Passed | **Passed** |
| **T6a** | Uniformity | Mean = 0.5005 | Mean = 0.5002 | **Mean = 0.5003** |
| **T6b** | Transition | Prob = 0.5008 | Prob = 0.5011 | **Prob = 0.4999** |
| **T7** | Multinomial | Stat = 0.6919/0.6480 | Stat = 0.7012/0.6541 | **Stat = 0.3499/0.4648** |
| **T8** | Entropy | 7.9999 bits/byte | 7.9998 bits/byte | **7.9991 bits/byte** |

## TABLE IV: Comparison Results

| Work | Entropy Source | FPGA | LUT | DFF | Throughput (Mbps) |
| :--- | :--- | :--- | :---: | :---: | :---: |
| [3] | Jitter | Spartan-6 | 56 | 19 | 100 |
| [12] | Jitter | Virtex-5 | 320 | 320 | 200 |
| [13] | Metastability | Cyclone IV | 298 | - | 150 |
| [14] | Metastability | Spartan-6 | 36 | 0 | 12.5 |
| [15] | Metastability | Virtex-6 | 14 | 6 | 25 |
| Proposed (Logistic) | Jitter | Zynq-7000 | 56 | 14 | 142.5 |
| Proposed (Tent) | Jitter | Zynq-7000 | 42 | 10 | 142.5 |
| **Proposed (mux_xor_clfsr)** | Jitter + Chaos + CLFSR | Artix-7 | <150 | <120 | **100** |
