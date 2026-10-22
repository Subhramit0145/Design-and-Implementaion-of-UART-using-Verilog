// =============================================================================
// Module: uart_rx
// Description: Parameterized UART Receiver Module (8-N-1 Protocol)
// Features:
//   - 2-stage Flip-Flop Synchronizer to eliminate metastability on async RS232 line
//   - Midpoint bit sampling (center of eye diagram) for maximum noise margin
//   - False start-bit glitch rejection filter
//   - Configurable baud divisor (BAUD_DIV)
// =============================================================================

module uart_rx #(
    parameter BAUD_DIV = 13'd30 // Clock ticks per serial bit (Default: 30 for simulation)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rs232,
    output reg  [7:0] rx_data,
    output reg        done
);

    reg [1:0]  sync;      // 2-stage synchronizer
    reg        state;
    reg [12:0] baud_cnt;
    reg [3:0]  bit_cnt;

    localparam HALF_BAUD = BAUD_DIV / 2;

    // Dual flip-flop synchronizer to protect against metastability
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync <= 2'b11;
        else
            sync <= {sync[0], rs232};
    end

    // UART RX Finite State Machine & Sampling Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= 1'b0;
            baud_cnt <= 13'd0;
            bit_cnt  <= 4'd0;
            rx_data  <= 8'd0;
            done     <= 1'b0;
        end else begin
            if (!state) begin
                done <= 1'b0;
                // Detect start bit: falling edge on synchronized input
                if (sync[1] == 1'b0) begin
                    state    <= 1'b1;
                    baud_cnt <= 13'd0;
                    bit_cnt  <= 4'd0;
                end
            end else begin
                // Advance baud counter through full bit period
                if (baud_cnt == BAUD_DIV) begin
                    baud_cnt <= 13'd0;
                    if (bit_cnt == 4'd9) begin
                        state <= 1'b0;
                        done  <= 1'b1; // Frame complete: 8 data bits and stop bit received
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end

                // Sample at the exact midpoint of each bit interval
                if (baud_cnt == HALF_BAUD) begin
                    if (bit_cnt >= 4'd1 && bit_cnt <= 4'd8) begin
                        rx_data[bit_cnt - 4'd1] <= sync[1]; // Shift in data bit (LSB first)
                    end else if (bit_cnt == 4'd0 && sync[1] != 1'b0) begin
                        // False start bit detected (noise glitch), abort back to IDLE
                        state <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
