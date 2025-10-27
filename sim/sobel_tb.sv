`timescale 1ns / 1ps

module sobel_tb();
    
localparam BAUD_RATE = 115200;

reg clk = 1;
reg rst = 1;
reg RsRx = 1;
wire tx_start;

wire [7:0] rx_data, tx_data;
wire valid;
wire baud_tick;
wire busy;
wire [2:0] status;
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

sobel_applier uut (
    .clk(clk),
    .rst(rst),
    .data_in(rx_data),
    .valid_in(valid),
    .ready_out(),
    .data_out(),
    .valid_out(),
    .ready_in()
);

integer sim_counter = 0;

// Clock generation
always #5 clk = ~clk;

// Task to send a UART byte (1 start, 8 data LSB first, 1 stop)
task send_uart_byte;
    input [7:0] input_byte;
    integer i;
    begin
        // Start bit
        RsRx = 0;
        @(posedge baud_tick);
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            RsRx = input_byte[i];
            @(posedge baud_tick);
        end

        // Stop bit
        RsRx = 1;
        @(posedge baud_tick);
    end
endtask

// Test sequence
reg [9:0] bit_index = 0;

initial begin
    // Apply reset
    #100;
    rst = 0;
    #50000;

    // Send first block of bytes
    @(posedge baud_tick);
    send_uart_byte(8'd5);
    send_uart_byte(8'd4);

    #50000;

    // Send second block of bytes
    @(posedge baud_tick);
    repeat(20) begin
        send_uart_byte(bit_index[7:0]);
        bit_index = bit_index + 1;
    end

    // Wait for remaining data to be transmitted
    #500000;
    $finish;
end


endmodule