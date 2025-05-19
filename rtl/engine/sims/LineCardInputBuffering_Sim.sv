`timescale 1ns / 1ps
`default_nettype none
/***********************************************************************************************************************
*                                                                                                                      *
* LATENTRED                                                                                                            *
*                                                                                                                      *
* Copyright (c) 2012-2025 Andrew D. Zonenberg                                                                          *
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

module LineCardInputBuffering_Sim();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clocking

	//internal GSR lasts 100 ns in sim and URAM isn't ungated until then
	logic ready = 0;
	initial begin
		#110;
		ready = 1;
	end

	logic clk = 0;
	always begin
		#1;
		clk = ready;
		#1;
		clk = 0;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Packet generation

	AXIStream #(.DATA_WIDTH(32), .ID_WIDTH(0), .DEST_WIDTH(0), .USER_WIDTH(1)) eth_rx_data[23:0]();

	logic[23:0]	next = 0;

	AXIS_PcapngPacketGenerator #(
		.FILENAME("/ceph/fast/home/azonenberg/code/latentred/testdata/2tagged-2untagged.pcapng")
	) eth0_gen (
		.clk(clk),
		.next(next[0]),
		.axi_tx(eth_rx_data[0])
	);

	//Tie off all other ports
	for(genvar g=1; g<24; g++) begin
		assign eth_rx_data[g].aclk = clk;
		assign eth_rx_data[g].areset_n = 0;
		assign eth_rx_data[g].tvalid = 0;
		assign eth_rx_data[g].tdata = 0;
		assign eth_rx_data[g].tstrb = 0;
		assign eth_rx_data[g].tkeep = 0;
		assign eth_rx_data[g].tlast = 0;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	logic[11:0]	port_vlan[23:0];
	logic		drop_tagged[23:0];
	logic		drop_untagged[23:0];

	AXIStream #(.DATA_WIDTH(64), .ID_WIDTH(0), .DEST_WIDTH(0), .USER_WIDTH(1)) eth_tx_data();
	LineCardInputBuffering dut(
		.clk_fabric(clk),

		.port_vlan(port_vlan),
		.drop_tagged(drop_tagged),
		.drop_untagged(drop_untagged),

		.axi_rx_portclk(eth_rx_data),
		.axi_tx(eth_tx_data)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Testbench

	logic[7:0] state = 0;

	initial begin
		for(integer i=0; i<24; i++) begin
			port_vlan[i]		= 69;
			drop_tagged[i]		= 0;
			drop_untagged[i]	= 0;
		end
	end

	always_ff @(posedge clk) begin
		next	<= 0;

		case(state)

			0: begin
				next[0]	<= 1;
				state	<= 1;
			end

			1: begin
				if(eth_rx_data[0].tlast) begin
					next[0]	<= 1;
					state	<= 2;
				end
			end

			2: begin
				if(eth_rx_data[0].tlast) begin
					next[0]	<= 1;
					state	<= 3;
				end
			end

			3: begin
				if(eth_rx_data[0].tlast) begin
					next[0]	<= 1;
					state	<= 4;
				end
			end

		endcase

	end

endmodule
