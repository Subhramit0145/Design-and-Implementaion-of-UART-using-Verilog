// Top-level UART module integrating transmitter and receiver
module uart_top(
    input clk,
    input rst_n,
    input start,
    input [7:0] data,
    input rs232_in,
    output rs232_tx,
    output [7:0] rx_data,
    output tx_done,
    output rx_done
);
    wire tx_done_wire;
    wire rs232_tx_wire;

    uart_tx u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data(data),
        .rs232_tx(rs232_tx_wire),
        .done(tx_done_wire)
    );

    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rs232(rs232_in),
        .rx_data(rx_data),
        .done(rx_done)
    );

    assign rs232_tx = rs232_tx_wire;
    assign tx_done = tx_done_wire;
endmodule
