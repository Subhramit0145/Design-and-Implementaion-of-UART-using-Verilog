// =============================================================================
// Module: uart_tx
// Description: Parameterized UART Transmitter Module (8-N-1 Protocol)
// Features:
//   - Configurable baud divisor for simulation & FPGA clock synthesis
//   - LSB-first serial transmission (1 start bit, 8 data bits, 1 stop bit)
//   - Transmission completion status flag (done)
// =============================================================================

module uart_tx #(
    parameter BAUD_DIV = 13'd30 // Clock ticks per serial bit (e.g., 30 for sim, 868 for 100MHz@115200)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data,
    output reg        rs232_tx,
    output reg        done
);

    reg [7:0]  r_data;
    reg        state;
    reg [12:0] baud_cnt;
    reg        bit_flag;
    reg [3:0]  bit_cnt;

    // Baud rate generator counter: counts 0 to BAUD_DIV
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 13'd0;
        else if (state) begin
            if (baud_cnt == BAUD_DIV)
                baud_cnt <= 13'd0;
            else
                baud_cnt <= baud_cnt + 1'b1;
        end else
            baud_cnt <= 13'd0;
    end

    // Pulse bit_flag every BAUD_DIV clock cycles during transmission
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_flag <= 1'b0;
        else if (state && (baud_cnt == BAUD_DIV))
            bit_flag <= 1'b1;
        else
            bit_flag <= 1'b0;
    end

    // UART TX Finite State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rs232_tx <= 1'b1; // Idle line is HIGH
            done     <= 1'b0;
            bit_cnt  <= 4'd0;
            state    <= 1'b0;
            r_data   <= 8'd0;
        end else begin
            if (start && !state) begin
                state    <= 1'b1;
                r_data   <= data;
                bit_cnt  <= 4'd0;
                done     <= 1'b0;
            end else if (state && bit_flag) begin
                case (bit_cnt)
                    4'd0: rs232_tx <= 1'b0;          // Start bit (active-low)
                    4'd1: rs232_tx <= r_data[0];     // Data bit 0 (LSB)
                    4'd2: rs232_tx <= r_data[1];     // Data bit 1
                    4'd3: rs232_tx <= r_data[2];     // Data bit 2
                    4'd4: rs232_tx <= r_data[3];     // Data bit 3
                    4'd5: rs232_tx <= r_data[4];     // Data bit 4
                    4'd6: rs232_tx <= r_data[5];     // Data bit 5
                    4'd7: rs232_tx <= r_data[6];     // Data bit 6
                    4'd8: rs232_tx <= r_data[7];     // Data bit 7 (MSB)
                    4'd9: rs232_tx <= 1'b1;          // Stop bit (active-high)
                    default: rs232_tx <= 1'b1;
                endcase

                if (bit_cnt == 4'd9) begin
                    done    <= 1'b1;
                    state   <= 1'b0;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end else if (!state) begin
                done <= 1'b0; // De-assert done once idle
            end
        end
    end

endmodule
