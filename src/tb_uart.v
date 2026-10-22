`timescale 1ns/1ps
// =============================================================================
// Testbench: tb_uart
// Description: Self-checking testbench for UART transceiver (Loopback & Multi-Vector)
// Features:
//   - Loopback verification (rs232_tx connected to rs232_in)
//   - Multi-byte test coverage (0x55, 0x58, 0xAA, 0x00, 0xFF, 0xA5, 0x3C)
//   - Automated pass/fail reporting with error counting
//   - VCD waveform generation for GTKWave / ModelSim / Vivado
// =============================================================================

module tb_uart;

    // Simulation Clock Parameters (50 MHz system clock -> 20ns period)
    parameter CLK_PERIOD = 20;
    parameter BAUD_DIV   = 30; // 30 clock ticks per bit for fast simulation

    // Testbench Stimulus Signals
    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] data;
    wire       rs232_line; // Loopback wire
    wire       rs232_tx;
    wire [7:0] rx_data;
    wire       tx_done;
    wire       rx_done;

    integer pass_count = 0;
    integer fail_count = 0;

    // Connect TX to RX for loopback testing
    assign rs232_line = rs232_tx;

    // Instantiate Top-level UART Module
    uart_top #(
        .BAUD_DIV(BAUD_DIV)
    ) uut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .data    (data),
        .rs232_in(rs232_line),
        .rs232_tx(rs232_tx),
        .rx_data (rx_data),
        .tx_done (tx_done),
        .rx_done (rx_done)
    );

    // 50 MHz Clock Generator (Period = 20 ns)
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Task: Transmit a byte, await reception, and self-check
    task send_and_verify(input [7:0] test_byte, input [255:0] desc);
        begin
            @(posedge clk);
            data  = test_byte;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Wait for both transmitter and receiver to complete
            fork
                @(posedge tx_done);
                @(posedge rx_done);
            join

            // Verify received data against transmitted byte
            @(posedge clk);
            if (rx_data === test_byte) begin
                $display("[PASS] Transmitted: 0x%02X | Received: 0x%02X | %0s", test_byte, rx_data, desc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Transmitted: 0x%02X | Received: 0x%02X | MISMATCH! %0s", test_byte, rx_data, desc);
                fail_count = fail_count + 1;
            end

            // Inter-frame idle delay
            #(CLK_PERIOD * 10);
        end
    endtask

    // Main Test Stimulus Process
    initial begin
        // Setup VCD waveform dump
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);

        $display("================================================================");
        $display("   STARTING UART SELF-CHECKING LOOPBACK VERIFICATION TESTBENCH  ");
        $display("================================================================");

        // System Initialization
        rst_n = 1'b0;
        start = 1'b0;
        data  = 8'h00;
        #(CLK_PERIOD * 5);

        // Release Reset
        rst_n = 1'b1;
        #(CLK_PERIOD * 10);

        // Run Verification Test Vectors
        send_and_verify(8'h55, "Alternating bit pattern (01010101)");
        send_and_verify(8'h58, "README Figure verification vector (01011000)");
        send_and_verify(8'hAA, "Inverted alternating pattern (10101010)");
        send_and_verify(8'h00, "All-zeros pattern (00000000)");
        send_and_verify(8'hFF, "All-ones pattern (11111111)");
        send_and_verify(8'hA5, "Checkerboard pattern A5 (10100101)");
        send_and_verify(8'h3C, "Nibble boundary pattern (00111100)");

        #(CLK_PERIOD * 20);

        // Final Report
        $display("================================================================");
        if (fail_count == 0) begin
            $display(" TEST STATUS: SUCCESS! All %0d vectors passed bit-accurately.", pass_count);
        end else begin
            $display(" TEST STATUS: FAILED! %0d passed, %0d failed.", pass_count, fail_count);
        end
        $display("================================================================");

        $finish;
    end

endmodule
