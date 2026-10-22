# Design and Implementation of UART Transceiver using Verilog HDL

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog%202001-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![FPGA Compatible](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7%20%7C%20Basys%203-orange.svg)](https://www.xilinx.com)
[![Protocol](https://img.shields.io/badge/Protocol-UART%208--N--1-success.svg)](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
[![Simulation Coverage](https://img.shields.io/badge/Verification-100%25%20Bit--Accurate-brightgreen.svg)](sim/uart_sim.py)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-performance, synthesizable, and parameterized **Universal Asynchronous Receiver-Transmitter (UART)** core implemented in Verilog HDL. The core provides full-duplex serial communication over standard 8-N-1 protocol framing, featuring dual-stage metastability synchronizers, midpoint eye-diagram sampling, and noise glitch rejection.

---

## Architecture Overview

```
                      ┌────────────────────────────────────────────────────────┐
                      │                       uart_top                         │
                      │                                                        │
                      │  ┌───────────────────────┐   rs232_tx                  │
       start ─────────┼─►│        uart_tx        ├─────────────► TX Serial Line│
       data[7:0] ─────┼─►│  (Serializer / FSM)   │                             │
                      │  │                       │   tx_done                   │
                      │  │ BAUD_DIV Rate Counter ├─────────────► Done Flag     │
                      │  └───────────────────────┘                             │
                      │                                                        │
                      │  ┌───────────────────────┐                             │
                      │  │        uart_rx        │                             │
                      │  │  (2-Stage Dual Sync)  │   rx_data[7:0]              │
   RX Serial Line ────┼─►│           ▼           ├─────────────► Parallel Data │
    (rs232_in)        │  │ Midpoint Eye Sampler  │                             │
                      │  │           ▼           │   rx_done                   │
                      │  │ Noise Glitch Filter   ├─────────────► Done Flag     │
                      │  └───────────────────────┘                             │
                      │                                                        │
                      └────────────────────────────────────────────────────────┘
```

### Key Technical Features
1. **Parameterized Baud Rate Divisor (`BAUD_DIV`)**:
   Adjusts effortlessly between ultra-fast simulation (`BAUD_DIV = 30`) and physical FPGA clock speeds (e.g., `BAUD_DIV = 868` for 100 MHz clock @ 115,200 baud).
2. **Dual-Stage Flip-Flop Synchronizer**:
   Isolates the internal synchronous logic from external asynchronous line metastability, ensuring high Mean Time Between Failures ($MTBF$).
3. **Midpoint Eye-Diagram Sampling**:
   Samples incoming serial bits at the center of each bit period ($\frac{T_{\text{bit}}}{2}$), maximizing tolerance against phase jitter and edge distortion.
4. **Sub-Bit Noise Glitch Filter**:
   Re-evaluates the line at the midpoint of the start bit. If line noise caused a transient spike, the frame is discarded immediately without corrupting internal state.
5. **Full-Duplex Operation**:
   Simultaneous independent transmission and reception with separate status flags (`tx_done` and `rx_done`).

---

## Detailed Module Breakdown

### 1. UART Top Module (`src/uart_top.v`)
- **Role**: Integrates the transmitter and receiver modules into a clean, unified transceiver interface.
- **Parameters**: `BAUD_DIV` (default: `13'd30`).
- **Ports**:
  - `clk`, `rst_n`: System clock and active-low reset.
  - `start`: 1-cycle pulse initiating transmission.
  - `data[7:0]`: 8-bit parallel data word to transmit.
  - `rs232_in`: Asynchronous serial receive line.
  - `rs232_tx`: Serial transmit output.
  - `rx_data[7:0]`: 8-bit received parallel data word.
  - `tx_done`, `rx_done`: 1-cycle completion strobes.

### 2. UART Transmitter (`src/uart_tx.v`)
- **Protocol Sequence**:
  - **Idle State**: Transmit line remains HIGH (`1`).
  - **Start Bit**: Drives line LOW (`0`) for 1 bit period.
  - **Data Bits**: Transmits 8 data bits serially, **LSB first** ($D_0 \rightarrow D_7$).
  - **Stop Bit**: Drives line HIGH (`1`) for 1 bit period.
  - **Completion**: Asserts `done` flag and resets to IDLE.

```
       Start    D0     D1     D2     D3     D4     D5     D6     D7    Stop
Line: ───┐      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐      ┌───
         │ (0)  │ (LSB)│      │      │      │      │      │      │ (MSB)│ (1)  │
         └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

### 3. UART Receiver (`src/uart_rx.v`)
- **Synchronization**: Routes incoming `rs232` through two cascaded D-flip-flops (`sync[1:0]`).
- **Start Detection**: Detects a synchronized falling edge (`sync[1] == 0`) while in IDLE state.
- **Center Sampling**: Samples data at `baud_cnt == BAUD_DIV / 2`:
  - `bit_cnt == 0`: Start bit validation (glitch filter).
  - `bit_cnt == 1..8`: Deserializes serial bits into `rx_data` (LSB first).
  - `bit_cnt == 9`: Validates stop bit and asserts `done <= 1`.

### 4. Self-Checking Testbench (`src/tb_uart.v`)
- Sets up a loopback channel connecting `rs232_tx` directly to `rs232_in`.
- Exercises multiple test vectors (`0x55`, `0x58`, `0xAA`, `0x00`, `0xFF`, `0xA5`, `0x3C`).
- Compares received bytes against sent bytes automatically, logging `[PASS]` or `[FAIL]`.
- Generates VCD waveform dumps (`tb_uart.vcd`) for visual inspection in GTKWave or ModelSim.

---

## Experimental Simulation Results

The core has been thoroughly simulated and verified with timing waveforms:

### 1. UART Transmitter Waveform (`0x58` = `8'b01011000`)
![image](https://github.com/user-attachments/assets/9ce8267d-9c21-4b7c-a300-df494ef17298)

- **Annotation**:
  - Start Bit = `0`
  - Data Bits LSB-first = `0, 0, 0, 1, 1, 0, 1, 0`
  - Stop Bit = `1`
  - Total frame duration = $10 \times 30$ clock ticks.

### 2. UART Receiver Waveform (`0x55` = `8'b01010101`)
![image](https://github.com/user-attachments/assets/7227766c-dea9-4c29-a927-d0bf4ab446d6)

- **Annotation**:
  - Demonstrates accurate midpoint sampling of alternating bit pattern `8'h55`.
  - The dual-stage synchronizer cleanly aligns the asynchronous serial stream to the internal clock domain without timing violations.

---

## Baud Rate Configuration Guide

To deploy this core on an FPGA board, calculate the integer divisor using the formula:

$$\text{BAUD\_DIV} = \frac{f_{\text{clk}}}{\text{Baud Rate}}$$

| Board | System Clock ($f_{\text{clk}}$) | Target Baud Rate | Parameter Setting | Actual Baud | Error |
|:------|:-------------------------------:|:----------------:|:-----------------:|:-----------:|:-----:|
| **Digilent Arty A7-100T** | 100 MHz | 115,200 bps | `BAUD_DIV = 868` | 115,207 bps | +0.006% |
| **Digilent Arty A7-100T** | 100 MHz | 9,600 bps | `BAUD_DIV = 10417` | 9,599.7 bps | -0.003% |
| **Digilent Basys 3** | 100 MHz | 115,200 bps | `BAUD_DIV = 868` | 115,207 bps | +0.006% |
| **Custom / Dev Kit** | 50 MHz | 115,200 bps | `BAUD_DIV = 434` | 115,207 bps | +0.006% |
| **Fast Simulation** | Any | N/A | `BAUD_DIV = 30` | 30 ticks/bit | 0.000% |

---

## Verification & How to Run

### 1. Standalone Python Verification (No EDA Tools Required)
A cycle-accurate bit-level Python model is included in `sim/uart_sim.py`:
```bash
python sim/uart_sim.py
```
**Output:**
```text
====================================================================
  UART GOLDEN SIMULATION AND SELF-CHECKING VERIFICATION SUITE
====================================================================
 [PASS] Transmitted: 0x55 | Received: 0x55 | Alternating 01010101
 [PASS] Transmitted: 0x58 | Received: 0x58 | README Figure Vector (01011000)
 [PASS] Transmitted: 0xAA | Received: 0xAA | Inverted Alternating 10101010
 [PASS] Transmitted: 0x00 | Received: 0x00 | All Zeros (00000000)
 [PASS] Transmitted: 0xFF | Received: 0xFF | All Ones (11111111)
 [PASS] Transmitted: 0xA5 | Received: 0xA5 | Checkerboard A5 (10100101)
 [PASS] Transmitted: 0x5A | Received: 0x5A | Checkerboard 5A (01011010)
 [PASS] Transmitted: 0x3C | Received: 0x3C | Nibble Pattern (00111100)
 [PASS] Transmitted: 0xC3 | Received: 0xC3 | Nibble Pattern (11000011)
--------------------------------------------------------------------
 Testing Noise Glitch Filter (< HALF_BAUD low pulse)...
 [PASS] Sub-bit glitch filtered out cleanly. RX stayed in IDLE.
====================================================================
 RESULT: ALL TESTS PASSED WITH 100% BIT ACCURACY!
====================================================================
```

### 2. Verilog Simulation with Icarus Verilog + GTKWave
```bash
iverilog -o uart_sim.vvp src/uart_top.v src/uart_tx.v src/uart_rx.v src/tb_uart.v
vvp uart_sim.vvp
gtkwave tb_uart.vcd
```

### 3. Simulation in ModelSim / QuestaSim
```tcl
vlib work
vlog src/*.v
vsim tb_uart
add wave -r /*
run -all
```

---

## FPGA Implementation (Vivado & Arty A7)

1. Open Vivado and create a new RTL project.
2. Select target FPGA: `xc7a100tcsg324-1` (or your board's part number).
3. Add source files:
   - `src/uart_top.v`
   - `src/uart_tx.v`
   - `src/uart_rx.v`
4. Add constraints: `fpga/arty_a7_uart.xdc`.
5. Set top module parameter `BAUD_DIV = 868` for 100 MHz clock @ 115,200 baud.
6. Run **Synthesis** $\rightarrow$ **Implementation** $\rightarrow$ **Generate Bitstream**.

---

## Directory Structure

```
Design-and-Implementaion-of-UART-using-Verilog/
├── fpga/
│   └── arty_a7_uart.xdc       # Xilinx Vivado pin constraints for Arty A7-100T
├── sim/
│   └── uart_sim.py            # Python cycle-accurate golden simulator & test suite
├── src/
│   ├── uart_top.v             # Parameterized top-level transceiver module
│   ├── uart_tx.v              # Serial transmitter FSM (8-N-1)
│   ├── uart_rx.v              # Serial receiver with 2-FF sync & midpoint sampling
│   └── tb_uart.v              # Self-checking automated loopback testbench
├── PROJECT_OVERVIEW.md        # In-depth architectural & mathematical documentation
├── README.md                  # Project overview, waveforms, and usage guide
└── LICENSE                    # MIT License
```

---

## References & Further Reading
- *Pong P. Chu*, **FPGA Prototyping by Verilog Examples**, Chapter 7: UART Transceiver.
- *EIA/TIA-232-F Standard*, Interface Between Data Terminal Equipment and Data Circuit-Terminating Equipment.
- *Xilinx Vivado Design Suite 7 Series FPGAs Packaging and Pinout Specification*.
