/*
 * vid_top_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_top (
	// Output
	output wire [ 3:0] data,
	output wire        vsync,
	output wire        hsync,
	output wire        de,

	// Bus interface
	input  wire [13:0] wb_addr,
	output reg  [31:0] wb_rdata,
	input  wire [31:0] wb_wdata,
	input  wire [ 3:0] wb_wmsk,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// IRQ
		// ??

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Timing Generator output
	wire [11:0] tg_x;
	wire [11:0] tg_y;

	wire        tg_vsync;
	wire        tg_hsync;
	wire        tg_active;
	wire        tg_draw;

	wire        tg_eof;

	// CPU interfaces
		// Timing gen
	wire [ 3:0] tg_cb_addr;
	wire [31:0] tg_cb_wdata;
	reg         tg_cb_we;

		// Screen RAM
	wire [ 8:0] scr_cp_addr_0;
	wire [31:0] scr_cp_wdata_0;
	wire [ 3:0] scr_cp_wmsk_0;
	reg         scr_cp_we_0;
	wire [31:0] scr_cp_rdata_1;

		// Character RAM
	wire [ 7:0] chr_cp_addr_0;
	wire [31:0] chr_cp_wdata_0;
	wire [ 3:0] chr_cp_wmsk_0;
	reg         chr_cp_we_0;
	wire [31:0] chr_cp_rdata_1;

		// Palette
	wire [ 3:0] pal_cp_addr_0;
	wire [31:0] pal_cp_wdata_0;
	reg         pal_cp_we_0;
	wire [31:0] pal_cp_rdata_1;

		// Misc
	reg         wb_cyc_r;
	wire        wb_we_i;

	// Video Ports
		// Screen RAM
	wire  [5:0] scr_vp_x_0;
	wire  [4:0] scr_vp_y_0;
	wire        scr_vp_sel_0;
	wire  [7:0] scr_vp_data_3;

		// Character RAM
	wire  [6:0] chr_vp_char_5;
	wire  [2:0] chr_vp_x_5;
	wire  [2:0] chr_vp_y_5;
	reg         chr_vp_mx_5;
	reg         chr_vp_my_5;
	reg         chr_vp_rot_5;
	reg         chr_vp_dbl_5;
	wire  [1:0] chr_vp_data_8;

		// Palette
	wire        pal_vp_zero_8;
	wire        pal_vp_brd_8;
	wire  [3:0] pal_vp_brd_col_8;
	wire  [3:0] pal_vp_col_8;
	wire  [3:0] pal_vp_col_9;

	// Pixel Pipeline
	reg  [ 3:0] pp_attr;
	wire        pp_char_ce_4;
	reg  [ 4:0] pp_attr_5;
	reg  [ 6:0] pp_char_5;
	reg  [ 2:0] pp_pal_5;
	wire        pp_dbl_8;
	wire  [2:0] pp_pal_8;
	wire        pp_draw_8;
	wire        pp_active_8;

	// Control
	wire [31:0] ctrl_rdata;
	reg         ctrl_we;

	reg  [ 3:0] brd_col;
	reg  [ 1:0] sel_pal;
	reg  [ 1:0] sel_rot;
	reg  [ 1:0] sel_dbl;
	reg         run;


	// Control
	// -------

	// CSR
	always @(posedge clk)
		if (rst) begin
			brd_col <= 4'h0;
			sel_pal <= 2'b00;
			sel_rot <= 2'b00;
			sel_dbl <= 2'b00;
			run     <= 1'b0;
		end else if (ctrl_we) begin
			brd_col <= wb_wdata[15:12];
			sel_pal <= wb_wdata[9:8];
			sel_rot <= wb_wdata[7:6];
			sel_dbl <= wb_wdata[5:4];
			run     <= wb_wdata[0];
		end

	assign ctrl_rdata = {
		16'd0,
		brd_col,
		2'd0,
		sel_pal,
		sel_rot,
		sel_dbl,
		3'd0,
		run
	};


	// Timing Generator
	// ----------------

	vid_tgen #(
		.W(12)
	) tg_I (
		.x        (tg_x),
		.y        (tg_y),
		.vsync    (tg_vsync),
		.hsync    (tg_hsync),
		.active   (tg_active),
		.draw     (tg_draw),
		.eof      (tg_eof),
		.cb_addr  (tg_cb_addr),
		.cb_wdata (tg_cb_wdata),
		.cb_we    (tg_cb_we),
		.run      (run),
		.clk      (clk),
		.rst      (rst)
	);


	// RAM
	// ---

	// Screen RAM
	vid_ram_screen scr_I (
		.cp_addr_0  (scr_cp_addr_0),
		.cp_wdata_0 (scr_cp_wdata_0),
		.cp_wmsk_0  (scr_cp_wmsk_0),
		.cp_we_0    (scr_cp_we_0),
		.cp_rdata_1 (scr_cp_rdata_1),
		.cp_clk     (clk),
		.vp_x_0     (scr_vp_x_0),
		.vp_y_0     (scr_vp_y_0),
		.vp_sel_0   (scr_vp_sel_0),
		.vp_data_3  (scr_vp_data_3),
		.vp_clk     (clk)
	);

	// Character RAM
	vid_ram_char chr_I (
		.cp_addr_0  (chr_cp_addr_0 ),
		.cp_wdata_0 (chr_cp_wdata_0),
		.cp_wmsk_0  (chr_cp_wmsk_0),
		.cp_we_0    (chr_cp_we_0),
		.cp_rdata_1 (chr_cp_rdata_1),
		.cp_clk     (clk),
		.vp_char_0  (chr_vp_char_5),
		.vp_x_0     (chr_vp_x_5),
		.vp_y_0     (chr_vp_y_5),
		.vp_mx_0    (chr_vp_mx_5),
		.vp_my_0    (chr_vp_my_5),
		.vp_rot_0   (chr_vp_rot_5 ),
		.vp_dbl_0   (chr_vp_dbl_5),
		.vp_data_3  (chr_vp_data_8),
		.vp_clk     (clk)
	);

	// Palette memory
	vid_palette #(
		.W(4)
	) pal_I (
		.cp_addr_0    (pal_cp_addr_0),
		.cp_wdata_0   (pal_cp_wdata_0),
		.cp_we_0      (pal_cp_we_0),
		.cp_rdata_1   (pal_cp_rdata_1),
		.cp_clk       (clk),
		.vp_zero_0    (pal_vp_zero_8),
		.vp_brd_0     (pal_vp_brd_8),
		.vp_brd_col_0 (pal_vp_brd_col_8),
		.vp_col_0     (pal_vp_col_8),
		.vp_col_1     (pal_vp_col_9),
		.vp_clk       (clk)
	);


	// Pixel pipeline
	// --------------

	// Lookup char & attr
	assign scr_vp_x_0   =  tg_x[9:4];
	assign scr_vp_y_0   =  tg_y[8:4];
	assign scr_vp_sel_0 = ~tg_x[0];

		// We need two cycles to lookup data,
		// so there are some pipeline trickery
		// here ...

	always @(posedge clk)
		pp_attr <= scr_vp_data_3[3:0];

	delay_bit #(3) dly_pp_ce (tg_x[0], pp_char_ce_4, clk);

	always @(posedge clk)
	begin
		if (pp_char_ce_4) begin
			pp_attr_5 <= { pp_attr, scr_vp_data_3[7] };
			pp_char_5 <= scr_vp_data_3[6:0];
		end
	end

	// Lookup pixel data
	assign chr_vp_char_5 = pp_char_5;

	delay_bus #(5, 3) dly_x (tg_x[3:1], chr_vp_x_5, clk);
	delay_bus #(5, 3) dly_y (tg_y[3:1], chr_vp_y_5, clk);

	always @(*)
	begin
		chr_vp_mx_5 = pp_attr_5[4];
		chr_vp_my_5 = pp_attr_5[3];

		pp_pal_5 = { pp_attr_5[2:1],  (pp_attr[0] & sel_pal[1]) ^ sel_pal[0] };

		casez (sel_rot)
			2'b00:   chr_vp_rot_5 = 1'b0;
			2'b01:   chr_vp_rot_5 = 1'b1;
			2'b1z:   chr_vp_rot_5 = pp_attr_5[0];
			default: chr_vp_rot_5 = 1'bx;
		endcase

		casez (sel_dbl)
			2'b00:   chr_vp_dbl_5 = 1'b0;
			2'b01:   chr_vp_dbl_5 = 1'b1;
			2'b1z:   chr_vp_dbl_5 = pp_attr_5[0];
			default: chr_vp_dbl_5 = 1'bx;
		endcase
	end

	// Lookup final color
	delay_bit #(3)    dly_dbl   (chr_vp_dbl_5, pp_dbl_8,    clk);
	delay_bus #(3, 3) dly_pal   (pp_pal_5,     pp_pal_8,    clk);
	delay_bit #(8)    dly_draw  (tg_draw,      pp_draw_8,   clk);
	delay_bit #(8)    dly_valid (tg_active,    pp_active_8, clk);

	assign pal_vp_zero_8    = ~pp_active_8;
	assign pal_vp_brd_8     =  pp_active_8 & ~pp_draw_8;
	assign pal_vp_brd_col_8 =  brd_col;

	assign pal_vp_col_8 = { pp_pal_8, 1'b0 } ^ { 2'b00, chr_vp_data_8[1] & pp_dbl_8, chr_vp_data_8[0] };

	// Output
	assign data = pal_vp_col_9;

	delay_bit #(9) dly_vsync  (tg_vsync,    vsync, clk);
	delay_bit #(9) dly_hsync  (tg_hsync,    hsync, clk);
	delay_bit #(1) dly_active (pp_active_8, de,    clk);


	// Bus Interface
	// -------------

		// Address mapping
		//
		// 00x - Control
		// 010 - Timing generator
		// 011 - Palette RAM
		// 10x - Char RAM
		// 11x - Screen RAM

	// Address / Write-data
	assign tg_cb_addr     = wb_addr[3:0];
	assign tg_cb_wdata    = wb_wdata;

	assign scr_cp_addr_0  = wb_addr[8:0];
	assign scr_cp_wdata_0 = wb_wdata;
	assign scr_cp_wmsk_0  = wb_wmsk;

	assign chr_cp_addr_0  = wb_addr[7:0];
	assign chr_cp_wdata_0 = wb_wdata;
	assign chr_cp_wmsk_0  = wb_wmsk;

	assign pal_cp_addr_0  = wb_addr[3:0];
	assign pal_cp_wdata_0 = wb_wdata;

	// Write strobes
	assign wb_we_i = wb_cyc & wb_we & ~wb_ack;

	always @(posedge clk)
	begin
	    ctrl_we     <= wb_we_i & (wb_addr[13:12] == 2'b00);
		tg_cb_we    <= wb_we_i & (wb_addr[13:11] == 3'b010);
		scr_cp_we_0 <= wb_we_i & (wb_addr[13:12] == 2'b11);
		chr_cp_we_0 <= wb_we_i & (wb_addr[13:12] == 2'b10);
		pal_cp_we_0 <= wb_we_i & (wb_addr[13:11] == 3'b011);
	end

	// Read Mux
	always @(posedge clk)
		if (~wb_cyc | wb_ack)
			wb_rdata <= 32'h00000000;
		else
			casez (wb_addr[13:11])
				3'b00z:  wb_rdata <= ctrl_rdata;
				3'b010:  wb_rdata <= 32'hxxxxxxxx;
				3'b011:  wb_rdata <= pal_cp_rdata_1;
				3'b10z:  wb_rdata <= chr_cp_rdata_1;
				3'b11z:  wb_rdata <= scr_cp_rdata_1;
				default: wb_rdata <= 32'hxxxxxxxx;
			endcase

	// Ack
	always @(posedge clk)
	begin
		wb_cyc_r <= wb_cyc & ~wb_ack;
		wb_ack   <= ((wb_cyc & wb_we) | (wb_cyc_r & ~wb_we)) & ~wb_ack;
	end

endmodule // vid_top
