`timescale 1ns / 1ps

module uart_tx_tb();
    
localparam BAUD_DIV = 100_000_000 / 9600 * 10;

reg clk = 1;
reg rst = 1;
wire [15:0] led;
reg RsRx = 1;

integer sim_counter = 0;

wire RsTx;
wire busy;

reg [7:0] tx_data = 8'h05;
reg tx_start = 0;

uart_tx tx(
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .RsTx(RsTx),
    .busy(busy)
);

always #5 clk = !clk;

initial begin
    #BAUD_DIV;
    rst = 0;
    #BAUD_DIV;
    repeat(3) begin
        tx_start = 1;
        #(BAUD_DIV * 2);
        tx_start = 0;
        #(BAUD_DIV * 10);
    end
    $finish;
end

endmodule
