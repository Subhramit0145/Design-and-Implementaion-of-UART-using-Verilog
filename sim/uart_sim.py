"""
=============================================================================
UART (Universal Asynchronous Receiver-Transmitter) Python Golden Simulator
Cycle-accurate bit-level verification model for uart_tx, uart_rx, and uart_top.
=============================================================================
"""

import sys

class UART_TX:
    """Cycle-accurate model of src/uart_tx.v"""
    def __init__(self, baud_div=30):
        self.baud_div = baud_div
        self.rst_n = 1
        self.r_data = 0
        self.state = 0
        self.baud_cnt = 0
        self.bit_flag = 0
        self.bit_cnt = 0
        self.rs232_tx = 1
        self.done = 0

    def step(self, start, data, rst_n):
        self.rst_n = rst_n
        if not self.rst_n:
            self.baud_cnt = 0
            self.bit_flag = 0
            self.rs232_tx = 1
            self.done = 0
            self.bit_cnt = 0
            self.state = 0
            self.r_data = 0
            return

        # Baud counter
        if self.state:
            if self.baud_cnt == self.baud_div:
                next_baud_cnt = 0
            else:
                next_baud_cnt = self.baud_cnt + 1
        else:
            next_baud_cnt = 0

        # Bit flag: pulses at baud limit
        if self.state and (self.baud_cnt == self.baud_div):
            next_bit_flag = 1
        else:
            next_bit_flag = 0

        next_state = self.state
        next_r_data = self.r_data
        next_bit_cnt = self.bit_cnt
        next_done = self.done
        next_rs232_tx = self.rs232_tx

        if start and not self.state:
            next_state = 1
            next_r_data = data & 0xFF
            next_bit_cnt = 0
            next_done = 0
        elif self.state and self.bit_flag:
            if self.bit_cnt == 0:
                next_rs232_tx = 0  # Start bit (Active-Low)
            elif 1 <= self.bit_cnt <= 8:
                next_rs232_tx = (self.r_data >> (self.bit_cnt - 1)) & 1  # LSB first
            elif self.bit_cnt == 9:
                next_rs232_tx = 1  # Stop bit (Active-High)

            if self.bit_cnt == 9:
                next_done = 1
                next_state = 0
            else:
                next_bit_cnt = self.bit_cnt + 1
        elif not self.state:
            next_done = 0

        self.baud_cnt = next_baud_cnt
        self.bit_flag = next_bit_flag
        self.state = next_state
        self.r_data = next_r_data
        self.bit_cnt = next_bit_cnt
        self.done = next_done
        self.rs232_tx = next_rs232_tx


class UART_RX:
    """Cycle-accurate model of src/uart_rx.v with midpoint sampling and glitch filter"""
    def __init__(self, baud_div=30):
        self.baud_div = baud_div
        self.half_baud = baud_div // 2
        self.sync = 3
        self.state = 0
        self.baud_cnt = 0
        self.bit_cnt = 0
        self.rx_data = 0
        self.done = 0

    def step(self, rs232_in, rst_n):
        if not rst_n:
            self.sync = 3
            self.state = 0
            self.baud_cnt = 0
            self.bit_cnt = 0
            self.rx_data = 0
            self.done = 0
            return

        # Dual flip-flop synchronizer
        self.sync = ((self.sync << 1) & 2) | (rs232_in & 1)
        sync1 = (self.sync >> 1) & 1

        next_state = self.state
        next_baud_cnt = self.baud_cnt
        next_bit_cnt = self.bit_cnt
        next_rx_data = self.rx_data
        next_done = 0

        if not self.state:
            if sync1 == 0:  # Falling edge start bit detection
                next_state = 1
                next_baud_cnt = 0
                next_bit_cnt = 0
        else:
            if self.baud_cnt == self.baud_div:
                next_baud_cnt = 0
                if self.bit_cnt == 9:
                    next_state = 0
                    next_done = 1
                else:
                    next_bit_cnt = self.bit_cnt + 1
            else:
                next_baud_cnt = self.baud_cnt + 1

            # Sample at the exact midpoint of each bit cell
            if self.baud_cnt == self.half_baud:
                if 1 <= self.bit_cnt <= 8:
                    bit_idx = self.bit_cnt - 1
                    mask = ~(1 << bit_idx) & 0xFF
                    next_rx_data = (self.rx_data & mask) | (sync1 << bit_idx)
                elif self.bit_cnt == 0 and sync1 != 0:
                    # Noise glitch rejection: abort back to IDLE
                    next_state = 0

        self.state = next_state
        self.baud_cnt = next_baud_cnt
        self.bit_cnt = next_bit_cnt
        self.rx_data = next_rx_data
        self.done = next_done


