## This file is a general .xdc for the Basys3 rev B board (AES HIL top)
## Project-specific top level in use: aes_hil_top
## Active ports in this project:
## - clk
## - rst
## - rx, tx (USB UART)
## - led_status[15:0]

## Clock signal
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button used by this design
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## USB UART Interface (active in this design)
## RX: data from host PC to FPGA
set_property PACKAGE_PIN A9 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

## TX: data from FPGA to host PC
set_property PACKAGE_PIN B10 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

## LEDs (all 16 used for status indication)
set_property PACKAGE_PIN U16 [get_ports {led_status[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[0]}]
set_property PACKAGE_PIN E19 [get_ports {led_status[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[1]}]
set_property PACKAGE_PIN U19 [get_ports {led_status[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[2]}]
set_property PACKAGE_PIN V19 [get_ports {led_status[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[3]}]
set_property PACKAGE_PIN W18 [get_ports {led_status[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[4]}]
set_property PACKAGE_PIN U15 [get_ports {led_status[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[5]}]
set_property PACKAGE_PIN U14 [get_ports {led_status[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[6]}]
set_property PACKAGE_PIN V14 [get_ports {led_status[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[7]}]
set_property PACKAGE_PIN V13 [get_ports {led_status[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[8]}]
set_property PACKAGE_PIN V3 [get_ports {led_status[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[9]}]
set_property PACKAGE_PIN W3 [get_ports {led_status[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[10]}]
set_property PACKAGE_PIN U3 [get_ports {led_status[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[11]}]
set_property PACKAGE_PIN P3 [get_ports {led_status[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[12]}]
set_property PACKAGE_PIN N3 [get_ports {led_status[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[13]}]
set_property PACKAGE_PIN P1 [get_ports {led_status[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[14]}]
set_property PACKAGE_PIN L1 [get_ports {led_status[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_status[15]}]
