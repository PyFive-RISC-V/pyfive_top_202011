/*
 * vid_ram_char.v
 *
 * Character RAM storing the 127 8x8 chars
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_ram_char (
	// CPU access port ( 2x32 bits words per chars )
	input  wire [ 7:0] cp_addr_0,
	input  wire [31:0] cp_wdata_0,
	input  wire [ 3:0] cp_wmsk_0,
	input  wire        cp_we_0,

	output wire [31:0] cp_rdata_1,

	input  wire        cp_clk,

	// Video read port
	input  wire  [6:0] vp_char_0,
	input  wire  [2:0] vp_x_0,
	input  wire  [2:0] vp_y_0,
	input  wire        vp_mx_0,
	input  wire        vp_my_0,
	input  wire        vp_rot_0,
	input  wire        vp_dbl_0,

	output reg   [1:0] vp_data_3,

	input  wire        vp_clk
);

	// Signals
	// -------

	wire [ 2:0] vp_xf_0;
	wire [ 2:0] vp_yf_0;
	wire [ 5:0] vp_lsb_0;

	reg  [ 7:0] vp_addr_1;
	reg  [ 4:0] vp_mux_1;
	reg  [ 4:0] vp_mux_2;

	wire [31:0] vp_data_2;
	reg  [ 2:0] vp_data_mux_2;


	// RAM instances
	// -------------

	sram_1rw1r_32_256_8_sky130 ram_I (
		.clk0   (cp_clk),
		.csb0   (1'b0),
		.web0   (~cp_we_0),
		.wmask0 (~cp_wmsk_0),
		.addr0  (cp_addr_0),
		.din0   (cp_wdata_0),
		.dout0  (cp_rdata_1),
		.clk1   (vp_clk),
		.csb1   (1'b0),
		.addr1  (vp_addr_1),
		.dout1  (vp_data_2)
	);


	// Video port
	// ----------

	// Addressing
		// Mirror
	assign vp_xf_0 = vp_x_0 ^ { 3{vp_mx_0} };
	assign vp_yf_0 = vp_y_0 ^ { 3{vp_my_0} };

		// Rotate
	assign vp_lsb_0 = vp_rot_0 ? { vp_xf_0, vp_yf_0 } : { vp_yf_0, vp_xf_0 };

		// Final mem addres + mux sel
	always @(posedge vp_clk)
	begin
		vp_addr_1 <= { vp_char_0, vp_lsb_0[5] };
		vp_mux_1  <= { vp_lsb_0[4:1], vp_lsb_0[0] & ~vp_dbl_0 };
		vp_mux_2  <= vp_mux_1;
	end

	// Read muxing
	always @(*)
		case (vp_mux_2[4:1])
			4'h0:    vp_data_mux_2 <= vp_data_2[ 1: 0];
			4'h1:    vp_data_mux_2 <= vp_data_2[ 3: 2];
			4'h2:    vp_data_mux_2 <= vp_data_2[ 5: 4];
			4'h3:    vp_data_mux_2 <= vp_data_2[ 7: 6];
			4'h4:    vp_data_mux_2 <= vp_data_2[ 9: 8];
			4'h5:    vp_data_mux_2 <= vp_data_2[11:10];
			4'h6:    vp_data_mux_2 <= vp_data_2[13:12];
			4'h7:    vp_data_mux_2 <= vp_data_2[15:14];
			4'h8:    vp_data_mux_2 <= vp_data_2[17:16];
			4'h9:    vp_data_mux_2 <= vp_data_2[19:18];
			4'ha:    vp_data_mux_2 <= vp_data_2[21:20];
			4'hb:    vp_data_mux_2 <= vp_data_2[23:22];
			4'hc:    vp_data_mux_2 <= vp_data_2[25:24];
			4'hd:    vp_data_mux_2 <= vp_data_2[27:26];
			4'he:    vp_data_mux_2 <= vp_data_2[29:28];
			4'hf:    vp_data_mux_2 <= vp_data_2[31:30];
			default: vp_data_mux_2 <= 2'bxx;
		endcase

	always @(posedge vp_clk)
	begin
		vp_data_3[1] <= vp_dbl_0 & vp_data_mux_2[1];
		vp_data_3[0] <= vp_mux_2[0] ? vp_data_mux_2[1] : vp_data_mux_2[0];
	end

endmodule // vid_ram_char
