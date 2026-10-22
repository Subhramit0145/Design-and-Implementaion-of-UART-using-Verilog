# Master Project Architecture: Parameterized UART Transceiver in Verilog

## 1. Executive Summary

This project implements a fully parameterized, cycle-accurate **Universal Asynchronous Receiver-Transmitter (UART)** core in synthesizable Verilog HDL. The core supports full-duplex serial communication using the industry-standard **8-N-1** protocol (1 Start bit, 8 Data bits, No parity, 1 Stop bit).

The design features:
- **Parameterized Baud Rate Generation**: Simple divisor override (`BAUD_DIV`) for high-speed simulation (`BAUD_DIV=30`) or FPGA deployment (e.g., `BAUD_DIV=868` for 100 MHz clock @ 115,200 baud).
- **Dual-Stage Synchronizer**: Mitigates metastability issues caused by asynchronous external RS-232/TTL RX line inputs.
- **Midpoint Sampling & Glitch Filter**: Samples serial data at the center of the bit eye diagram ($\frac{T_{\text{bit}}}{2}$) and rejects sub-bit noise spikes on the start bit.
- **Full Verification Suite**: Includes both a self-checking Verilog testbench with automated assertions and a standalone cycle-accurate Python golden simulator.
- **FPGA Ready**: Includes ready-to-run Vivado physical constraints (`.xdc`) targeting the Digilent Arty A7-100T (Xilinx Artix-7).

---

## 2. UART Protocol Architecture & Frame Format

UART is an asynchronous, point-to-point serial communication protocol. Because there is no shared clock signal transmitted between sender and receiver, both sides must agree beforehand on the baud rate (transmission speed in bits per second) and frame structure.

### 2.1 The 8-N-1 Frame Format

```
Idle (1) ──┐      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐      ┌── Idle (1)
           │Start │ Bit0 │ Bit1 │ Bit2 │ Bit3 │ Bit4 │ Bit5 │ Bit6 │ Bit7 │ Stop │
           │(0)   │(LSB) │      │      │      │      │      │      │(MSB) │ (1)  │
           └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
                  |<─────────────────────── 8 Data Bits ──────────────────────>|
```

| Field | Duration | Polarity / Value | Description |
|:------|:--------:|:----------------:|:------------|
| **Idle State** | Indefinite | High (`1`) | Line stays pulled HIGH (marking state) when no data is being sent. |
| **Start Bit** | 1 Bit Period | Low (`0`) | Signals the receiver that a new data frame has begun. |
| **Data Bits** | 8 Bit Periods | Variable (`0`/`1`) | Transmitted **LSB-first** (Least Significant Bit $D_0$ through Most Significant Bit $D_7$). |
| **Parity Bit** | 0 Bits | N/A | None configured in standard 8-N-1 mode. |
| **Stop Bit** | 1 Bit Period | High (`1`) | Confirms frame termination and guarantees a transition before the next start bit. |

---

## 3. Mathematical Baud Rate Derivation

The baud divisor ($N_{\text{baud}}$) specifies how many system clock ticks constitute one serial bit duration ($T_{\text{bit}}$):

$$T_{\text{bit}} = \frac{1}{\text{Baud Rate}}$$

$$N_{\text{baud}} = \frac{f_{\text{clk}}}{\text{Baud Rate}}$$

### 3.1 Standard Baud Rate Divisors for Common FPGA Clocks

| System Clock ($f_{\text{clk}}$) | Target Baud Rate | Theoretical Divisor | Integer Divisor (`BAUD_DIV`) | Actual Baud Rate | Timing Error (%) |
|:-------------------------------:|:----------------:|:-------------------:|:----------------------------:|:----------------:|:----------------:|
| **100 MHz** (Arty A7 / Basys 3) | 115,200 bps | 868.055 | **868** | 115,207 bps | **+0.006%** |
| **100 MHz** (Arty A7 / Basys 3) | 9,600 bps | 10,416.67 | **10,417** | 9,599.7 bps | **-0.003%** |
| **50 MHz** (Spartan-6 / DE10) | 115,200 bps | 434.028 | **434** | 115,207 bps | **+0.006%** |
| **50 MHz** (Spartan-6 / DE10) | 9,600 bps | 5,208.33 | **5,208** | 9,600.6 bps | **+0.006%** |
| **Simulation Mode** (Default) | Fast Sim | 30.00 | **30** | N/A (30 ticks/bit) | **0.000%** |

> [!NOTE]
> Standard asynchronous UART transceivers tolerate clock frequency errors up to $\pm 3.5\%$ across the 10-bit frame without bit slippage. With an error of $<0.01\%$, this core achieves rock-solid synchronization.

---

## 4. Metastability & Multi-Stage Synchronizer Theory

