// UART Receiver Module
module uart_rx(
    input clk,
    input rst_n,
    input rs232,
    output reg [7:0] rx_data,
    output reg done
);
    reg [1:0] sync;      // Synchronizer to reduce metastability
    reg state;
    reg [12:0] baud_cnt;
    reg [3:0] bit_cnt;

    // Synchronize rs232 input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync <= 2'b11;
        else
            sync <= {sync[0], rs232};
    end

    // UART RX state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            baud_cnt <= 0;
            bit_cnt <= 0;
            rx_data <= 0;
            done <= 0;
        end else begin
            // Detect start bit (falling edge)
            if (!state && (sync[1] == 0)) begin
                state <= 1;
                baud_cnt <= 0;
                bit_cnt <= 0;
                done <= 0;
            end else if (state) begin
                baud_cnt <= baud_cnt + 1;
                // Sample in the middle of the bit period (when baud_cnt == 15)
                if (baud_cnt == 15) begin
                    baud_cnt <= 0;
                    if (bit_cnt >= 1 && bit_cnt <= 8) begin
                        rx_data[bit_cnt-1] <= sync[1];
                    end
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == 9) begin
                        state <= 0;
                        done <= 1;
                    end
                end
            end
        end
    end
endmodule
