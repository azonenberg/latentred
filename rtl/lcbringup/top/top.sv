`timescale 1ns/1ps
`default_nettype none
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

module top(

	//Main system clock
	input wire			clk_25mhz,

	//FMC pins to MCU for APB interface
	input wire			fmc_clk,
	output wire			fmc_nwait,
	input wire			fmc_noe,
	inout wire[15:0]	fmc_ad,
	input wire			fmc_nwe,
	input wire[1:0]		fmc_nbl,
	input wire			fmc_nl_nadv,
	input wire[9:0]		fmc_a_hi,
	input wire			fmc_ne3,
	input wire			fmc_ne2,
	input wire			fmc_ne1,

	//MDIO to line card
	output wire			eth_mdc,
	inout wire			mdio,
	output wire			mdio_tx_en,

	//GPIO LEDs
	output wire[3:0]	led
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock synthesis

	wire	clk_125mhz;

	ClockGeneration clkgen(
		.clk_25mhz(clk_25mhz),
		.clk_125mhz(clk_125mhz)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FMC to APB bridge

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(25), .USER_WIDTH(0)) fmc_apb();
	APB #(.DATA_WIDTH(64), .ADDR_WIDTH(20), .USER_WIDTH(0)) fmc_apb64();

	FMC_APBBridge #(
		.CLOCK_PERIOD(6.66),	//150 MHz
		.VCO_MULT(8),			//1.25 GHz VCO
		.CAPTURE_CLOCK_PHASE(-30),
		.LAUNCH_CLOCK_PHASE(-60),
		.BASE_X64(32'h0080_0000)
	) fmcbridge(

		.apb_x32(fmc_apb),
		.apb_x64(fmc_apb64),

		.clk_mgmt(clk_125mhz),

		.fmc_clk(fmc_clk),
		.fmc_nwait(fmc_nwait),
		.fmc_noe(fmc_noe),
		.fmc_ad(fmc_ad),
		.fmc_nwe(fmc_nwe),
		.fmc_nbl(fmc_nbl),
		.fmc_nl_nadv(fmc_nl_nadv),
		.fmc_a_hi({2'b0, fmc_a_hi[7:0]}),	//A24 is acting funny, not sure why. for now ignore it
											//TODO: this was on a different board
		.fmc_cs_n(fmc_ne1)
	);

	/*
	//Bridge the 64-bit APB to 32 bit
	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(20), .USER_WIDTH(0)) fmc_apb64_to32_raw();
	APB_WriteBuffer64To32 wbuf64(
		.up(fmc_apb64),
		.down(fmc_apb64_to32_raw)
	);

	//Pipeline stage for timing
	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(20), .USER_WIDTH(0)) fmc_apb64_to32();
	APBRegisterSlice #(.DOWN_REG(1), .UP_REG(1)) regslice_apb_root64(
		.upstream(fmc_apb64_to32_raw),
		.downstream(fmc_apb64_to32));
	*/

	//Pipeline stage for timing
	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(25), .USER_WIDTH(0)) fmc_apb_pipe();
	APBRegisterSlice #(.DOWN_REG(0), .UP_REG(1)) regslice_apb_root(
		.upstream(fmc_apb),
		.downstream(fmc_apb_pipe));

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// APB root bridge

	//TODO: we need to make a giant segment for the KU+ first

	//TODO: very large segment for hyperram? or do we want to add AHB or something for that?

	//Two 16-bit bus segments at 0xc000_0000 (APB1) and c001_0000 (APB2) for core peripherals
	//APB1 has 1 kB address space per peripheral and is for small stuff
	//APB2 has 4 kB address space per peripheral and is only used for Ethernet
	//APB3/4/5/6 segments are allocated to each of the I/O ports and contain all of the flash controllers etc
	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(23), .USER_WIDTH(0)) rootAPB[1:0]();

	//Root bridge
	APBBridge #(
		.BASE_ADDR(32'h0000_0000),	//MSBs are not sent over FMC so we set to zero on our side
		.BLOCK_SIZE(32'h10_0000),
		.NUM_PORTS(2)
	) root_bridge (
		.upstream(fmc_apb_pipe),
		.downstream(rootAPB)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Peripherals on APB1 bus (0x0xc000_0000)

	wire	mdio_tx_en_int;
	wire	mdio_tx_data;
	wire	mdio_rx_data;

	BidirectionalBuffer mdio_obuf(
		.fabric_in(mdio_rx_data),
		.fabric_out(mdio_tx_data),
		.pad(mdio),
		.oe(mdio_tx_en_int)
	);

	Peripherals_APB1 apb1(
		.apb(rootAPB[0]),

		.clk_25mhz(clk_25mhz),

		.led(led),

		.mdio_tx_en(mdio_tx_en_int),
		.mdio_tx_data(mdio_tx_data),
		.mdio_rx_data(mdio_rx_data),
		.eth_mdc(eth_mdc)
	);

	//invert polarity to match external level shifter DIR signal requirements
	assign mdio_tx_en = !mdio_tx_en_int;

endmodule
