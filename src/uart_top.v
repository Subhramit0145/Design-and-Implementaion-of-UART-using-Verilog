// =============================================================================
// Module: uart_top
// Description: Top-Level UART Transceiver integrating Transmitter and Receiver
// Features:
//   - Parameterized baud rate configuration
//   - Full-duplex asynchronous serial communication (TX and RX concurrently)
//   - Individual completion flags for TX (tx_done) and RX (rx_done)
// =============================================================================

module uart_top #(
    parameter BAUD_DIV = 13'd30 // Clock cycles per serial bit (Default: 30 for simulation)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    input  wire       rs232_in,
    output wire       rs232_tx,
    output wire [7:0] rx_data,
    output wire       tx_done,
    output wire       rx_done
);

    // UART Transmitter Instance
    uart_tx #(
        .BAUD_DIV(BAUD_DIV)
    ) u_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .data    (data),
        .rs232_tx(rs232_tx),
        .done    (tx_done)
    );

    // UART Receiver Instance
    uart_rx #(
        .BAUD_DIV(BAUD_DIV)
    ) u_rx (
        .clk     (clk),
        .rst_n   (rst_n),
        .rs232   (rs232_in),
        .rx_data (rx_data),
        .done    (rx_done)
    );

endmodule
