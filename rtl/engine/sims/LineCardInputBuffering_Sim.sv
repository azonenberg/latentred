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

	for(genvar g=0; g<24; g++) begin

		//Hook up stuff
		if(g == 1) begin
			AXIS_PcapngPacketGenerator #(
				.FILENAME("/ceph/fast/home/azonenberg/code/latentred/testdata/ping-host1.pcapng")
			) host1_gen (
				.clk(clk),
				.next(next[1]),
				.axi_tx(eth_rx_data[1])
			);
		end

		else if(g == 2) begin
			AXIS_PcapngPacketGenerator #(
				.FILENAME("/ceph/fast/home/azonenberg/code/latentred/testdata/ping-host2.pcapng")
			) host2_gen (
				.clk(clk),
				.next(next[2]),
				.axi_tx(eth_rx_data[2])
			);
		end

		//Tie off all other ports
		else begin
			assign eth_rx_data[g].aclk = clk;
			assign eth_rx_data[g].areset_n = 0;
			assign eth_rx_data[g].tvalid = 0;
			assign eth_rx_data[g].tdata = 0;
			assign eth_rx_data[g].tstrb = 0;
			assign eth_rx_data[g].tkeep = 0;
			assign eth_rx_data[g].tlast = 0;
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	logic[11:0]	port_vlan[23:0];
	logic		drop_tagged[23:0];
	logic		drop_untagged[23:0];

	//Interface from line card buffer to the MAC table
	AXIStream #(.DATA_WIDTH(114), .ID_WIDTH(5), .DEST_WIDTH(2), .USER_WIDTH(0)) eth_mac_lookup();
	AXIStream #(.DATA_WIDTH(6), .ID_WIDTH(5), .DEST_WIDTH(2), .USER_WIDTH(1)) eth_mac_results();

	//Data to the crossbar
	AXIStream #(.DATA_WIDTH(64), .ID_WIDTH(0), .DEST_WIDTH(7), .USER_WIDTH(12)) eth_tx_data();
	wire[9:0]	xbar_fifo_wsize;
	LineCardInputBuffering #(
		.BASE_PORT(0),
		.XBAR_PORT(0)
	) dut (
		.clk_fabric(clk),

		.port_vlan(port_vlan),
		.drop_tagged(drop_tagged),
		.drop_untagged(drop_untagged),

		.axi_lookup(eth_mac_lookup),
		.axi_results(eth_mac_results),

		.axi_rx_portclk(eth_rx_data),
		.axi_tx(eth_tx_data),
		.xbar_fifo_wsize(xbar_fifo_wsize)
	);

	MACAddressTable #(
		.TABLE_ROWS(2048),
		.ASSOC_WAYS(8),
		.PENDING_SIZE(8),
		.NUM_PORTS(50)
	) mactable (
		.axi_lookup(eth_mac_lookup),
		.axi_results(eth_mac_results),

		//management interface not used
		.gc_en(1'b0),
		.gc_done(),
		.mgmt_rd_en(1'b0),
		.mgmt_del_en(1'b0),
		.mgmt_ack(),
		.mgmt_addr(11'h0),
		.mgmt_way(),
		.mgmt_rd_valid(),
		.mgmt_rd_gc_mark(),
		.mgmt_rd_mac(),
		.mgmt_rd_vlan(),
		.mgmt_rd_port()
	);

	//Combinatorial decoding of TDEST
	AXIStream #(.DATA_WIDTH(64), .ID_WIDTH(0), .DEST_WIDTH(11), .USER_WIDTH(12)) decode_tx_data();
	LineCardDestinationDecoder decoder(
		.axi_rx(eth_tx_data),
		.axi_tx(decode_tx_data)
	);

	//Output FIFO (single BRAM)
	AXIStream #(.DATA_WIDTH(64), .ID_WIDTH(0), .DEST_WIDTH(11), .USER_WIDTH(12)) fifo_tx_data();
	AXIS_FIFO #(
		.FIFO_DEPTH(512),
		.USE_BLOCK(1)
	) outfifo (
		.axi_rx(decode_tx_data),
		.axi_tx(fifo_tx_data),
		.wr_size(xbar_fifo_wsize)
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

		fifo_tx_data.tready	= 0;
	end

	logic[7:0] count = 0;

	always_ff @(posedge clk) begin

		next				<= 0;

		case(state)

			//Request
			0: begin
				next[1]	<= 1;
				state	<= 1;
			end

			//Reply
			1: begin
				if(eth_rx_data[1].tlast) begin
					next[2]	<= 1;
					state	<= 2;
				end
			end

			//wait until second frame is buffered etc
			2: begin
				if(eth_rx_data[2].tlast) begin
					state	<= 3;
					count	<= 0;
				end
			end

			//ungate fabric
			3: begin
				count	<= count + 1;
				if(count == 31) begin
					state				<= 4;
					fifo_tx_data.tready	<= 1;
				end
			end

			//Two simultaneous packets?

			/*
			2: begin
				if(eth_rx_data[1].tlast) begin
					next[1]	<= 1;
					state	<= 3;
				end
			end

			3: begin
				if(eth_rx_data[1].tlast) begin
					next[1]	<= 1;
					state	<= 4;
				end
			end*/

		endcase

	end

endmodule
