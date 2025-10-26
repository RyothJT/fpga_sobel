`timescale 1ns / 1ps

module uart_baud_gen_tb();
    
localparam BAUD_DIV = 100_000_000 / 9600 * 10;

reg clk = 1;
reg rst = 1;
reg RsRx = 1;

wire [7:0] rx_data;
wire [2:0] status;

integer sim_counter = 0;

uart_rx #(
    .ENABLE_ERRORS(1)
) rx (
    .clk(clk),
    .rst(rst),
    .RsRx(RsRx),
    .rx_data(rx_data),
    .valid(valid),
    .status(status)
);

always #5 clk = !clk;

initial begin
    #BAUD_DIV;
    rst = 0;
    #BAUD_DIV;
    RsRx = 0;
    #(BAUD_DIV*15.5);
    RsRx = 1;
    #BAUD_DIV;
    repeat(5) begin
        RsRx = 0;
        #BAUD_DIV
        RsRx = 1;
        #BAUD_DIV
        repeat(3) begin
            RsRx = 0;
            #BAUD_DIV;
            RsRx = 1;
            #BAUD_DIV;
        end
        RsRx = 0;
        #BAUD_DIV;
        RsRx = 1;
        #(BAUD_DIV*1);
    end
    $finish;
end

endmodule