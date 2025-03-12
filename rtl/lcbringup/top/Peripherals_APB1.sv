/***********************************************************************************************************************
*                                                                                                                      *
* LATENTRED                                                                                                            *
*                                                                                                                      *
* Copyright (c) 2024-2025 Andrew D. Zonenberg and contributors                                                         *
* All rights reserved.                                                                                                 *
*                                                                                                                      *
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     *
* following conditions are met:                                                                                        *
*                                                                                                                      *
*    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         *
*      following disclaimer.                                                                                           *
*                                                                                                                      *
*    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       *
*      following disclaimer in the documentation and/or other materials provided with the distribution.                *
*                                                                                                                      *
*    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     *
*      derived from this software without specific prior written permission.                                           *
*                                                                                                                      *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   *
* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL *
* THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       *
* BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *
* POSSIBILITY OF SUCH DAMAGE.                                                                                          *
*                                                                                                                      *
***********************************************************************************************************************/

`timescale 1ns/1ps
`default_nettype none

module Peripherals_APB1(

	//APB to root bridge
	APB.completer 		apb,

	//Low speed clock for device info
	input wire			clk_25mhz,

	//GPIO LEDs
	output wire[3:0]	led,

	//MDIO and control lines to the single line card in the testbed
	output wire			mdio_tx_data,
	output wire			mdio_tx_en,
	input wire			mdio_rx_data,
	output wire			eth_mdc
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pipeline register heading up to root bridge

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(16), .USER_WIDTH(0)) apb1_root();
	APBRegisterSlice #(.DOWN_REG(0), .UP_REG(0)) regslice_apb1_root(
		.upstream(apb),
		.downstream(apb1_root));

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// We only support 32-bit APB, throw synthesis error for anything else

	if(apb.DATA_WIDTH != 32)
		apb_bus_width_is_invalid();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// APB bridge for peripherals on this bus

	localparam NUM_PERIPHERALS	= 4;
	localparam BLOCK_SIZE		= 32'h400;
	localparam ADDR_WIDTH		= $clog2(BLOCK_SIZE);
	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH), .USER_WIDTH(0)) apb1[NUM_PERIPHERALS-1:0]();
	APBBridge #(
		.BASE_ADDR(32'h0000_0000),
		.BLOCK_SIZE(BLOCK_SIZE),
		.NUM_PORTS(NUM_PERIPHERALS)
	) bridge (
		.upstream(apb1_root),
		.downstream(apb1)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GPIO core (c000_0000)

	wire[31:0]	gpioa_out;
	wire[31:0]	gpioa_in;
	wire[31:0]	gpioa_tris;

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH), .USER_WIDTH(0)) apb_gpioa();
	APBRegisterSlice #(.DOWN_REG(1), .UP_REG(1)) regslice_apb_gpioa(
		.upstream(apb1[0]),
		.downstream(apb_gpioa));

	APB_GPIO gpioA(
		.apb(apb_gpioa),

		.gpio_out(gpioa_out),
		.gpio_in(gpioa_in),
		.gpio_tris(gpioa_tris)
	);

	//tie off unused bits
	assign gpioa_in[23:7] = 0;

	//LEDs
	assign led				= gpioa_out[3:0];
	assign gpioa_in[3:0]	= led;
	/*
	//Ethernet
	assign eth_rst_n		= gpioa_out[4];
	assign gpioa_in[4]		= eth_rst_n;
	assign gpioa_in[5]		= rgmii_link_up_core;
	assign gpioa_in[6]		= rx_frame_ready;

	//PMOD GPIOs
	for(genvar g=0; g<8; g++) begin : pmod
		IOBUF iobuf(
			.I(gpioa_out[24+g]),
			.O(gpioa_in[24+g]),
			.T(!gpioa_tris[24+g]),
			.IO(pmod_gpio[g]));
	end
	*/

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Device information (c000_0400)

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH), .USER_WIDTH(0)) apb_devinfo();
	APBRegisterSlice #(.DOWN_REG(0), .UP_REG(1)) regslice_apb_devinfo(
		.upstream(apb1[1]),
		.downstream(apb_devinfo));

	APB_DeviceInfo_7series devinfo(
		.apb(apb_devinfo),
		.clk_dna(clk_25mhz),
		.clk_icap(clk_25mhz) );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MDIO transciever (c000_0800)

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH), .USER_WIDTH(0)) apb_mdio();
	APBRegisterSlice #(.DOWN_REG(1), .UP_REG(1)) regslice_apb_mdio(
		.upstream(apb1[2]),
		.downstream(apb_mdio));

	APB_MDIO_ExternalTristate #(
		.CLK_DIV(125)
	) mdio (
		.apb(apb_mdio),

		.mdio_tx_en(mdio_tx_en),
		.mdio_tx_data(mdio_tx_data),
		.mdio_rx_data(mdio_rx_data),
		.mdc(eth_mdc)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// XADC for on-die sensors (c000_1000)

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH), .USER_WIDTH(0)) apb_xadc();
	APBRegisterSlice #(.DOWN_REG(1), .UP_REG(1)) regslice_apb_xadc(
		.upstream(apb1[3]),
		.downstream(apb_xadc));

	APB_XADC xadc(.apb(apb_xadc));

endmodule

