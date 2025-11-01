`timescale 1ns / 1ps

module sobel_tb();
    
localparam BAUD_RATE = 3_000_000;

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

logic ready_out = 0;

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
    .ready_out(ready_out),
    .data_out(),
    .valid_out(valid_out),
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

// Simulate TX module by pulsing every 10 cycles
logic [3:0] baud_div_cnt = 0;
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        baud_div_cnt <= 0;
        ready_out <= 0;
    end else begin
        ready_out <= 0; // default low
        if (baud_tick) begin
            if (baud_div_cnt == 4'd9) begin
                baud_div_cnt <= 0;
                ready_out <= 1; // pulse for one clk
            end else begin
                baud_div_cnt <= baud_div_cnt + 1;
            end
        end
    end
end



// Test sequence
reg [9:0] bit_index = 0;

logic [31:0] bits_sent = 0;
always @(posedge valid_out) bits_sent <= bits_sent + 1; 

initial begin
    // Apply reset
    #100;
    rst = 0;
    #50000;

    // Send first block of bytes
    @(posedge baud_tick);
    send_uart_byte(8'd5);
    send_uart_byte(8'd0);
    send_uart_byte(8'd7);
    send_uart_byte(8'd0);

    #50000;
    
    @(posedge baud_tick);
//    repeat(5) begin
//        repeat(3) send_uart_byte(255);
//        send_uart_byte(1);
//        repeat(3) send_uart_byte(254);
//    end

    repeat(4) send_uart_byte(0);
    send_uart_byte(255);
    repeat(30) send_uart_byte(0);

    // Send second block of bytes
//    @(posedge baud_tick);
//    repeat(1024*3) begin
//        send_uart_byte(bit_index[7:0]);
//        bit_index = bit_index + 1;
//    end
    
    
    
//    rst = 1;
//    #10000000;
//    rst = 0;
//    bit_index = 0;
    
//    @(posedge baud_tick);
//    send_uart_byte(8'd12);
//    send_uart_byte(8'd0); // 1024
//    send_uart_byte(8'd8);
//    send_uart_byte(8'd0);
    
//    #50000;
    
//    @(posedge baud_tick);
//    repeat(12*8) begin
//        send_uart_byte(bit_index[7:0]);
//        bit_index = bit_index + 1;
//    end

    // Wait for remaining data to be transmitted
    #100000;
    $finish;
end


endmodule