/*
 * vid_palette.v
 *
 * Screen RAM storing the 48x28 char+attr
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_palette #(
	parameter integer W = 4
)(
	// CPU access port
	input  wire [ 3:0] cp_addr_0,
	input  wire [31:0] cp_wdata_0,
	input  wire        cp_we_0,

	output reg  [31:0] cp_rdata_1,

	input  wire        cp_clk,

	// Video read port
	input  wire          vp_zero_0,
	input  wire          vp_brd_0,
	input  wire  [W-1:0] vp_brd_col_0,

	input  wire  [  3:0] vp_col_0,
	output reg   [W-1:0] vp_col_1,

	input  wire          vp_clk
);

	// Signals
	// -------

	reg [W-1:0] mem[0:15];


	// CPU port
	// --------

	// Write
	always @(posedge cp_clk)
		if (cp_we_0)
			mem[cp_addr_0] <= cp_wdata_0[W-1:0];

	// Read
	always @(posedge cp_clk)
		cp_rdata_1[W-1:0] <= mem[cp_addr_0];

	initial
		cp_rdata_1[31:W] = 0;


	// Video port
	// ----------

	always @(posedge vp_clk)
		vp_col_1 <= vp_zero_0 ? 0 : (vp_brd_0 ? vp_brd_col_0 : mem[vp_col_0]);

endmodule // vid_palette
