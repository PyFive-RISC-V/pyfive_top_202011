/*
 * uart_tx.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module uart_tx #(
	parameter integer DIV_WIDTH = 8
)(
	output wire tx,
	input  wire [7:0] data,
	input  wire valid,
	output reg  ack,
	input  wire [DIV_WIDTH-1:0] div,	// div - 2
	input  wire clk,
	input  wire rst
);

	// Signals
	wire go, done, ce;
	reg  active;
	reg [9:0] shift;
	reg [DIV_WIDTH:0] div_cnt;
	reg [4:0] bit_cnt;

	// Control
	assign go = valid & ~active;
	assign done = ce & bit_cnt[4];

	always @(posedge clk or posedge rst)
		if (rst)
			active <= 1'b0;
		else
			active <= (active & ~done) | go;

	// Baud rate generator
	always @(posedge clk)
		if (~active | div_cnt[DIV_WIDTH])
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
	always @(posedge clk or posedge rst)
		if (rst)
			shift <= 10'h3ff;
		else if (go)
			shift <= { 1'b1, data, 1'b0 };
		else if (ce)
			shift <= { 1'b1, shift[9:1] };

	// Outputs
	always @(posedge clk)
		ack <= go;

	assign tx = shift[0];

endmodule // uart_tx
