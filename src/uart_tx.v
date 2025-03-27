// UART Transmitter Module
module uart_tx(
    input clk,
    input rst_n,
    input start,
    input [7:0] data,
    output reg rs232_tx,
    output reg done
);

    reg [7:0] r_data;
    reg state;
    reg [12:0] baud_cnt;
    reg bit_flag;
    reg [3:0] bit_cnt;

    // Baud counter: counts to 30 (for simulation; adjust for real baud rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 0;
        else if (state) begin
            if (baud_cnt == 30)
                baud_cnt <= 0;
            else
                baud_cnt <= baud_cnt + 1;
        end else
            baud_cnt <= 0;
    end

    // Generate bit_flag every 30 cycles
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_flag <= 0;
        else if (state && (baud_cnt == 30))
            bit_flag <= 1;
        else
            bit_flag <= 0;
    end

    // UART TX state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs232_tx <= 1;
            done <= 0;
            bit_cnt <= 0;
            state <= 0;
        end else begin
            if (start && !state) begin
                state <= 1;
                r_data <= data;
                bit_cnt <= 0;
                done <= 0;
            end else if (state && bit_flag) begin
                case (bit_cnt)
                    4'd0: rs232_tx <= 0;             // Start bit (low)
                    4'd1: rs232_tx <= r_data[0];
                    4'd2: rs232_tx <= r_data[1];
                    4'd3: rs232_tx <= r_data[2];
                    4'd4: rs232_tx <= r_data[3];
                    4'd5: rs232_tx <= r_data[4];
                    4'd6: rs232_tx <= r_data[5];
                    4'd7: rs232_tx <= r_data[6];
                    4'd8: rs232_tx <= r_data[7];
                    4'd9: rs232_tx <= 1;             // Stop bit (high)
                    default: rs232_tx <= 1;
                endcase
                if (bit_cnt == 9) begin
                    done <= 1;
                    state <= 0;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end
        end
    end
endmodule
