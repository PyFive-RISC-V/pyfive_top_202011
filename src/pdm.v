/*
 * pdm.v
 *
 * vim: ts=4 sw=4
 *
 * Pulse Density Modulation core (1st order with dither)
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module pdm #(
	parameter integer WIDTH = 8,
	parameter DITHER = "NO",
	parameter PHY = "GENERIC"
)(
	// PWM out
	output wire pdm,

	// Config
	input  wire [WIDTH-1:0] cfg_val,
	input  wire cfg_oe,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	wire [WIDTH:0] inc;
	reg  [WIDTH:0] acc;

	reg  dither;

	wire pdm_i;

	// Delta Sigma
	assign inc = { acc[WIDTH], cfg_val };

	always @(posedge clk)
	begin
		if (rst)
			acc <= 0;
		else
			acc <= acc + inc + dither;
	end

	assign pdm_i = acc[WIDTH];

	// Dither generator
	generate
		if (DITHER == "YES") begin
			// Dither using a simple LFSR
			wire [7:0] lfsr_out;

			pdm_lfsr #(
				.WIDTH(8),
				.POLY(8'h71)
			) lfsr_I (
				.out(lfsr_out),
				.clk(clk),
				.rst(rst)
			);

			always @(posedge clk)
				dither <= lfsr_out[0] ^ lfsr_out[3];

		end else begin
			// No dither
			initial
				dither = 1'b0;
		end
	endgenerate

	// PHY (Basically just IO register)
	generate
		if (PHY == "NONE") begin
			// No PHY (and no OE support)
			assign pdm = pdm_i;
		end else if (PHY == "GENERIC") begin
			// Generic IO register, let tool figure it out
			reg pdm_d_r;
			reg pdm_oe_r;
			always @(posedge clk)
			begin
				pdm_d_r  <= pdm_i;
				pdm_oe_r <= cfg_oe;
			end
			assign pdm = pdm_oe_r ? pdm_d_r : 1'bz;
		end else if (PHY == "ICE40") begin
			// iCE40 specific IOB
			SB_IO #(
				.PIN_TYPE(6'b110100),
				.PULLUP(1'b0),
				.NEG_TRIGGER(1'b0),
				.IO_STANDARD("SB_LVCMOS")
			) io_reg_I (
				.PACKAGE_PIN(pdm),
				.LATCH_INPUT_VALUE(1'b0),
				.CLOCK_ENABLE(1'b1),
				.INPUT_CLK(1'b0),
				.OUTPUT_CLK(clk),
				.OUTPUT_ENABLE(cfg_oe),
				.D_OUT_0(pdm_i),
				.D_OUT_1(1'b0),
				.D_IN_0(),
				.D_IN_1()
			);
		end
	endgenerate

endmodule // pdm


module pdm_lfsr #(
	parameter integer WIDTH = 8,
	parameter POLY = 8'h71
)(
	output reg  [WIDTH-1:0] out,
	input  wire clk,
	input  wire rst
 );

	// Signals
	wire fb;

	// Linear Feedback
	assign fb = ^(out & POLY);

	// Register
	always @(posedge clk)
		if (rst)
			out <= { {(WIDTH-1){1'b0}}, 1'b1 };
		else
			out <= { fb, out[WIDTH-1:1] };

endmodule // pdm_lfsr
