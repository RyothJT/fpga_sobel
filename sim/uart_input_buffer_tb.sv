`timescale 1ns / 1ps

module uart_input_buffer_tb();

localparam BAUD_RATE = 115200;

reg clk = 1;
reg rst = 1;
reg RsRx = 1;
reg start_sending = 0;
wire tx_start;

wire [7:0] rx_data, tx_data;
wire valid;
wire baud_tick;
wire busy;
wire [2:0] status;
wire RsTx;
wire valid_out;

integer sim_counter = 0;

// Baud generator
uart_baud_gen #(
    .BAUD_RATE(BAUD_RATE)
) baud_gen (
    .clk(clk),
    .rst(rst),
    .baud_tick(baud_tick)
);

// UART RX
uart_rx #(
    .ENABLE_ERRORS(1),
    .BAUD_RATE(BAUD_RATE)
) rx (
    .clk(clk),
    .rst(rst),
    .RsRx(RsRx),
    .rx_data(rx_data),
    .valid_out(valid),
    .status(status)
);

// UART input buffer
uart_input_buffer uut (
    .clk(clk),
    .rst(rst),
    .data_in(rx_data),
    .valid_in(valid),
    .ready_out(tx_start),
    .data_out(tx_data),
    .valid_out(valid_out),
    .ready_in()
);

// UART TX
uart_tx #(
    .BAUD_RATE(BAUD_RATE)
) tx (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .RsTx(RsTx),
    .busy(busy)
);

// Clock generation
always #5 clk = ~clk;

// Task to send a UART byte (1 start, 8 data LSB first, 1 stop)
task send_uart_byte;
    input [7:0] byte;
    integer i;
    begin
        // Start bit
        RsRx = 0;
        @(posedge baud_tick);
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            RsRx = byte[i];
            @(posedge baud_tick);
        end

        // Stop bit
        RsRx = 1;
        @(posedge baud_tick);
    end
endtask

// Drive TX start when buffer has valid data
assign tx_start = (rst || busy || !valid_out || !start_sending) ? 0 : 1; 

// Test sequence
reg [9:0] bit_index = 0;

initial begin
    // Apply reset
    #100;
    rst = 0;

    // Send first block of bytes
    repeat(10) begin
        send_uart_byte(bit_index[7:0]);
        bit_index = bit_index + 1;
    end

    #500000;
    start_sending = 1; // allow buffer to output
    #50000;

    // Send second block of bytes
    bit_index = bit_index + 50;
    repeat(14) begin
        send_uart_byte(bit_index[7:0]);
        bit_index = bit_index + 1;
    end

    // Wait for remaining data to be transmitted
    #50000;
    $finish;
end

endmodule
