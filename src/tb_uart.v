`timescale 1ns/1ps
// Testbench for UART modules
module tb_uart;
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] data;
    reg rs232_in;
    wire rs232_tx;
    wire [7:0] rx_data;
    wire tx_done;
    wire rx_done;

    // Instantiate top-level UART module
    uart_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data(data),
        .rs232_in(rs232_in),
        .rs232_tx(rs232_tx),
        .rx_data(rx_data),
        .tx_done(tx_done),
        .rx_done(rx_done)
    );

    // Clock generation (50 MHz clock: period = 20 ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test stimulus
    initial begin
        rst_n = 0;
        start = 0;
        data = 8'h55;  // Example data
        rs232_in = 1;  // Idle state high
        #50;
        rst_n = 1;
        #50;
        start = 1;
        #20;
        start = 0;
        // Run simulation for a sufficient duration to see the transaction
        #1000;
        $stop;
    end
endmodule
