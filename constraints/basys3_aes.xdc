## basys3_aes.xdc - Pin Constraints for AES-128 FPGA Accelerator
## Target: Xilinx Artix-7 XC7A35TCPG236-1 (Basys 3)
## Generated: April 29, 2026
## 
## Configuration:
## - System Clock: 100 MHz
## - Control Inputs: 8 switches (enc_dec mode and operation control)
## - Status Outputs: 8 LEDs (done and result indication)
## - Optional: 7-segment display for operation status

####################
## Clock Signal
####################
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

####################
## Reset Signal
####################
## Active-low reset connected to dedicated reset pin or button
## Uncomment to use button or switch as reset
# set_property PACKAGE_PIN U18 [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

####################
## Control Inputs (Switches)
####################
## 8 switches for:
## - swt[0]: start signal or mode selector
## - swt[1-7]: Control bits or configuration

# Switches commented out — using USB serial only for HIL
# set_property PACKAGE_PIN V17 [get_ports {swt[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[0]}]

# set_property PACKAGE_PIN V16 [get_ports {swt[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[1]}]

# set_property PACKAGE_PIN W16 [get_ports {swt[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[2]}]

# set_property PACKAGE_PIN W17 [get_ports {swt[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[3]}]

# set_property PACKAGE_PIN W15 [get_ports {swt[4]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[4]}]

# set_property PACKAGE_PIN V15 [get_ports {swt[5]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[5]}]

# set_property PACKAGE_PIN W14 [get_ports {swt[6]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[6]}]

# set_property PACKAGE_PIN W13 [get_ports {swt[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {swt[7]}]

####################
## Status Outputs (LEDs)
####################
## 8 LEDs for:
## - led[0]: done signal indication
## - led[1-7]: Output ciphertext/plaintext byte display (low 7 bits)

# LEDs commented out — using USB serial only for HIL
# set_property PACKAGE_PIN U16 [get_ports {led[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

# set_property PACKAGE_PIN E19 [get_ports {led[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# set_property PACKAGE_PIN U19 [get_ports {led[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

# set_property PACKAGE_PIN V19 [get_ports {led[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# set_property PACKAGE_PIN W18 [get_ports {led[4]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

# set_property PACKAGE_PIN U15 [get_ports {led[5]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]

# set_property PACKAGE_PIN U14 [get_ports {led[6]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]

# set_property PACKAGE_PIN V14 [get_ports {led[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

####################
## 7-Segment Display (Optional)
####################
## For displaying operation mode, round counter, or result bytes
## 7-segment pins are intentionally left commented — HIL uses USB serial

# set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
# 
# set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
# 
# set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
# 
# set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
# 
# set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
# 
# set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
# 
# set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]
# 
# ## Decimal point
# set_property PACKAGE_PIN V7 [get_ports dp]
# set_property IOSTANDARD LVCMOS33 [get_ports dp]
# 
# ## Anode select lines (active low)
# set_property PACKAGE_PIN U2 [get_ports {an[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
# 
# set_property PACKAGE_PIN U4 [get_ports {an[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
# 
# set_property PACKAGE_PIN V4 [get_ports {an[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
# 
# set_property PACKAGE_PIN W4 [get_ports {an[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

####################
## Pushbuttons (Optional)
####################
## Buttons left commented — using USB serial commands for control

# ## Center Button
# set_property PACKAGE_PIN U18 [get_ports btnC]
# set_property IOSTANDARD LVCMOS33 [get_ports btnC]
# 
# ## Up Button
# set_property PACKAGE_PIN T18 [get_ports btnU]
# set_property IOSTANDARD LVCMOS33 [get_ports btnU]
# 
# ## Left Button
# set_property PACKAGE_PIN W19 [get_ports btnL]
# set_property IOSTANDARD LVCMOS33 [get_ports btnL]
# 
# ## Right Button
# set_property PACKAGE_PIN T17 [get_ports btnR]
# set_property IOSTANDARD LVCMOS33 [get_ports btnR]
# 
# ## Down Button
# set_property PACKAGE_PIN U17 [get_ports btnD]
# set_property IOSTANDARD LVCMOS33 [get_ports btnD]

####################
## Pmod Headers (Optional)
####################
## Pmod I/O left commented for now

# ## Pmod Header JA (8 pins)
# set_property PACKAGE_PIN J1 [get_ports {JA[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {JA[0]}]
# 
# set_property PACKAGE_PIN L2 [get_ports {JA[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {JA[1]}]
# 
# set_property PACKAGE_PIN J2 [get_ports {JA[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {JA[2]}]
# 
# set_property PACKAGE_PIN G2 [get_ports {JA[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {JA[3]}]

####################
## USB-RS232 Interface (Optional)
####################
## If using dedicated RS232 pins, uncomment below. For Basys3 the
## USB-UART bridge is preferred; use host-side USB serial device.

# ## RS232 Receive (from computer to FPGA)
# set_property PACKAGE_PIN B18 [get_ports RsRx]
# set_property IOSTANDARD LVCMOS33 [get_ports RsRx]
# 
# ## RS232 Transmit (from FPGA to computer)
# set_property PACKAGE_PIN A18 [get_ports RsTx]
# set_property IOSTANDARD LVCMOS33 [get_ports RsTx]

####################
## Timing Constraints
####################
## All paths must complete within one clock cycle
## Critical path: Datapath multiplexer + transformation logic
## Setup time: 2.0 ns (15% margin at 100 MHz)

set_property INTERNAL_VREF 0.75 [get_iobanks 14]
set_property INTERNAL_VREF 0.75 [get_iobanks 15]
set_property INTERNAL_VREF 0.75 [get_iobanks 16]
set_property INTERNAL_VREF 0.75 [get_iobanks 34]
set_property INTERNAL_VREF 0.75 [get_iobanks 35]

####################
## End of Constraints File
####################
