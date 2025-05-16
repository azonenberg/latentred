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

module AXIS_VlanTagDecoder_Sim();

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

	AXIStream #(.DATA_WIDTH(32), .ID_WIDTH(0), .DEST_WIDTH(0), .USER_WIDTH(1)) eth_tx_data();

	logic	next = 0;

	AXIS_PcapngPacketGenerator #(
		.FILENAME("/ceph/fast/home/azonenberg/code/latentred/testdata/2tagged-2untagged.pcapng")
	) gen (
		.clk(clk),
		.next(next),
		.axi_tx(eth_tx_data)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// VLAN tag decode logic

	AXIStream #(.DATA_WIDTH(32), .ID_WIDTH(0), .DEST_WIDTH(12), .USER_WIDTH(1)) decoded();

	logic	drop_tagged = 0;
	logic	drop_untagged = 0;

	AXIS_VLANTagDecoder decoder(
		.axi_rx(eth_tx_data),
		.axi_tx(decoded),

		.port_vlan(12'd42),
		.drop_tagged(drop_tagged),
		.drop_untagged(drop_untagged)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test control

	initial begin
		decoded.tready = 0;
	end

	logic[7:0] state = 0;

	always_ff @(posedge clk) begin

		next				<= 0;
		decoded.tready	<= 1;

		case(state)

			//Send the first (tagged) packet
			0: begin
				next	<= 1;
				state	<= 1;
			end

			1: begin
				if(eth_tx_data.tlast) begin
					next		<= 1;
					state		<= 2;
					drop_tagged	<= 1;
				end
			end

			2: begin
				if(eth_tx_data.tlast) begin
					next		<= 1;
					state		<= 3;
				end
			end

			3: begin
				if(eth_tx_data.tlast) begin
					next			<= 1;
					state			<= 3;
					drop_tagged		<= 0;
					drop_untagged	<= 1;
				end
			end

		endcase

	end

endmodule
