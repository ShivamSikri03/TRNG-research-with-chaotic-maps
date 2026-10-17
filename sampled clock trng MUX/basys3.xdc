## ============================================================================
## Basys 3 Master XDC Constraints
## Design: Sampled Clock TRNG MUX (RO_3, RO_5, RO_7, RO_9) + UART TX
## Target Board: Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
## Directory: sampled clock trng MUX/basys3.xdc
## ============================================================================

## ---------- 1. Clock Signal (100 MHz Onboard Crystal Oscillator) ----------
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

## ---------- 2. Reset Button (Center Pushbutton BTNC - Active High) ----------
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst]

## ---------- 3. Enable Switch (Slide Switch SW0 - 1=Run, 0=Pause) ----------
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports enable]

## ---------- 4. USB-UART TX Pin (Serial Data Stream to PC @ 115200 Baud) ----------
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_out]

## ---------- 5. Status & Diagnostic LEDs (LED[7:0]) ----------
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

## ============================================================================
## 6. Vivado Configuration Voltage Standards
## ============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ============================================================================
## 7. Ring Oscillators: Allow Intentional Combinatorial Feedback Loops
## ============================================================================
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *ro_3_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *ro_5_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *ro_7_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *ro_9_inst*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *selected_ro*}]

## ============================================================================
## 8. Timing Constraints: Set False Paths for Asynchronous Oscillators
## ============================================================================
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *ro_3_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *ro_5_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *ro_7_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *ro_9_inst*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *selected_ro*}]

## ============================================================================
## 9. Prevent Logic Trimming on Oscillators and Synchronizers
## ============================================================================
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *ro_3_inst*}]
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *ro_5_inst*}]
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *ro_7_inst*}]
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *ro_9_inst*}]
set_property DONT_TOUCH TRUE [get_cells -hierarchical -filter {NAME =~ *u_trng_core*}]

## ============================================================================
## 10. Bitstream Optimization Settings for Basys 3 SPI Flash
## ============================================================================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
