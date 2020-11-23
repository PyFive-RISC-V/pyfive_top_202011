/*
 * vid_ram_screen.v
 *
 * Screen RAM storing the 48x28 char+attr
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_ram_screen (
	// CPU access port
	input  wire [ 8:0] cp_addr_0,
	input  wire [31:0] cp_wdata_0,
	input  wire [ 3:0] cp_wmsk_0,
	input  wire        cp_we_0,

	output wire [31:0] cp_rdata_1,

	input  wire        cp_clk,

	// Video read port
	input  wire  [5:0] vp_x_0,		// 0..47
	input  wire  [4:0] vp_y_0,		// 0..27
	input  wire        vp_sel_0,	// 0 => bit [7:0],  1 => bit [11:8]

	output reg   [7:0] vp_data_3,

	input  wire        vp_clk
);

	// Signals
	// -------

	// CPU port
	wire [ 1:0] cp_web_i_0;
	reg         cp_addr_lsb_1;
	wire [63:0] cp_rdata_i_1;

	// Video port
	reg  [ 7:0] vp_addr_1;
	reg  [ 3:0] vp_mux_1;
	reg  [ 3:0] vp_mux_2;

	wire [63:0] vp_data_2;
	reg  [ 7:0] vp_data_mux_2;


	// RAM instances
	// -------------

	sram_1rw1r_32_256_8_sky130 ram_hi_I (
		.clk0   (cp_clk),
		.csb0   (1'b0),
		.web0   (cp_web_i_0[1]),
		.wmask0 (~cp_wmsk_0),
		.addr0  (cp_addr_0[8:1]),
		.din0   (cp_wdata_0),
		.dout0  (cp_rdata_i_1[63:32]),
		.clk1   (vp_clk),
		.csb1   (1'b0),
		.addr1  (vp_addr_1),
		.dout1  (vp_data_2[63:32])
	);

	sram_1rw1r_32_256_8_sky130 ram_lo_I (
		.clk0   (cp_clk),
		.csb0   (1'b0),
		.web0   (cp_web_i_0[0]),
		.wmask0 (~cp_wmsk_0),
		.addr0  (cp_addr_0[8:1]),
		.din0   (cp_wdata_0),
		.dout0  (cp_rdata_i_1[31:0]),
		.clk1   (vp_clk),
		.csb1   (1'b0),
		.addr1  (vp_addr_1),
		.dout1  (vp_data_2[31:0])
	);


	// CPU port
	// --------

	assign cp_web_i_0 = {
		~(cp_we_0 &  cp_addr_0[0]),
		~(cp_we_0 & ~cp_addr_0[0])
	};

	always @(posedge cp_clk)
		cp_addr_lsb_1 <= cp_addr_0[0];

	assign cp_rdata_1 = cp_addr_lsb_1 ? cp_rdata_i_1[63:32] : cp_rdata_i_1[31:0];


	// Video port
	// ----------

	// Adressing
	always @(posedge vp_clk)
	begin
		// 9*y + 6*sel + (sel ? (x/16) : (x/8))
		vp_addr_1 <=
			{ vp_y_0, vp_sel_0, vp_sel_0, 1'b0 } +
			{ 3'b000, vp_y_0 } +
			( vp_sel_0 ? { 6'd0, vp_x_0[5:4] } : { 5'd0, vp_x_0[5:3] } );

		vp_mux_1 <= vp_sel_0 ? vp_x_0[3:0] : { vp_x_0, 1'b0 };
		vp_mux_2 <= vp_mux_1;
	end

	// Read muxing
	always @(*)
		case (vp_mux_2[3:1])
			3'b000:  vp_data_mux_2 <= vp_data_2[ 7: 0];
			3'b001:  vp_data_mux_2 <= vp_data_2[15: 8];
			3'b010:  vp_data_mux_2 <= vp_data_2[23:16];
			3'b011:  vp_data_mux_2 <= vp_data_2[31:24];
			3'b100:  vp_data_mux_2 <= vp_data_2[39:32];
			3'b101:  vp_data_mux_2 <= vp_data_2[47:40];
			3'b110:  vp_data_mux_2 <= vp_data_2[55:48];
			3'b111:  vp_data_mux_2 <= vp_data_2[63:56];
			default: vp_data_mux_2 <= 8'hxx;
		endcase

	always @(posedge vp_clk)
	begin
		vp_data_3[7:4] <= vp_data_mux_2[7:4];
		vp_data_3[3:0] <= vp_mux_2[0] ? vp_data_mux_2[7:4] : vp_data_mux_2[3:0];
	end

endmodule // vid_ram_screen
