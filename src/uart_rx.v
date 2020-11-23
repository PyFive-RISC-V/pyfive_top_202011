/*
 * uart_rx.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module uart_rx #(
	parameter integer DIV_WIDTH = 8,
	parameter integer GLITCH_FILTER = 2
)(
	input  wire rx,
	output wire [7:0] data,
	output reg  stb,
	input  wire [DIV_WIDTH-1:0] div,	// div - 2
	input  wire clk,
	input  wire rst
);
	// Signals
	wire rx_val;
	wire rx_fall;

	wire go, done, ce;
	reg  active;
	reg [DIV_WIDTH:0] div_cnt;
	reg [4:0] bit_cnt;
	reg [8:0] shift;

	// Input stage (synchronizer / de-glitch / change detect)
	generate
		// Glitch filter
		if (GLITCH_FILTER > 0)
			glitch_filter #(
				.L(GLITCH_FILTER),
				.RST_VAL(1'b1),
				.WITH_SYNCHRONIZER(1)
			) gf_I (
				.in(rx),
				.val(rx_val),
				.rise(),
				.fall(rx_fall),
				.clk(clk),
				.rst(rst)
			);

		// Or simple synchronizer
		else begin
			reg [1:0] rx_sync;
			reg rx_fd;

			always @(posedge clk)
			begin
				rx_sync <= { rx_sync[0], rx };
				rx_fd   <= rx_sync[1] & ~rx_sync[0];
			end

			assign rx_fall = rx_fd;
			assign rx_val  = rx_sync[1];
		end
	endgenerate

	// Control
	assign go = rx_fall & ~active;
	assign done = ce & bit_cnt[4];

	always @(posedge clk or posedge rst)
		if (rst)
			active <= 1'b0;
		else
			active <= (active & ~done) | go;

	// Baud rate generator
	always @(posedge clk)
		if (~active)
			div_cnt <= { 2'b00, div[DIV_WIDTH-1:1] } - 1;
		else if (div_cnt[DIV_WIDTH])
			div_cnt <= { 1'b0, div };
		else
			div_cnt <= div_cnt - 1;

	assign ce = div_cnt[DIV_WIDTH];

	// Bit counter
	always @(posedge clk)
		if (~active)
			bit_cnt <= 5'h08;
		else if (ce)
			bit_cnt <= bit_cnt - 1;

	// Shift register
	always @(posedge clk)
		if (ce)
			shift <= { rx_val, shift[8:1] };

	// Outputs
	assign data = shift[7:0];

	always @(posedge clk)
		stb <= ce & bit_cnt[4] & rx_val;

endmodule // uart_rx
