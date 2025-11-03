Personal project using Basys-3 FPGA developement board (XC7A35T-1CPG236C).

No separate IP used. All code written by Justin Troth, with the exception of the adapation of the .gitignore file.

# Process

Outputs the edges of a given image using the sobel operator. A python script decodes theh image into grayscale values. The width and height of the images are then sent over UART as 16 bit numbers. The brightness value of each pixel is then sent over as 8 bits numbers, from top-left to bottom-right. Once there is enough information, the FPGA starts processing and outputting concurrently with the input. The output is then recompiled as an image of the same size by the python script.

<p align="center">
  <img src="https://github.com/user-attachments/assets/308c19c3-77b0-444d-a798-06ce48c1b353" width="48%" alt="Before"/>
  <img src="https://github.com/user-attachments/assets/892e9127-5960-4699-a497-67bc3e72f50d" width="48%" alt="After"/>
</p>
<p align="center"><b>Before</b> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <b>After</b></p>

# Limitations

The main constraint of this implementation is UART. UART is not intedned for this purpose, but is the only mode of communication available on the Basys-3 board. UART is set to be 448000 baud in this implementation, as this is the fastest baud rate I was able to use without package loss.

(448000 bits/s)(1 byte/10 bits) = 44.8 kB/s.

This speed not fast enough for effective image processing. Currently it is a decellerator. It takes approximately 9 seconds to send a "small" 748x480 image.

When evaluating the actual edges of the image (x = 0, y = height -1...), unknown values are considered as '0'. This leads to the edges of the image almost always being marked with large values. This was actually helpful for troubleshooting, but are not true edges and should not be evaluated as such. This can be fixed by modifying the mask to grab the nearest known value, although this becomes more complicated with corners and which value to take.

# Module Structure

The UART modules constitue the communication for this implementation. They are fairly simple implementations of Mealy machines, although they are currently not structured well. Both modules implement an accumulator-based fractional divider with 32 bits of precision. For 448000 baud at 100 MHz, oversampling by 16x, the true baud rate is 447999.998869. It would take approximately 14 minutes for the clocks to get out of sync, assuming all else is ideal. This equates to 40.47 MB, which is enough to fit four grayscale 4k images.

Rx connects to the sobel applier module without an input buffer implemented. It is not needed in this application because we can be absolultely certain that the TX module is sending out data at the same rate. An input buffer could be easily implemented by swapping valid_in, ready_in, and data_in wires from outside the sobel applier module.

The sobel applier module has three line buffers. The size of these modules must be set at compile time, so we grab the largest memory segments we can, 4kB. This allows any image less than 4096 in width or height to be processed by the FPGA. Rotation is applied beforehand by the python script to ensure the smallest dimension feeds into the line buffers.

The module waits in idle until data is recieved. Once data is recieved, it processes the first four bytes as 16 bit width and height. After this startup period, we move to the start of data processing.

(Note: I hope to break data into separate states in the future for the sake of clarity)

Data starts by accepting the whole first line of the first image without outputting. We do not have enough data to do a convolution yet, and our image would actually get larger if we took started outputting values during this time.

After we have the first line and the first two datapoints of the next line, we can compute the first multiplication. This is the top-left corner of the image. The module masks the data accordingly, such that unknown values are set to 0. Computation then starts, and after pipelineing, the result is done, valid_out is set to true for one cycle, and TX outputs the computed value. Output and input takes place concurrently until all the input has been recieved, after which shifting and bit masking is done without input until all pixels have been output. The state reverts to idle and is ready to receive a new image.

# Setup

The COM port is not automatically calibrated. You will have to find which COM part corresponds to the FPGA yourself.

# Goals


- Reduce variables
- Rewrite RX and TX modules in SystemVerilog style as proper Mealy machines
- Rewrite indexing syntax to be human readable, currently names are misleading
- Reduce WNS signficantly by pipelining more operations, make more explicit
- Split DATA into separate segments to appropriately module the three parts of convolution
- Support for images up to an arbitrarily size, assuming one side is less than 4096 pixels. (Currently only works with 1024 pixels due to BRAM structure)
- Support for other 3x3 convolutions
- Easy setup for Vivado
- Testing using communication method other than UART

- ~~Fix application of sobel operator (currently smears slightly)~~ Data written to RAM at same time as reading caused issues with offsetting the kernel
- ~~Get rid of number_bytes_to_send in order to not use DSP slice (currently used for ending condition and troubleshooting)~~
- ~~Fix alignment issue on straight lines (somehow warped)?~~ Fixed by setting baud rate to a multiple of 112000 (may vary by computer)
