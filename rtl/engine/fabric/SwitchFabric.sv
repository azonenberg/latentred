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

import EthernetBus::*;

/**
	@brief Top level module for the actual switch fabric
 */
module SwitchFabric(

	//Main system clock
	input wire			clk_fabric,

	//Line card 0 receive data stream (PHY clock domain)
	AXIStream.receiver	lc0_axi_rx[23:0],

	//Line card configuration
	input wire vlan_t	lc0_port_vlan[23:0],
	input wire			lc0_port_drop_tagged[23:0],
	input wire			lc0_port_drop_untagged[23:0]
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MAC address table

	//TODO: convert to axi-stream and APB

	//TODO: arbitration on lookups

	wire		mac_lookup_en;
	vlan_t		mac_lookup_src_vlan;
	macaddr_t	mac_lookup_src_mac;
	wire[4:0]	mac_lookup_src_port;
	macaddr_t	mac_lookup_dst_mac;

	wire		mac_lookup_done;
	wire		mac_lookup_hit;
	wire[5:0]	mac_lookup_dst_port;

	//extend line card port to global port
	wire[5:0] mac_lookup_src_port_global = {1'b0, mac_lookup_src_port};

	MACAddressTable #(
		.TABLE_ROWS(2048),
		.ASSOC_WAYS(8),
		.PENDING_SIZE(8),
		.NUM_PORTS(50)
	) mactable (
		.clk(clk_fabric),

		.lookup_en(mac_lookup_en),
		.lookup_src_vlan(mac_lookup_src_vlan),
		.lookup_src_mac(mac_lookup_src_mac),
		.lookup_src_port(mac_lookup_src_port_global),
		.lookup_dst_mac(mac_lookup_dst_mac),

		.lookup_done(mac_lookup_done),
		.lookup_hit(mac_lookup_hit),
		.lookup_dst_port(mac_lookup_dst_port),

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Input buffers

	AXIStream #(.DATA_WIDTH(64), .ID_WIDTH(0), .DEST_WIDTH(7), .USER_WIDTH(12)) lc0_xbar_in();

	LineCardInputBuffering #(
		.CDC_FIFO_DEPTH(256),
		.CDC_FIFO_USE_BLOCK(1),
		.MATRIX_ID("LINECARD0")
	) lc0_rx_bufs (
		.clk_fabric(clk_fabric),

		.port_vlan(lc0_port_vlan),
		.drop_tagged(lc0_port_drop_tagged),
		.drop_untagged(lc0_port_drop_untagged),

		.mac_lookup_en(mac_lookup_en),
		.mac_lookup_src_vlan(mac_lookup_src_vlan),
		.mac_lookup_src_mac(mac_lookup_src_mac),
		.mac_lookup_src_port(mac_lookup_src_port),
		.mac_lookup_dst_mac(mac_lookup_dst_mac),
		.mac_lookup_done(mac_lookup_done),
		.mac_lookup_hit(mac_lookup_hit),
		.mac_lookup_dst_port(mac_lookup_dst_port),

		.axi_rx_portclk(lc0_axi_rx),
		.axi_tx(lc0_xbar_in)
	);

	//DEBUG: accept traffic leaving the input buffer
	assign lc0_xbar_in.tready = 1;

	//TODO: other line cards

	//TODO: uplinks

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual crossbar

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Exit queues

endmodule
