`timescale 1ns / 1ps

module sobel_applier #(
    parameter DATA_BITS_IN = 8,
    parameter MAX_WIDTH = 32
)(
    input clk,
    input rst,
    input [(DATA_BITS_IN - 1):0] data_in,
    input valid_in,
    input ready_out,
    output logic [(DATA_BITS_IN - 1):0] data_out,
    output logic valid_out,
    output logic ready_in         // This remains unused because the UART can not stop, but kept for modularity
);

typedef enum logic [2:0] {
    IDLE,       // Waiting for signal to turn on
    STARTUP,    // Get dimensions of the image
    DATA,       // Calculate sobel operator and calculate data
    STOP        // Reach the calculated end of image
} state_t;

state_t state, next_state;

logic [15:0] width, height, x_input, y_input, x_output, y_output;
logic [1:0] top, y_middle, bottom;

logic [7:0] window_top[0:2], window_mid[0:2], window_bot[0:2];

logic [7:0] window[0:2][0:2];

logic [7:0] top_mask[0:2], mid_mask[0:2], bot_mask[0:2];

logic [10:0] sobel_vertical, sobel_horizontal;
logic [9:0] abs_sobel_vertical, abs_sobel_horizontal;
logic new_line;

logic [0:1] line_sel;

always_comb begin
    abs_sobel_vertical = (sobel_vertical[10]) ? -sobel_vertical : sobel_vertical;
    abs_sobel_horizontal = (sobel_horizontal[10]) ? -sobel_horizontal : sobel_horizontal;
    new_line = x_input == width - 1;
    x_output = x_input - 4;
end

logic [7:0] line_buffer [2:0][0:(MAX_WIDTH - 1)];
logic [9:0] wr_ptr;

always_ff @(posedge clk) begin
    if (rst) begin
        wr_ptr <= 0;
    end else begin
        window_top[0] <= window_top[1];
        window_top[1] <= window_top[2];
        window_top[2] <= line_buffer[0][wr_ptr];
        
        window_mid[0] <= window_mid[1];
        window_mid[1] <= window_mid[2];
        window_mid[2] <= line_buffer[1][wr_ptr];
        
        window_bot[0] <= window_bot[1];
        window_bot[1] <= window_bot[2];
        window_bot[2] <= line_buffer[2][wr_ptr];
    
        // write current pixel
        line_buffer[line_sel][wr_ptr] <= data_in;

        // advance write address
        if (wr_ptr == MAX_WIDTH-1) begin
            wr_ptr   <= 0;
            line_sel <= (line_sel == 2) ? 0 : line_sel + 1; // wrap on 3
        end else begin
            wr_ptr <= wr_ptr + 1;
        end
    end
end

// Compute nextstate and output
always_comb begin
    // default values
    next_state = IDLE;
    valid_out = 0;
    ready_in = 0;

    
    case(state)
        IDLE: begin
            data_out = 0;
            if (valid_in) begin
                next_state = STARTUP;
                width = data_in;
            end
        end
        STARTUP: begin
            next_state = STARTUP;
            if (valid_in) begin
                next_state = DATA;
                height = data_in;
            end
        end
        DATA: begin
            // Input new data
            next_state = DATA;
            if (valid_in) begin
                
                // Check if we've reached the end
                if (y_input == height) begin
                    next_state = STOP;
                end
    
                // Once we have three lines we can start processing and never stop
                // Skip the first x_input = 0, since this represents the convolution for the previous row
                if (y_input >= 2 || (y_input >= 1 && x_input > 1)) begin
                    valid_out = 1;
                    data_out = ((abs_sobel_vertical + abs_sobel_horizontal) >> 3);
                    
                    // Horizontal gradient (Gx)

                end
            end
        end
        STOP: begin
            next_state = STOP;
        end
    endcase
end

endmodule