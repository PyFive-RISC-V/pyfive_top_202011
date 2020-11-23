/*
 * vid_tgen.v
 *
 * Flexible video timing generator
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_tgen #(
	parameter integer W = 12
)(
	// Outputs
	output wire [W-1:0] x,
	output wire [W-1:0] y,

	output wire         vsync,
	output wire         hsync,
	output wire         active,
	output wire         draw,

	output reg          eof,	// End-Of-Frame pulse

	// Config Bus
	input  wire [ 3:0] cb_addr,
	input  wire [31:0] cb_wdata,
	input  wire        cb_we,

	// Control
	input  wire run,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	wire active_h;
	wire draw_h;

	wire active_v;
	wire draw_v;
	reg  draw_v_r;

	wire nxt_line;


	// Counters
	// --------

	vid_tgen_cnt #(W) cnt_h (
		.pos      (x),
		.sync     (hsync),
		.active   (active_h),
		.draw     (draw_h),
		.cb_addr  (cb_addr[2:0]),
		.cb_wdata (cb_wdata),
		.cb_we    (cb_we & ~cb_addr[3]),
		.run      (run),
		.step     (1'b1),
		.rollover (nxt_line),
		.clk      (clk),
		.rst      (rst)
	);

	vid_tgen_cnt #(W) cnt_v (
		.pos      (y),
		.sync     (vsync),
		.active   (active_v),
		.draw     (draw_v),
		.cb_addr  (cb_addr[2:0]),
		.cb_wdata (cb_wdata),
		.cb_we    (cb_we &  cb_addr[3]),
		.run      (run),
		.step     (nxt_line),
		.rollover (),
		.clk      (clk),
		.rst      (rst)
	);


	// Outputs
	// -------

	assign active = active_h & active_v;
	assign draw   = draw_h   & draw_v;

	always @(posedge clk)
	begin
		draw_v_r <= draw_v;
		eof <= draw_v_r & ~draw_v;
	end

endmodule // vid_tgen


module vid_tgen_cnt #(
	parameter integer W = 12
)(
	// Outputs
	output wire [W-1:0] pos,

	output wire         sync,
	output wire         active,
	output wire         draw,

	// Config Bus
	input  wire [ 2:0] cb_addr,
	input  wire [31:0] cb_wdata,
	input  wire        cb_we,

	// Control
	input  wire run,
	input  wire step,
	output wire rollover,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	localparam integer FLG_LAST   = 3;
	localparam integer FLG_SYNC   = 2;
	localparam integer FLG_ACTIVE = 1;
	localparam integer FLG_DRAW   = 0;


	// Signals
	// -------

	// Config registersd
	reg  [W-1:0] cfg_zone_len[0:5];
	reg  [  3:0] cfg_zone_flag[0:5];

	// Zones
	wire         z_move;

		// Current
	reg    [2:0] zc_id;
	reg    [3:0] zc_flag;
	reg  [W-1:0] zc_len;

		// Next
	wire   [2:0] zn_id;
	wire   [3:0] zn_flag;
	wire [W-1:0] zn_len;

	// Position
	reg  [W-1:0] cnt_cur;
	wire [W-1:0] cnt_inc;
	wire [W-1:0] cnt_nxt;
	wire         cnt_last;


	// Configuation
	// ------------

	always @(posedge clk)
	begin : cfg_reg
		integer i;
		for (i=0; i<6; i=i+1)
			if (cb_we & (cb_addr == i))
			begin
				cfg_zone_len[i]  <= cb_wdata[W-1:0];
				cfg_zone_flag[i] <= cb_wdata[31:28];
			end
	end


	// Zone counter
	// ------------

	// Register for current zone
	always @(posedge clk)
		if (~run | z_move) begin
			zc_id   <= zn_id;
			zc_flag <= zn_flag;
			zc_len  <= zn_len;
		end

	// Next zone ID
	assign zn_id = (~run | zc_flag[FLG_LAST]) ? 3'd0 : (zc_id + 1);

	// Next zone data
	assign zn_len  = cfg_zone_len[zn_id];
	assign zn_flag = cfg_zone_flag[zn_id];

	// When to move
	assign z_move = step & cnt_last;


	// Position Counter
	// ----------------

	always @(posedge clk or negedge run)
		if (~run)
			cnt_cur <= 0;
		else if (step)
			cnt_cur <= cnt_nxt;

	assign cnt_last = (cnt_cur == zc_len);
	assign cnt_inc  = cnt_cur + 1;
	assign cnt_nxt  = cnt_last ? 0 : cnt_inc;


	// Outputs
	// -------

	assign pos = cnt_cur;

	assign sync   = zc_flag[FLG_SYNC];
	assign active = zc_flag[FLG_ACTIVE];
	assign draw   = zc_flag[FLG_DRAW];

	assign rollover = step & cnt_last & zc_flag[FLG_LAST];

endmodule // vid_tgen_cnt
