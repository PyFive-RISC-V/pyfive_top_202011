/*
 * vid_top_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module vid_top_tb;

	// Signals
	// -------

	// Clock / Reset
	reg rst = 1;
	reg clk = 1;

	// DUT
	wire [ 3:0] data;
	wire        vsync;
	wire        hsync;
	wire        de;

	reg  [15:0] wb_addr;
	wire [31:0] wb_rdata;
	reg  [31:0] wb_wdata;
	reg  [ 3:0] wb_wmsk;
	reg         wb_we;
	reg         wb_cyc;
	wire        wb_ack;


	// Test bench setup
	// ----------------

	// Setup recording
	initial begin
		$dumpfile("vid_top_tb.vcd");
		$dumpvars(0,vid_top_tb);
	end

	// Reset pulse
	initial begin
		# 31 rst = 0;
		# 200000 $finish;
	end

	// Clocks
	always #10 clk = !clk;


	// DUT
	// ---

	vid_top dut_I (
		.data     (data),
		.vsync    (vsync),
		.hsync    (hsync),
		.de       (de),
		.wb_addr  (wb_addr),
		.wb_rdata (wb_rdata),
		.wb_wdata (wb_wdata),
		.wb_wmsk  (wb_wmsk),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc),
		.wb_ack   (wb_ack),
		.clk      (clk),
		.rst      (rst)
	);


	task wb_write;
		input [15:0] addr;
		input [31:0] data;
		begin
			wb_addr  <= addr;
			wb_wdata <= data;
			wb_wmsk  <= 4'h0;
			wb_we    <= 1'b1;
			wb_cyc   <= 1'b1;

			@(posedge clk);
			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 16'hxxxx;
			wb_wdata <= 32'hxxxxxxxx;
			wb_wmsk  <= 4'hx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;
		end
	endtask

	task wb_read;
		input [15:0] addr;
		begin
			wb_addr  <= addr;
			wb_we    <= 1'b0;
			wb_cyc   <= 1'b1;

			@(posedge clk);
			while (~wb_ack)
				@(posedge clk);

			wb_addr  <= 16'hxxxx;
			wb_we    <= 1'bx;
			wb_cyc   <= 1'b0;
        end
    endtask

	initial
	begin : cfg
		// Init
		wb_addr  <= 16'hxxxx;
		wb_wdata <= 32'hxxxxxxxx;
		wb_wmsk  <= 4'hx;
		wb_we    <= 1'bx;
		wb_cyc   <= 1'b0;

		@(negedge rst);
		@(posedge clk);

		// Core init
			// Timing generator
		wb_write(16'h4000, 32'h40000003);	// Sync
		wb_write(16'h4001, 32'h00000007);	// BP
		wb_write(16'h4002, 32'h2000000b);	// Border
		wb_write(16'h4003, 32'h3000001f);	// Active
		wb_write(16'h4004, 32'h2000000b);	// Border
		wb_write(16'h4005, 32'h80000007);	// FP

		wb_write(16'h4008, 32'h40000003);	// Sync
		wb_write(16'h4009, 32'h00000007);	// BP
		wb_write(16'h400a, 32'h2000000b);	// Border
		wb_write(16'h400b, 32'h3000001f);	// Active
		wb_write(16'h400c, 32'h2000000b);	// Border
		wb_write(16'h400d, 32'h80000007);	// FP

			// Write char 1
		wb_write(16'h8002, 32'h55555555);
		wb_write(16'h8003, 32'h00000000);

			// Write screen line 1, char 2
		wb_write(16'hc012, 32'h00000100);
		wb_write(16'hc01e, 32'h00000040);

			// Palette
		wb_write(16'h6000, 32'h00000004);
		wb_write(16'h6001, 32'h00000006);

			// Start
		wb_write(16'h0000, 32'h8000a001);
	end

endmodule