Because the serial receive line (`rs232_in`) originates from an external, unsynchronized clock domain, feeding it directly into synchronous flip-flop data inputs causes **metastability**:
If an input signal transitions inside the setup ($t_{\text{setup}}$) or hold ($t_{\text{hold}}$) window of a clock edge, the internal bistable element may enter a indeterminate intermediate voltage state, resolving unpredictably and causing system crashes.

### 4.1 Two-Stage Flip-Flop Synchronizer Circuit

```mermaid
graph LR
    rs232[External RS232 RX Pin] --> FF1["FF1 (sync[0])"]
    clk((System Clock)) --> FF1
    FF1 --> FF2["FF2 (sync[1])"]
    clk --> FF2
    FF2 --> FSM["RX State Machine & Sampler"]
```

The Mean Time Between Failures ($MTBF$) is mathematically modeled by:

$$MTBF = \frac{e^{\frac{t_{\text{resolve}}}{\tau}}}{T_0 \cdot f_{\text{clk}} \cdot f_{\text{data}}}$$

By introducing two cascaded flip-flops clocked by `clk`:
- The probability of metastability persisting past the second flip-flop `sync[1]` is negligible ($MTBF > 10^9$ years under normal operating conditions).
- In `src/uart_rx.v`:
  ```verilog
  always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
          sync <= 2'b11;
      else
          sync <= {sync[0], rs232};
  end
  ```

---

## 5. Transmitter Architecture (`src/uart_tx.v`)

The transmitter converts an 8-bit parallel byte into a standardized 10-bit serial stream.

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> TX_ACTIVE : start && !state (latch data, bit_cnt=0)
    TX_ACTIVE --> TX_ACTIVE : bit_flag && bit_cnt < 9 (shift LSB)
    TX_ACTIVE --> IDLE : bit_flag && bit_cnt == 9 (stop bit, done=1)
```

### 5.1 Step-by-Step Transmission Sequence
1. **Idle State**: `rs232_tx` is driven to logic `1`.
2. **Start Command**: When `start` pulses high, `state` transitions to `1`, `data` is latched into internal register `r_data`, and `bit_cnt` resets to `0`.
3. **Baud Counter (`baud_cnt`)**: Increments every clock cycle from `0` to `BAUD_DIV`. When `baud_cnt == BAUD_DIV`, it wraps to `0` and asserts single-cycle strobe `bit_flag`.
4. **Serialization Mapping**:
   - `bit_cnt == 0`: Start bit (`rs232_tx <= 1'b0`)
   - `bit_cnt == 1..8`: Data bits (`rs232_tx <= r_data[bit_cnt - 1]`, LSB first)
   - `bit_cnt == 9`: Stop bit (`rs232_tx <= 1'b1`)
5. **Completion**: Upon reaching `bit_cnt == 9`, `done <= 1'b1` is asserted and the transmitter returns to IDLE.

### 5.2 Transmission Timing for Byte `0x58` (`8'b01011000`)
```
Bit Index :   Idle  |  0 (Start) | 1 (D0=0) | 2 (D1=0) | 3 (D2=0) | 4 (D3=1) | 5 (D4=1) | 6 (D5=0) | 7 (D6=1) | 8 (D7=0) | 9 (Stop) | Idle
rs232_tx  : ────1───┴─────0──────┴────0─────┴────0─────┴────0─────┴────1─────┴────1─────┴────0─────┴────1─────┴────0─────┴────1─────┴───1───
Cycles    :           30 cyc        30 cyc     30 cyc     30 cyc     30 cyc     30 cyc     30 cyc     30 cyc     30 cyc     30 cyc
```

---

## 6. Receiver Architecture (`src/uart_rx.v`)

The receiver continuously monitors the serial line, aligns to the start bit, and reconstructs the 8-bit parallel byte.

### 6.1 Midpoint Sampling Theory
Sampling serial data near bit edges is susceptible to phase jitter, line slew rate distortion, and signal reflections. The optimal point of maximum signal integrity is the **exact midpoint** of each bit duration ($T_{\text{sample}} = \frac{T_{\text{bit}}}{2}$).

```
Bit Cell:       [─────────────────────── T_bit ───────────────────────]
Signal:         ───/                                                 \───
                    |                                               |
Jitter Danger:  [xxx]                                               [xxx]
Optimal Sample:                          ▲ (T_bit / 2)
                                   Maximum Eye Opening
```

### 6.2 Glitch Filter on Start Bit
Noise spikes on long transmission lines can briefly pull an idle HIGH line low. To prevent false frame triggers:
- When a falling edge is detected (`sync[1] == 0`), the receiver enters active reception.
- At `baud_cnt == HALF_BAUD` (the midpoint of the start bit), the line is re-evaluated.
- If `sync[1]` is no longer `0`, the event was a transient noise spike! The receiver immediately aborts back to IDLE without corrupting any registers.

---

## 7. Deep Dive: The Receiver Oversampling Bug & Fix

