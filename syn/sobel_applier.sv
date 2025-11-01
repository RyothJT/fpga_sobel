`timescale 1ns / 1ps

// Move to separate module eventually
module bram_1k8_dual (
    // Port A
    input  logic        clk_a,
    input  logic        we_a,
    input  logic [9:0]  addr_a,
    input  logic [7:0]  din_a,
    output logic [7:0]  dout_a,

    // Port B
    input  logic        clk_b,
    input  logic        we_b,
    input  logic [9:0]  addr_b,
    input  logic [7:0]  din_b,
    output logic [7:0]  dout_b
);

    // Shared 2K x 8 memory
    logic [7:0] mem [0:2047]; // Doubled to 2kB each, almost enough for 4k images

    // Port A
    always_ff @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    // Port B
    always_ff @(posedge clk_b) begin
        if (we_b)
            mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end
endmodule


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
    
    ,
    output [7:0] led
);

// DEBUG
assign led = bytes_output[7:0];

typedef enum logic [2:0] {
    IDLE,       // Waiting for signal to turn on
    STARTUP,    // Get dimensions of the image
    DATA,
//    DATA_IN,
//    DATA_INOUT,       // 
//    DATA_OUT,   // Output the remaining last row of multiplications after all data recieved
    STOP        // Reach the calculated end of image
} state_t;

typedef enum logic [2:0] {
    TOP = 3'b100,
    MID = 3'b010,
    BOT = 3'b001
} line_write_enable_t;

state_t state, next_state;

line_write_enable_t line_we;

logic [15:0] width, height, wr_ptr, rd_ptr, wr_y, rd_y;
logic [7:0] top_out, mid_out, bot_out;
logic [7:0] window_top[0:2], window_mid[0:2], window_bot[0:2];
logic [7:0] effective_top[0:2], effective_mid[0:2], effective_bot[0:2];
logic [10:0] sobel_vertical, sobel_horizontal;
logic [9:0] abs_sobel_vertical, abs_sobel_horizontal;
logic new_line;
logic right, down, left, up;
logic [31:0] bytes_input, bytes_output;
logic [2:0] config_bytes_recieved;
logic ready_to_send;
logic [31:0] number_bytes_to_send;
logic [7:0] latched_data;

// Loop for pipeline delay
logic [15:0] rd_y_pipeline;

bram_1k8_dual top_line (
    // WRITE PORT
    .clk_a(clk),
    .we_a(line_we[2]),
    .din_a(latched_data),
    .addr_a(wr_ptr),
    .dout_a(),
    
    // READ PORT
    .clk_b(clk),
    .we_b(0),
    .din_b(0),
    .addr_b(wr_ptr),
    .dout_b(top_out)
);

bram_1k8_dual mid_line (
    // WRITE PORT
    .clk_a(clk),
    .we_a(line_we[1]),
    .din_a(latched_data),
    .addr_a(wr_ptr),
    .dout_a(),
    
    // READ PORT
    .clk_b(clk),
    .we_b(0),
    .din_b(0),
    .addr_b(wr_ptr),
    .dout_b(mid_out)
);

bram_1k8_dual bot_line (
    // WRITE PORT
    .clk_a(clk),
    .we_a(line_we[0]),
    .din_a(latched_data),
    .addr_a(wr_ptr),
    .dout_a(),
    
    // READ PORT
    .clk_b(clk),
    .we_b(0),
    .din_b(0),
    .addr_b(wr_ptr),
    .dout_b(bot_out)
);

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        line_we <= TOP; // default of top?
    end else begin
        state <= next_state;
        
        if (state == IDLE) begin
            wr_ptr <= 0;
            wr_y <= 0;
            rd_y <= 0;
            rd_y_pipeline <= 0;
            bytes_input <= 0;
            bytes_output <= 0;
            ready_to_send <= 0;
            number_bytes_to_send <= 0;
            config_bytes_recieved <= 0;
            valid_out <= 0;
            latched_data <= 0;
            
            // wait until we recieve a byte
            if (valid_in) begin
                width[7:0] <= data_in[7:0];
                config_bytes_recieved <= 1;
            end
        end
        else if (state == STARTUP) begin
            if (valid_in) begin
                case (config_bytes_recieved)
                    1: width[15:8] <= data_in[7:0];
                    2: height[7:0] <= data_in[7:0];
                    3: height[15:8] <= data_in[7:0];
                    default: ;
                endcase
                config_bytes_recieved <= config_bytes_recieved + 1;
            end
            number_bytes_to_send <= width * height;
        end
        else if (state == DATA) begin
            valid_out <= 0;
            // Accept data, move shift registers appropriately
            if (valid_in || (wr_y >= height)) begin // TODO fix DSP
            //if (valid_in || bytes_input >= number_bytes_to_send) begin
                bytes_input <= bytes_input + 1;
                ready_to_send <= 1;
                latched_data <= data_in;
                
                // Wrap line and increment x coordinate
                // Something is wrong with wr_ptr...
            end
            
            // Conditions for this are hard. TODO
            // Output data, only output when a new data has been recieved or we're at the end of the stream
            //if (ready_out && ready_to_send) begin
            if (ready_out && (ready_to_send)) begin
                ready_to_send <= 0;
                
                if (new_line) begin
                    wr_ptr <= 0;
                    wr_y <= wr_y + 1;
                    case(line_we)
                        BOT: line_we <= MID;
                        MID: line_we <= TOP;
                        TOP: line_we <= BOT;
                    endcase
                end
                else wr_ptr <= wr_ptr + 1;
                        
                // TODO Make this understandable   
                case(line_we)
                    BOT: begin
                        window_top[2] <= mid_out;
                        window_mid[2] <= top_out;
                        window_bot[2] <= bot_out;
                    end
                    MID: begin
                        window_top[2] <= top_out;
                        window_mid[2] <= bot_out;
                        window_bot[2] <= mid_out;
                    end
                    TOP: begin
                        window_top[2] <= bot_out;
                        window_mid[2] <= mid_out;
                        window_bot[2] <= top_out;
                    end
                endcase
                
                // Shift the window
                window_top[0] <= window_top[1];
                window_top[1] <= window_top[2];
                
                window_mid[0] <= window_mid[1];
                window_mid[1] <= window_mid[2];
                
                window_bot[0] <= window_bot[1];
                window_bot[1] <= window_bot[2];
        
                if (rd_y >= 1) begin
                    bytes_output <= bytes_output + 1;
                    valid_out <= 1;
                end

                // Process data
                sobel_vertical <= -effective_top[0]-(effective_top[1] << 1)-effective_top[2]
                                  +effective_bot[0]+(effective_bot[1] << 1)+effective_bot[2];
                                  
                sobel_horizontal <= -effective_top[0] + effective_top[2]
                                   -(effective_mid[0] << 1) + (effective_mid[2] << 1)
                                   -effective_bot[0] + effective_bot[2];
                                   
                // Pipeline y coordinate
                rd_y <= rd_y_pipeline;
                rd_y_pipeline <= wr_y;
            end
            
//            // Last row and some extras
//            else if (ready_out && bytes_input == number_bytes_to_send) begin
//                bytes_output <= bytes_output + 1;
//                valid_out <= 1;
//            end
        end
    end
end


assign abs_sobel_vertical = (sobel_vertical[10]) ? -sobel_vertical : sobel_vertical;
assign abs_sobel_horizontal = (sobel_horizontal[10]) ? -sobel_horizontal : sobel_horizontal;
assign new_line = (wr_ptr == width - 1);
assign rd_ptr = (wr_ptr >= 2) ? (wr_ptr - 2) : (width - (2 - wr_ptr));
    
    // Update conditions for edge checking
assign left = (rd_ptr == 0);
assign down = (rd_y == (height - 0));
assign right = (rd_ptr == (width -1));
assign up = (rd_y <= 1);
    
    // TOP LEFT
assign effective_top[0] = (up || left) ? 0 : window_top[0];
    // TOP MIDDLE
assign effective_top[1] = up ? 0 : window_top[1];
    // TOP RIGHT
assign effective_top[2] = (up || right) ? 0 : window_top[2];
    // MIDDLE RIGHT
assign effective_mid[2] = right ? 0 : window_mid[2];
    // BOTTOM RIGHT
assign effective_bot[2] = (down || right) ? 0 : window_bot[2];
    // BOTTOM MIDDLE
assign effective_bot[1] = down ? 0 : window_bot[1];
    // BOTTOM LEFT
assign effective_bot[0] = (down || left) ? 0 : window_bot[0];
    // MIDDLE LEFT
assign effective_mid[0] = left ? 0 : window_mid[0];
    // MIDDLE MIDDLE
assign effective_mid[1] = window_mid[1];

// Compute nextstate and output
always_comb begin
    // default values
    next_state = state;
    ready_in = 0;

    case(state)
        IDLE: begin
            if (valid_in) begin
                next_state = STARTUP;
            end
        end
        STARTUP: begin
            next_state = STARTUP;
            if (config_bytes_recieved == 4) begin
                next_state = DATA;
            end
        end
        DATA: begin
            // Input new data
            next_state = DATA;
            data_out = ((abs_sobel_vertical + abs_sobel_horizontal) >> 3);
            
//            if (bytes_output == number_bytes_to_send) begin
//                next_state = STOP;
//            end
            
            if (rd_y >= (height + 1) && rd_ptr > 0) begin
                next_state = STOP;
            end
        end
        STOP: begin
            next_state = IDLE;
        end
    endcase
end

endmodule