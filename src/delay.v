/*
 * delay.v
 *
 * vim: ts=4 sw=4
 *
 * Generates a delay line/bus
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

// ---------------------------------------------------------------------------
// Single line delay
// ---------------------------------------------------------------------------

module delay_bit #(
	parameter integer DELAY = 1
)(
	input  wire d,
	output wire q,
	input  wire clk
);

	reg [DELAY-1:0] dl;

	generate
		if (DELAY > 1)
			always @(posedge clk)
				dl <= { dl[DELAY-2:0], d };
		else
			always @(posedge clk)
				dl <= d;
	endgenerate

	assign q = dl[DELAY-1];

endmodule // delay_bit


// ---------------------------------------------------------------------------
// Bus delay
// ---------------------------------------------------------------------------

module delay_bus #(
	parameter integer DELAY = 1,
	parameter integer WIDTH = 1
)(
	input  wire [WIDTH-1:0] d,
	output wire [WIDTH-1:0] q,
	input  wire clk
);

	genvar i;
	reg [WIDTH-1:0] dl[0:DELAY-1];

	always @(posedge clk)
		dl[0] <= d;

	generate
		for (i=1; i<DELAY; i=i+1)
			always @(posedge clk)
				dl[i] <= dl[i-1];
	endgenerate

	assign q = dl[DELAY-1];

endmodule // delay_bus


// ---------------------------------------------------------------------------
// Toggle delay
// ---------------------------------------------------------------------------

module delay_toggle #(
	parameter integer DELAY = 1
)(
	input  wire d,
	output wire q,
	input  wire clk
);

	// FIXME: TODO

endmodule // delay_toggle
