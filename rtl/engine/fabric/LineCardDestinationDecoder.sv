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

/**
	@file
	@author Andrew D. Zonenberg
	@brief Port index decoder for LATENTRED

	Input stream
		TUSER is VLAN
		TDEST is
			[6] 	broadcast flag
			[5:0]	dest port

	Output stream
		TUSER is VLAN
		TDEST is
			[10]	broadcast flag
			[9:4]	dest switch port
			[3:0]	dest crossbar port bitmask
 */
module LineCardDestinationDecoder (
	AXIStream.receiver			axi_rx,
	AXIStream.transmitter		axi_tx
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Validate buses are the same size

	if(axi_rx.DATA_WIDTH != axi_tx.DATA_WIDTH)
		axi_bus_width_inconsistent();
	if(axi_rx.USER_WIDTH != axi_tx.USER_WIDTH)
		axi_bus_width_inconsistent();
	if(axi_rx.ID_WIDTH != axi_tx.ID_WIDTH)
		axi_bus_width_inconsistent();
	if(axi_rx.DEST_WIDTH != 7)
		axi_bus_width_inconsistent();
	if(axi_tx.DEST_WIDTH != 11)
		axi_bus_width_inconsistent();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pass-through on control signals

	assign axi_tx.aclk		= axi_rx.aclk;
	assign axi_tx.twakeup	= axi_rx.twakeup;
	assign axi_tx.areset_n	= axi_rx.areset_n;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pass-through on data lines

	assign axi_tx.tvalid	= axi_rx.tvalid;
	assign axi_tx.tdata		= axi_rx.tdata;
	assign axi_tx.tlast		= axi_rx.tlast;
	assign axi_tx.tstrb		= axi_rx.tstrb;
	assign axi_tx.tkeep		= axi_rx.tkeep;
	assign axi_tx.tid		= axi_rx.tid;
	assign axi_tx.tuser		= axi_rx.tuser;

	assign axi_rx.tready	= axi_tx.tready;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Decode TDEST

	logic		is_broadcast;
	logic[5:0]	dest_port;

	always_comb begin

		//Crack input fields
		is_broadcast			= axi_rx.tdest[6];
		dest_port				= axi_rx.tdest[5:0];

		//Mirror output fields
		axi_tx.tdest[10]		= is_broadcast;
		axi_tx.tdest[9:4]		= dest_port;

		//If broadcast, send to all ports
		if(is_broadcast)
			axi_tx.tdest[3:0]	= 4'b1111;

		//Unicast, decode each port individually
		else begin

			//Default to no output bits set
			axi_tx.tdest[3:0]		= 0;

			//First line card
			if(dest_port < 24)
				axi_tx.tdest[0]		= 1;

			//Second line card
			if( (dest_port >= 24) && (dest_port < 48) )
				axi_tx.tdest[1]		= 1;

			//First uplink
			if(dest_port == 48)
				axi_tx.tdest[2]		= 1;

			//Second uplink
			if(dest_port == 49)
				axi_tx.tdest[3]		= 1;

		end

	end

endmodule
