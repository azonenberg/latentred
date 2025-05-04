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

	//SFP+ signals
	input wire			gtp_refclk_p,
	input wire			gtp_refclk_n,

	input wire			sfp_rx_p,
	input wire			sfp_rx_n,

	output wire			sfp_tx_p,
	output wire			sfp_tx_n,

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
		.fmc_a_hi(fmc_a_hi[9:0]),
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
	// Peripherals on APB1 bus (0xc000_0000)

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GTP using the wizard

	wire	gtp_tx_mmcm_lock;
	wire	gtp_rx_mmcm_lock;
	wire	gtp_tx_reset_done;
	wire	gtp_rx_reset_done;

	wire	gtp_txusrclk;
	wire	gtp_txusrclk2;

	wire	gtp_rxusrclk;
	wire	gtp_rxusrclk2;

	wire[31:0]	gtp_rx_data;
	wire[31:0]	gtp_rx_charisk;

	wire[31:0]	gtp_tx_data;
	wire[31:0]	gtp_tx_charisk;

	wire		gtp_lane_rx_reset_done;

	wire[4:0]	gtp_tx_postcursor = 5'h0;
	wire[4:0]	gtp_tx_precursor = 5'h4;
	wire[3:0]	gtp_tx_diffctrl = 5'h8;

	wire		gtp_lane_tx_reset_done;
	wire[3:0]	gtp_lane_rxcommadet;
	wire		gtp_lane_rxbyteisaligned;
	wire		gtp_lane_rxbyterealign;

	gtwizard_0  gtwizard_0_i
	(
		.soft_reset_tx_in(0),
		.soft_reset_rx_in(0),
		.dont_reset_on_data_error_in(1),
		.q0_clk0_gtrefclk_pad_n_in(gtp_refclk_n),
		.q0_clk0_gtrefclk_pad_p_in(gtp_refclk_p),
		.gt0_tx_mmcm_lock_out(gtp_tx_mmcm_lock),
		.gt0_rx_mmcm_lock_out(gtp_rx_mmcm_lock),
		.gt0_tx_fsm_reset_done_out(gtp_tx_reset_done),
		.gt0_rx_fsm_reset_done_out(gtp_rx_reset_done),
		.gt0_data_valid_in(1'b1),

		.gt0_txusrclk_out(gtp_txusrclk),
		.gt0_txusrclk2_out(gtp_txusrclk2),
		.gt0_rxusrclk_out(gtp_rxusrclk),
		.gt0_rxusrclk2_out(gtp_rxusrclk2),

		.gt0_drpaddr_in                 (9'h0),
		.gt0_drpdi_in                   (16'h0),
		.gt0_drpdo_out                  (),
		.gt0_drpen_in                   (1'b0),
		.gt0_drprdy_out                 (),
		.gt0_drpwe_in                   (1'b0),

		.gt0_eyescanreset_in            (1'b0),
		.gt0_rxuserrdy_in               (gtp_rx_mmcm_lock),

		.gt0_eyescandataerror_out       (),
		.gt0_eyescantrigger_in          (1'b0),

		.gt0_rxdata_out                 (gtp_rx_data),
		.gt0_rxcharisk_out              (gtp_rx_charisk),
		.gt0_rxcommadet_out				(gtp_lane_rxcommadet),
		.gt0_rxbyteisaligned_out		(gtp_lane_rxbyteisaligned),
		.gt0_rxbyterealign_out			(gtp_lane_rxbyterealign),

		.gt0_gtprxn_in                  (sfp_rx_n),
		.gt0_gtprxp_in                  (sfp_rx_p),

		.gt0_dmonitorout_out            (),

		.gt0_rxlpmhfhold_in             (1'b0),
		.gt0_rxlpmlfhold_in             (1'b0),

		.gt0_rxoutclkfabric_out         (),

		.gt0_gtrxreset_in               (1'b0),
		.gt0_rxlpmreset_in              (1'b0),

		.gt0_rxresetdone_out            (gtp_lane_rx_reset_done),

		//rx invert
		.gt0_rxpolarity_in				(1'b0),

		.gt0_txpostcursor_in            (gtp_tx_postcursor),
		.gt0_txprecursor_in             (gtp_tx_precursor),

		.gt0_gttxreset_in               (1'b0),
		.gt0_txuserrdy_in               (gtp_tx_mmcm_lock),

		.gt0_txcharisk_in				(gtp_tx_charisk),
		.gt0_txdata_in                  (gtp_tx_data),

		.gt0_gtptxn_out                 (sfp_tx_n),
		.gt0_gtptxp_out                 (sfp_tx_p),
		.gt0_txdiffctrl_in              (gtp_tx_diffctrl),

		.gt0_txoutclkfabric_out         (),
		.gt0_txoutclkpcs_out            (),

		.gt0_txresetdone_out            (gtp_lane_tx_reset_done),

		.gt0_pll0reset_out(),
		.gt0_pll0outclk_out(),
		.gt0_pll0outrefclk_out(),
		.gt0_pll0lock_out(),
		.gt0_pll0refclklost_out(),
		.gt0_pll1outclk_out(),
		.gt0_pll1outrefclk_out(),

		.sysclk_in(clk_25mhz)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shift comma alignment to the correct position (we have a 32 bit bus but internal datapath is 16 bit)

	wire[3:0]	gtp_rx_charisk_aligned;
	wire[31:0]	gtp_rx_data_aligned;

	BlockAligner8b10b aligner(
		.clk(gtp_rxusrclk2),

		.kchar_in(gtp_rx_charisk),
		.data_in(gtp_rx_data),

		.kchar_out(gtp_rx_charisk_aligned),
		.data_out(gtp_rx_data_aligned)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Bridge to KU+ (0xc010_0000)

	APB #(.DATA_WIDTH(32), .ADDR_WIDTH(32), .USER_WIDTH(0)) apb_req();

	wire	tx_ll_link_up;
	wire	rx_ll_link_up;

	SCCB_APBBridge #(
		.SYMBOL_WIDTH(4),
		.TX_CDC_BYPASS(1'b0)
	) bridge (

		.rx_clk(gtp_rxusrclk2),
		.rx_kchar(gtp_rx_charisk_aligned),
		.rx_data(gtp_rx_data_aligned),
		.rx_data_valid(1'b1),
		.rx_ll_link_up(rx_ll_link_up),

		.tx_clk(gtp_txusrclk2),
		.tx_kchar(gtp_tx_charisk),
		.tx_data(gtp_tx_data),
		.tx_ll_link_up(tx_ll_link_up),

		.apb_req(apb_req),
		.apb_comp(rootAPB[1])
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug ILA

	ila_0 ila(
		.clk(fmc_apb.pclk),
		.probe0(fmc_apb.psel),
		.probe1(fmc_apb.penable),
		.probe2(fmc_apb.pwrite),
		.probe3(fmc_apb.pready),
		.probe4(rootAPB[1].penable),
		.probe5(rootAPB[1].psel),
		.probe6(rootAPB[1].pready),
		.probe7(tx_ll_link_up),
		.probe8(fmc_apb.paddr),
		.probe9(fmc_apb.pwdata),
		.probe10(fmc_apb.prdata)
	);

endmodule
