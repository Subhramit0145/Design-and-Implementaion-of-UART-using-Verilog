## =============================================================================
## XDC Constraints File: Digilent Arty A7-100T (XC7A100TCSG324-1)
## Target Design: Parameterized UART Transceiver
## =============================================================================

## Clock Signal (100 MHz onboard oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Active-Low Reset (Button btn[0] or Dedicated CPU_RESETN Pin C2)
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## USB-UART Interface (On-board FTDI Bridge)
## Note: UART RX on FPGA connects to TX of FTDI (Pin A9)
## Note: UART TX on FPGA connects to RX of FTDI (Pin D10)
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { rs232_in }];
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { rs232_tx }];

## Start Transmission Trigger (Push Button btn[0] on Arty)
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { start }];

## 8-bit Data Input (Slide Switches + Extended Header or Internal Register)
## Example mapping to Slide Switches sw[3:0] and Header pins
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { data[0] }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { data[1] }];
set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { data[2] }];
set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { data[3] }];

## Status LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { tx_done }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { rx_done }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { rx_data[0] }];
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { rx_data[1] }];
