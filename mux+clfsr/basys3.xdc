## ============================================================================
## Basys 3 Constraints for CLFSR + MUX Hybrid TRNG with UART
## Board: Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C)
##
## Architecture: RO(8) + CLFSR + RO(5) + RO(3) → 4x1 Chaotic MUX
## FIRO (RO_16) replaced by clfsr_trng_single
## ============================================================================

## ---------- Clock (100 MHz onboard oscillator) ----------
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## ---------- Reset (BTNC - Center button, active high) ----------
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports rst]

## ---------- Enable (SW0 - leftmost switch) ----------
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports enable]

## ---------- UART TX (USB-UART on Basys 3) ----------
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports uart_out]

## ============================================================================
## CFGBVS and CONFIG_VOLTAGE (required for Basys 3)
## ============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ============================================================================
## Ring Oscillator: Allow combinational loops (intentional for TRNG)
## ============================================================================
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *RO_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *RO_5_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *RO_3_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *mux_out*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *sel*}]

## ============================================================================
## Timing: Tell Vivado the ring oscillators are asynchronous
## ============================================================================
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *RO_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *RO_5_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *RO_3_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *mux_out*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *sel*}]

## ============================================================================
## CLFSR: Synchronous design, no special constraints needed
## (It runs on sys_clk, Vivado handles timing automatically)
## ============================================================================