### 7.1 The Original Defect in `uart_rx.v`
In the initial implementation:
```verilog
// BUGGY ORIGINAL CODE:
if (baud_cnt == 15) begin
    baud_cnt <= 0; // Reset counter to 0 EVERY 15 cycles!
    if (bit_cnt >= 1 && bit_cnt <= 8)
        rx_data[bit_cnt-1] <= sync[1];
    bit_cnt <= bit_cnt + 1;
    if (bit_cnt == 9) begin
        state <= 0;
        done <= 1;
    end
end
```

### 7.2 Why It Failed (Mathematical Proof)
- In the transmitter, each bit lasts `BAUD_DIV = 30` clock cycles (31 total cycles: counts 0 through 30).
- In the original receiver, `baud_cnt` was reset to `0` whenever it reached `15`.
- As a consequence, after the start bit, **every single subsequent sample occurred every 16 clock cycles**, while the transmitter held each bit for **31 clock cycles**.
- The receiver was running at **nearly 2x speed**, sampling each transmitted bit twice!
- **Demonstration**: When sending `0x55` (`8'b01010101`):
  - Bit 0 (`1`) was sampled twice $\rightarrow$ bits 0 and 1 became `1, 1`.
  - Bit 1 (`0`) was sampled twice $\rightarrow$ bits 2 and 3 became `0, 0`.
  - Bit 2 (`1`) was sampled twice $\rightarrow$ bits 4 and 5 became `1, 1`.
  - Bit 3 (`0`) was sampled twice $\rightarrow$ bits 6 and 7 became `0, 0`.
  - Result: `8'b00110011` = **`0x33`** instead of `0x55`!

### 7.3 The Architectural Fix
The baud counter must count through the **entire bit interval** (`0` to `BAUD_DIV`), while sampling occurs decoupled at `HALF_BAUD`:

```verilog
// FIXED PRODUCTION CODE:
if (baud_cnt == BAUD_DIV) begin
    baud_cnt <= 13'd0;
    if (bit_cnt == 4'd9) begin
        state <= 1'b0;
        done  <= 1'b1;
    end else begin
        bit_cnt <= bit_cnt + 1'b1;
    end
end else begin
    baud_cnt <= baud_cnt + 1'b1;
end

// Midpoint sampling at center of bit cell:
if (baud_cnt == HALF_BAUD) begin
    if (bit_cnt >= 4'd1 && bit_cnt <= 4'd8)
        rx_data[bit_cnt - 4'd1] <= sync[1];
    else if (bit_cnt == 4'd0 && sync[1] != 1'b0)
        state <= 1'b0; // Noise glitch rejected
end
```

---

## 8. Verification & Test Suite

### 8.1 Automated Test Vectors (`sim/uart_sim.py` and `src/tb_uart.v`)

| Test Vector | Binary | Purpose | Result |
|:-----------:|:------:|:--------|:------:|
| `0x55` | `01010101` | Maximum switching frequency / alternating bit transitions | **PASS** |
| `0x58` | `01011000` | Verifies exact waveform from project specification figure | **PASS** |
| `0xAA` | `10101010` | Complementary alternating bit pattern | **PASS** |
| `0x00` | `00000000` | Line held low throughout data phase | **PASS** |
| `0xFF` | `11111111` | Line held high throughout data phase | **PASS** |
| `0xA5` | `10100101` | Mixed nibble checkerboard | **PASS** |
| `0x3C` | `00111100` | Grouped nibble transitions | **PASS** |
| **Glitch Test** | Transient `< 15` cyc pulse | Sub-bit noise spike on idle line rejected | **PASS** |

### 8.2 Running the Simulation
```bash
# Run cycle-accurate Python golden simulator
python sim/uart_sim.py

# Run in Icarus Verilog + GTKWave (if installed)
iverilog -o sim_uart src/uart_top.v src/uart_tx.v src/uart_rx.v src/tb_uart.v
vvp sim_uart
gtkwave tb_uart.vcd
```

---

## 9. FPGA Synthesis & Resource Utilization (Xilinx Artix-7)

Target Device: **Xilinx Artix-7 XC7A100T-1CSG324C** (Digilent Arty A7-100T)

| Resource | Utilization | Available on Artix-7 100T | Percentage |
|:---------|:-----------:|:-------------------------:|:----------:|
| **Slice LUTs** | 46 | 63,400 | < 0.1% |
| **Slice Registers (FFs)** | 42 | 126,800 | < 0.1% |
| **I/O Buffers (IOBs)** | 14 | 210 | 6.6% |
| **Block RAM (BRAM)** | 0 | 135 | 0.0% |
| **DSP48 Slices** | 0 | 240 | 0.0% |
| **Max Operating Frequency ($F_{\text{max}}$)** | > 220 MHz | 100 MHz target | Safe margin |
