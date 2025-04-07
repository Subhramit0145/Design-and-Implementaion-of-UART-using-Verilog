
## Detailed Module Descriptions

### 1. UART Transmitter (`src/uart_tx.v`)
- **Purpose:** Converts parallel data into a serial stream by adding a start bit, transmitting 8 data bits (LSB-first), and appending a stop bit.
- **Operation:**  
  - **State Machine:** Begins transmission when a high-level `start` signal is received.  
  - **Baud Rate Control:** Uses a counter (`baud_cnt`) that, for simulation purposes, counts 30 clock cycles per bit (adjust this value for real-world baud rate requirements).
  - **Transmission Sequence:**  
    - **Start Bit:** Drives the output line low.
    - **Data Bits:** Sequentially transmits each of the 8 bits of data.
    - **Stop Bit:** Returns the line to a high state.
- **Diagram Reference:** See **Figure 4** in the PDF for the timing diagram of the sending module.

### 2. UART Receiver (`src/uart_rx.v`)
- **Purpose:** Converts a serial data stream back into parallel data.
- **Operation:**  
  - **Synchronization:** Implements a multi-stage synchronizer to mitigate metastability issues while sampling the asynchronous input.
  - **Start Bit Detection:** Detects a falling edge that marks the start of the data frame.
  - **Data Sampling:** Samples data at the midpoint of each bit period to ensure accurate data capture.
  - **Reception Sequence:**  
    - Discards the start and stop bits.
    - Captures 8 bits of data into an 8-bit parallel output.
- **Diagram Reference:** See **Figure 5** in the PDF for the timing diagram of the receiving module.

### 3. Top Module (`src/uart_top.v`)
- **Purpose:** Integrates both the UART transmitter and receiver modules to facilitate full-duplex communication.
- **Operation:**  
  - Instantiates both the TX and RX modules.
  - Connects the transmitter’s output and receiver’s input.
  - Provides status signals (`tx_done` and `rx_done`) to indicate the completion of data transmission and reception.

### 4. Testbench (`src/tb_uart.v`)
- **Purpose:** Verifies the complete UART design by simulating both transmission and reception.
- **Operation:**  
  - Generates a clock signal (e.g., 50 MHz).
  - Resets the system and provides stimulus by initiating data transmission (for example, transmitting `8'h55`).
  - Monitors the outputs to confirm that the data is correctly transmitted and received.

## Experimental Results

The design has been verified through simulation with the following observations:

- **UART Transmitter Results 
![image](https://github.com/user-attachments/assets/9ce8267d-9c21-4b7c-a300-df494ef17298):**
  - The waveform shows the sequential output of the start bit, followed by the 8 data bits, and a final stop bit.
  - For instance, when transmitting a data value (e.g., `58H`), the waveform clearly demonstrates the proper sequencing (start bit, data bits in LSB-first order, and stop bit).

- **UART Receiver Results :**
![image](https://github.com/user-attachments/assets/7227766c-dea9-4c29-a927-d0bf4ab446d6)

  - The received waveform confirms that the receiver accurately captures 8 data bits (e.g., `55H`), effectively synchronizing and sampling the incoming serial data.
  - The experimental waveforms validate that the receiver's synchronizer and sampling strategy work as intended.
