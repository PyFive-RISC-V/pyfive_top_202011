/*
 * glitch_filter.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module glitch_filter #(
	parameter integer L = 4,
	parameter RST_VAL = 1'b1,
	parameter integer WITH_SYNCHRONIZER = 1,
	parameter integer WITH_SAMP_COND = 0,
	parameter integer WITH_EVT_COND = 0
)(
	input wire  in,
	input wire  samp_cond,	// Sampling condition
	input wire  evt_cond,	// Event condition

	output wire val,
	output reg  rise,
	output reg  fall,

	input  wire clk,
	input  wire rst
);
	// Signals
	wire [L-1:0] all_zero;
	wire [L-1:0] all_one;
	wire [L-1:0] all_rst;

	wire samp_cond_i = WITH_SAMP_COND ? samp_cond : 1'b1;
	wire evt_cond_i  = WITH_EVT_COND  ? evt_cond  : 1'b1;

	reg    [1:0] sync;
	reg          state;
	reg  [L-1:0] cnt;
	reg  [L-1:0] cnt_move;

	wire cnt_is_all_zero;
	wire cnt_is_all_one;

	// Constants
	assign all_zero = { L{1'b0} };
	assign all_one  = { L{1'b1} };
	assign all_rst  = { L{RST_VAL} };

	// Synchronizer
	if (WITH_SYNCHRONIZER)
		always @(posedge clk)
			sync <= { sync[0], in };
	else
		always @(*)
			sync = { in, in };

	// Filter
	always @(*)
	begin
		cnt_move = all_zero;

		if (samp_cond_i & sync[1] & ~cnt_is_all_one)
			cnt_move = 1;
		else if (samp_cond_i & ~sync[1] & ~cnt_is_all_zero)
			cnt_move = -1;
	end

	always @(posedge clk)
		if (rst)
			cnt <= all_rst;
		else
			cnt <= cnt + cnt_move;

	assign cnt_is_all_zero = (cnt == all_zero);
	assign cnt_is_all_one  = (cnt == all_one);

	// State
	always @(posedge clk)
		if (rst)
			state <= RST_VAL;
		else begin
			if (state & cnt_is_all_zero)
				state <= 1'b0;
			else if (~state & cnt_is_all_one)
				state <= 1'b1;
			else
				state <= state;
		end

	assign val = state;

	// Rise / Fall detection
	always @(posedge clk)
	begin
		if (~evt_cond_i) begin
			rise <= 1'b0;
			fall <= 1'b0;
		end else begin
			rise <= ~state & cnt_is_all_one;
			fall <=  state & cnt_is_all_zero;
		end
	end

endmodule // glitch_filter
