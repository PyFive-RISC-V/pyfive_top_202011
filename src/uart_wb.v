/*
 * uart_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019-2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module uart_wb #(
	parameter integer DIV_WIDTH = 8,
	parameter integer DW = 16
)(
	// UART
	output wire uart_tx,
	input  wire uart_rx,

	// Bus interface
	input  wire [1:0]    wb_addr,
	output wire [DW-1:0] wb_rdata,
	input  wire [DW-1:0] wb_wdata,
	input  wire          wb_we,
	input  wire          wb_cyc,
	output wire          wb_ack,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// RX fifo
	wire [ 7:0] urf_wdata;
	wire        urf_wren;
	wire        urf_full;
	wire [ 7:0] urf_rdata;
	wire        urf_rden;
	wire        urf_empty;

	reg         urf_overflow;
	wire        urf_overflow_clr;

	// TX fifo
	wire [ 7:0] utf_wdata;
	wire        utf_wren;
	wire        utf_full;
	wire [ 7:0] utf_rdata;
	wire        utf_rden;
	wire        utf_empty;

	// TX core
	wire [ 7:0] uart_tx_data;
	wire        uart_tx_valid;
	wire        uart_tx_ack;

	// RX core
	wire [ 7:0] uart_rx_data;
	wire        uart_rx_stb;

	// CSR
	reg  [DIV_WIDTH-1:0] uart_div;

	// Bus IF
	wire          ub_rdata_rst;
	reg  [DW-1:0] ub_rdata;
	reg           ub_rd_data;
	reg           ub_rd_ctrl;
	reg           ub_wr_data;
	reg           ub_wr_div;
	reg           ub_ack;


	// TX Core
	// -------

	uart_tx #(
		.DIV_WIDTH(DIV_WIDTH)
	) uart_tx_I (
		.data(uart_tx_data),
		.valid(uart_tx_valid),
		.ack(uart_tx_ack),
		.tx(uart_tx),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);


	// TX FIFO
	// -------

	fifo_sync_shift #(
		.DEPTH(8),
		.WIDTH(8)
	) uart_tx_fifo_I (
		.wr_data(utf_wdata),
		.wr_ena(utf_wren),
		.wr_full(utf_full),
		.rd_data(utf_rdata),
		.rd_ena(utf_rden),
		.rd_empty(utf_empty),
		.clk(clk),
		.rst(rst)
	);

	// TX glue
	assign uart_tx_data  =  utf_rdata;
	assign uart_tx_valid = ~utf_empty;
	assign utf_rden      =  uart_tx_ack;


	// RX Core
	// -------

	uart_rx #(
		.DIV_WIDTH(DIV_WIDTH),
		.GLITCH_FILTER(2)
	) uart_rx_I (
		.rx(uart_rx),
		.data(uart_rx_data),
		.stb(uart_rx_stb),
		.div(uart_div),
		.clk(clk),
		.rst(rst)
	);


	// RX FIFO
	// -------

	fifo_sync_shift #(
		.DEPTH(8),
		.WIDTH(8)
	) uart_rx_fifo_I (
		.wr_data(urf_wdata),
		.wr_ena(urf_wren),
		.wr_full(urf_full),
		.rd_data(urf_rdata),
		.rd_ena(urf_rden),
		.rd_empty(urf_empty),
		.clk(clk),
		.rst(rst)
	);

	// RX glue
	assign urf_wdata = uart_rx_data;
	assign urf_wren  = uart_rx_stb & ~urf_full;

	// Overflow
	always @(posedge clk or posedge rst)
		if (rst)
			urf_overflow <= 1'b0;
		else
			urf_overflow <= (urf_overflow & ~urf_overflow_clr) | (uart_rx_stb & urf_full);


	// Bus interface
	// -------------

	always @(posedge clk)
		if (ub_ack) begin
			ub_rd_data <= 1'b0;
			ub_rd_ctrl <= 1'b0;
			ub_wr_data <= 1'b0;
			ub_wr_div  <= 1'b0;
		end else begin
			ub_rd_data <= ~wb_we & wb_cyc & (wb_addr == 2'b00);
			ub_rd_ctrl <= ~wb_we & wb_cyc & (wb_addr == 2'b01);
			ub_wr_data <=  wb_we & wb_cyc & (wb_addr == 2'b00) & ~utf_full;
			ub_wr_div  <=  wb_we & wb_cyc & (wb_addr == 2'b01);
		end

	always @(posedge clk)
		if (ub_ack)
			ub_ack <= 1'b0;
		else
			ub_ack <= wb_cyc & (~wb_we | (wb_addr == 2'b01) | ~utf_full);

	assign ub_rdata_rst = ub_ack | wb_we | ~wb_cyc;

	always @(posedge clk)
		if (ub_rdata_rst)
			ub_rdata <= { DW{1'b0} };
		else
			ub_rdata <= wb_addr[0] ?
				{ urf_empty, urf_overflow, utf_empty, utf_full, { (DW-DIV_WIDTH-4){1'b0} }, uart_div } :
				{ urf_empty, { (DW-9){1'b0} }, urf_rdata };

	always @(posedge clk)
		if (ub_wr_div)
			uart_div <= wb_wdata[DIV_WIDTH-1:0];

	assign utf_wdata = wb_wdata[7:0];
	assign utf_wren  = ub_wr_data;

	assign urf_rden  = ub_rd_data & ~ub_rdata[DW-1];
	assign urf_overflow_clr = ub_rd_ctrl & ub_rdata[DW-2];

	assign wb_rdata = ub_rdata;
	assign wb_ack = ub_ack;

endmodule // uart_wb
