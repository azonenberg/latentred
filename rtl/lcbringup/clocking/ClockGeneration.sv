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

module ClockGeneration(
	input wire	clk_25mhz,

	output wire	clk_125mhz
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock synthesis PLL for various internal domains

	wire	clk_125mhz_raw;
	wire	pll_lock;
	wire	clk_fb;

	PLLE2_BASE #(
		.BANDWIDTH("OPTIMIZED"),
		.CLKFBOUT_MULT(40),	//1 GHz VCO
		.DIVCLK_DIVIDE(1),
		.CLKFBOUT_PHASE(0),
		.CLKIN1_PERIOD(40),
		.STARTUP_WAIT("FALSE"),

		.CLKOUT0_DIVIDE(8),		//125 MHz
		.CLKOUT1_DIVIDE(5),
		.CLKOUT2_DIVIDE(5),
		.CLKOUT3_DIVIDE(5),
		.CLKOUT4_DIVIDE(5),
		.CLKOUT5_DIVIDE(5),

		.CLKOUT0_PHASE(0),
		.CLKOUT1_PHASE(0),
		.CLKOUT2_PHASE(0),
		.CLKOUT3_PHASE(0),
		.CLKOUT4_PHASE(0),
		.CLKOUT5_PHASE(0),

		.CLKOUT0_DUTY_CYCLE(0.5),
		.CLKOUT1_DUTY_CYCLE(0.5),
		.CLKOUT2_DUTY_CYCLE(0.5),
		.CLKOUT3_DUTY_CYCLE(0.5),
		.CLKOUT4_DUTY_CYCLE(0.5),
		.CLKOUT5_DUTY_CYCLE(0.5)
	) pll (
		.CLKIN1(clk_25mhz),
		.CLKFBIN(clk_fb),
		.CLKFBOUT(clk_fb),
		.RST(1'b0),
		.CLKOUT0(clk_125mhz_raw),
		.CLKOUT1(),
		.CLKOUT2(),
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.LOCKED(pll_lock),
		.PWRDWN(0)
	);

	BUFGCE bufg_clk_125mhz(
		.I(clk_125mhz_raw),
		.O(clk_125mhz),
		.CE(pll_lock)
	);

endmodule
