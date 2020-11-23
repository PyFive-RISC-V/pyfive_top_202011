/*
 * wb_splitter.v
 *
 * Splits and adapt the bus as provided by the caravel to the
 * stuff I usually use which is not 100% wishbone
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module wb_splitter #(
	parameter integer N = 4,	// max 16

	// auto-set
	parameter integer RL = (N * 32) - 1
)(
	// Upstream port
	input  wire         wbu_stb_i,
	input  wire         wbu_cyc_i,
	input  wire         wbu_we_i,
	input  wire   [3:0] wbu_sel_i,
	input  wire  [31:0] wbu_dat_i,
	input  wire  [31:0] wbu_adr_i,
	output wire         wbu_ack_o,
	output reg   [31:0] wbu_dat_o,

	// Downstream ports
	output wire  [15:0] wbd_addr,
	input  wire  [RL:0] wbd_rdata,
	output wire  [31:0] wbd_wdata,
	output wire  [ 3:0] wbd_wmsk,
	output wire         wbd_we,
	output reg  [N-1:0] wbd_cyc,
	input  wire [N-1:0] wbd_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	assign wbd_addr  =  wbu_adr_i[17:2];

	assign wbd_wdata = wbu_dat_i;
	assign wbd_wmsk  = ~wbu_sel_i;
	assign wbd_we    =  wbu_we_i;

	assign wbu_ack_o = |wbd_ack;

	always @(*)
	begin : wb_or_gen
		integer i;
		wbu_dat_o = 0;
		for (i=0; i<N; i=i+1)
			wbu_dat_o = wbu_dat_o | wbd_rdata[32*i+:32];
	end

	always @(*)
	begin : wb_cyc_gen
		integer i;
		wbd_cyc = 0;
		for (i=0; i<N; i=i+1)
			wbd_cyc[i] = wbu_cyc_i & wbu_stb_i & (wbu_adr_i[23:20] == i);
	end

endmodule // wb_splitter