def run_tests():
    print("=" * 68)
    print("  UART GOLDEN SIMULATION AND SELF-CHECKING VERIFICATION SUITE")
    print("=" * 68)

    tx = UART_TX(baud_div=30)
    rx = UART_RX(baud_div=30)

    # Test vectors covering key bit patterns (including 0x55 and 0x58 from README)
    test_vectors = [
        (0x55, "Alternating 01010101"),
        (0x58, "README Figure Vector (01011000)"),
        (0xAA, "Inverted Alternating 10101010"),
        (0x00, "All Zeros (00000000)"),
        (0xFF, "All Ones (11111111)"),
        (0xA5, "Checkerboard A5 (10100101)"),
        (0x5A, "Checkerboard 5A (01011010)"),
        (0x3C, "Nibble Pattern (00111100)"),
        (0xC3, "Nibble Pattern (11000011)"),
    ]

    all_passed = True
    for byte_val, desc in test_vectors:
        # Reset
        for _ in range(5):
            tx.step(start=0, data=0, rst_n=0)
            rx.step(rs232_in=1, rst_n=0)

        # Settle
        for _ in range(5):
            tx.step(start=0, data=0, rst_n=1)
            rx.step(rs232_in=tx.rs232_tx, rst_n=1)

        # Trigger TX start
        tx.step(start=1, data=byte_val, rst_n=1)
        rx.step(rs232_in=tx.rs232_tx, rst_n=1)

        # Run loopback until RX asserts done
        received = False
        for cycle in range(500):
            tx.step(start=0, data=byte_val, rst_n=1)
            rx.step(rs232_in=tx.rs232_tx, rst_n=1)
            if rx.done:
                if rx.rx_data == byte_val:
                    print(f" [PASS] Transmitted: 0x{byte_val:02X} | Received: 0x{rx.rx_data:02X} | {desc}")
                else:
                    print(f" [FAIL] Transmitted: 0x{byte_val:02X} | Received: 0x{rx.rx_data:02X} (MISMATCH)")
                    all_passed = False
                received = True
                break
        if not received:
            print(f" [FAIL] Transmitted: 0x{byte_val:02X} | TIMEOUT (rx_done not asserted)")
            all_passed = False

    # Glitch Rejection Test
    print("-" * 68)
    print(" Testing Noise Glitch Filter (< HALF_BAUD low pulse)...")
    for _ in range(5):
        rx.step(rs232_in=1, rst_n=1)
    # Inject 4-cycle noise spike (shorter than half_baud = 15)
    for _ in range(4):
        rx.step(rs232_in=0, rst_n=1)
    # Restore line to HIGH
    for _ in range(40):
        rx.step(rs232_in=1, rst_n=1)
        assert rx.done == 0, "Noise glitch falsely asserted rx_done!"
    assert rx.state == 0, "Noise glitch failed to restore receiver to IDLE!"
    print(" [PASS] Sub-bit glitch filtered out cleanly. RX stayed in IDLE.")

    print("=" * 68)
    if all_passed:
        print(" RESULT: ALL TESTS PASSED WITH 100% BIT ACCURACY!")
    else:
        print(" RESULT: ONE OR MORE TESTS FAILED!")
        sys.exit(1)
    print("=" * 68)

if __name__ == "__main__":
    run_tests()
