`default_nettype none
`timescale 1ns/1ps
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
	@file
	@author Andrew D. Zonenberg
	@brief MAC address table

	SUMMARY / USAGE

		Fully pipelined MAC table with VLAN support, address learning, and garbage collection.

		Default configuration is 8 ways * 2048 rows * ~66 bits per port
		One RAMB36 is 2K x 18, so we need 4 BRAMs per way or 32 BRAMs for the entire table

		Fixed latency, no flow control support.

	PERFORMANCE
		A single Ethernet frame can be a minimum size of 8 bytes preamble/SFD, 64 bytes frame, plus 12 of IFG which
		comes out to a total of 84 bytes * 8 bits = 672 UIs. This comes out to 1.488 Mpps/Gbps.

		We target a sustained throughput of 1 clock per packet with a fixed latency from request to reply. This gives
		us a maximum forwarding throughput of 1 Mpps/MHz (However, running at the theoretical forwarding limit will
		prevent table bandwidth from being available for learning new addresses and garbage-collecting old ones.)

		LATENTRED has 48x 1 Gbps + 2x 25 Gbps = 98 Gbps of max forwarding throughput, or 145.824 Mpps.
		So we need to clock the MAC table at at least 146 MHz.

	THEORY OF OPERATION

		The table is organized as a set-associative cache, indexed by a simple XOR hash of the MAC address. Replacement
		policy is random.

		The MAC table memory is dual ported, with table lookups and learning/garbage collection/management operations
		occurring simultaneously on different ports.

		When a packet comes in, the destination address is looked up on one port while the source is looked up on
		another. After the lookup completes the external interface is presented with the destination results.

		On the internal port, if the source address was found to not be in the table, the address/port tuple are added
		to a FIFO of learned MAC addresses. If the FIFO is full, the address will not be learned.

		Any cycle that a table lookup is not in progress, the learning FIFO is popped and the learned addresses are
		saved in the main address table.

		Old addresses are removed by a mark-and-sweep garbage collector. The mark is set any time a packet from that
		address is forwarded. When a GC is requested by the host system, all un-marked addresses are erased and all
		marked addresses are un-marked.

		TODO: allow management interface to "pin" table entries so they can't be GC'd

	AXI INTERFACE conventions
		Common
			Single words (must always have TLAST asserted when TVALID is asserted)
			TSTRB/TKEEP ignored
			TID is port index for line cards and will be echoed to the reply
			TDEST is crossbar port (line card or uplink index) making the request and will be echoed to the reply

		Request stream
			TDATA is {src port, src vlan, src mac, dst mac }
			TUSER is ignored

		Reply stream
			TDATA is dest port
			TUSER is hit flag (1=hit, 0=miss)
 */
module MACAddressTable #(
	parameter TABLE_ROWS	= 2048,				//Number of rows in each set
	parameter ASSOC_WAYS	= 8,				//Number of associative sets
	parameter PENDING_SIZE	= 8,				//Number of addresses that can be pending write to the table

	parameter NUM_PORTS		= 50,
	localparam PORT_BITS	= $clog2(NUM_PORTS),

	localparam ROW_BITS		= $clog2(TABLE_ROWS),
	localparam ASSOC_BITS	= $clog2(ASSOC_WAYS)
)(
	AXIStream.receiver			axi_lookup,
	AXIStream.transmitter		axi_results,

	//TODO: convert management interface to APB in same clock domain
	input wire					gc_en,					//assert for one clock to start garbage collection
	output logic				gc_done			= 0,	//goes high at end of garbage collection

	input wire					mgmt_rd_en,				//Read a table row from the management interface
	input wire					mgmt_del_en,			//Wipe a table row from the management interface
	output logic				mgmt_ack		= 0,	//goes high for one cycle upon completion of a mgmt operation
	input wire[ROW_BITS-1:0]	mgmt_addr,
	input wire[ASSOC_BITS-1:0]	mgmt_way,
	output logic				mgmt_rd_valid	= 0,
	output logic				mgmt_rd_gc_mark	= 0,
	output macaddr_t			mgmt_rd_mac		= 0,
	output vlan_t				mgmt_rd_vlan	= 0,
	output logic[PORT_BITS-1:0]	mgmt_rd_port	= 0
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Hook up AXI control signals

	assign axi_results.aclk		= axi_lookup.aclk;
	assign axi_results.areset_n	= axi_lookup.areset_n;
	assign axi_results.twakeup	= 1;

	//always ready for stuff
	assign axi_lookup.tready	= 1;

	initial begin
		axi_results.areset_n	= 0;
		axi_results.tvalid		= 0;
		axi_results.tdata		= 0;
		axi_results.tkeep		= 0;
		axi_results.tstrb		= 0;
		axi_results.tdest		= 0;
		axi_results.tuser		= 0;
		axi_results.tlast		= 0;
		axi_results.tid			= 0;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Crack AXI request fields

	vlan_t					lookup_src_vlan;
	macaddr_t				lookup_src_mac;
	logic[PORT_BITS-1:0]	lookup_src_port;
	macaddr_t				lookup_dst_mac;

	always_comb begin
		lookup_dst_mac		= axi_lookup.tdata[0 +: 48];
		lookup_src_mac		= axi_lookup.tdata[48 +: 48];
		lookup_src_vlan		= axi_lookup.tdata[96 +: 12];
		lookup_src_port		= axi_lookup.tdata[108 +: PORT_BITS];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cache indexing

	//Helper function for calculating the cache line for a row
	//Create a 16-bit index (enough for 64K table rows) by XOR reduction, then truncate to ROW_BITS
	function[ROW_BITS-1:0] CacheHash(macaddr_t mac, vlan_t vlan);

		logic[15:0] hash;
		begin
			hash = mac[47:32] ^ mac[31:16] ^ mac[15:0] ^ vlan;
			CacheHash = hash[ROW_BITS-1:0];
		end

	endfunction

	logic[ROW_BITS-1:0]	lookup_src_index;
	logic[ROW_BITS-1:0]	lookup_dst_index;

	always_comb begin
		lookup_src_index	= CacheHash(lookup_src_mac, lookup_src_vlan);
		lookup_dst_index	= CacheHash(lookup_dst_mac, lookup_src_vlan);	//src/dest vlan are same
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// "PRNG" for cache replacement

	//for now, sequential replacement policy. Try a LFSR in the future and see if that improves things?
	logic[ASSOC_BITS-1:0] 	cache_set 		= 0;
	logic[ASSOC_BITS-1:0] 	cache_set_fwd	= 0;
	logic					bump_set		= 0;

	always_comb begin
		if(bump_set)
			cache_set_fwd <= cache_set + 1'h1;
		else
			cache_set_fwd <= cache_set;
	end

	always_ff @(posedge axi_lookup.aclk) begin
		cache_set <= cache_set_fwd;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The table memory

	typedef struct packed
	{
		logic						gc_mark;
		logic						valid;
		vlan_t						vlan;
		logic[PORT_BITS-1:0]		port;
		macaddr_t					mac;
	} entry_t;

	entry_t					lookup_rdata[ASSOC_WAYS-1:0];
	entry_t					learn_rdata[ASSOC_WAYS-1:0];

	logic					learn_en		= 0;
	logic[ASSOC_WAYS-1:0]	learn_wr		= 0;
	logic[ROW_BITS-1:0]		learn_addr		= 0;
	entry_t					learn_wdata;

	for(genvar g=0; g<ASSOC_WAYS; g++) begin : sets
		MemoryMacro #(
			.WIDTH($bits(entry_t)),
			.DEPTH(TABLE_ROWS),
			.DUAL_PORT(1),
			.USE_BLOCK(1),
			.OUT_REG(2),
			.TRUE_DUAL(1),
			.INIT_VALUE({$bits(entry_t){1'h0}})
		) mem (
			.porta_clk(axi_lookup.aclk),
			.porta_en(axi_lookup.tvalid),
			.porta_addr(lookup_dst_index),
			.porta_we(1'b0),
			.porta_din({$bits(entry_t){1'h0}}),
			.porta_dout(lookup_rdata[g]),

			.portb_clk(axi_lookup.aclk),
			.portb_en(learn_en),
			.portb_addr(learn_addr),
			.portb_we(learn_wr[g]),
			.portb_din(learn_wdata),
			.portb_dout(learn_rdata[g])
		);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pipeline delay for read requests

	logic					lookup_en_ff			= 0;
	logic					lookup_en_ff2			= 0;
	logic[ROW_BITS-1:0]		lookup_src_index_ff		= 0;
	logic[ROW_BITS-1:0]		lookup_src_index_ff2	= 0;

	entry_t					lookup_src_ff			= 0;
	entry_t					lookup_src_ff2			= 0;
	macaddr_t				lookup_dst_mac_ff		= 0;
	macaddr_t				lookup_dst_mac_ff2		= 0;

	logic[PORT_BITS-1:0]	dest_ff		= 0;
	logic[PORT_BITS-1:0]	dest_ff2	= 0;
	logic[1:0]				id_ff		= 0;
	logic[1:0]				id_ff2		= 0;

	always_ff @(posedge axi_lookup.aclk) begin
		lookup_en_ff			<= axi_lookup.tvalid;
		lookup_en_ff2			<= lookup_en_ff;
		lookup_src_index_ff		<= lookup_src_index;
		lookup_src_index_ff2	<= lookup_src_index_ff;

		lookup_src_ff.mac		<= lookup_src_mac;
		lookup_src_ff.port		<= lookup_src_port;
		lookup_src_ff.vlan		<= lookup_src_vlan;

		lookup_src_ff2			<= lookup_src_ff;

		lookup_dst_mac_ff		<= lookup_dst_mac;
		lookup_dst_mac_ff2		<= lookup_dst_mac_ff;

		dest_ff					<= axi_lookup.tdest;
		dest_ff2				<= dest_ff;

		id_ff					<= axi_lookup.tid;
		id_ff2					<= id_ff;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Readout logic

	logic					hit_comb;
	logic					lookup_hit_comb;
	logic[PORT_BITS-1:0]	lookup_dst_port_comb;
	logic[ASSOC_BITS-1:0]	lookup_way_comb;

	logic					need_to_refresh_comb;

	always_comb begin
		hit_comb				= 0;
		lookup_hit_comb			= 0;
		lookup_dst_port_comb	= 0;
		need_to_refresh_comb	= 0;
		lookup_way_comb			= 0;

		//When a lookup completes, check if any set has a hit.
		//We should never have >1 hit but if we do, use the highest numbered set.
		if(lookup_en_ff2) begin
			for(integer i=0; i<ASSOC_WAYS; i=i+1) begin

				//Row valid plus vlan/mac match?
				if( lookup_rdata[i].valid &&
					(lookup_rdata[i].vlan == lookup_src_ff2.vlan) &&
					(lookup_rdata[i].mac == lookup_dst_mac_ff2) ) begin

					//It's a hit! Report the target
					hit_comb				= 1;
					lookup_hit_comb			= 1;
					lookup_dst_port_comb	= lookup_rdata[i].port;
					lookup_way_comb			= i;

					//Need to write back the GC mark bit if not set
					need_to_refresh_comb	= !lookup_rdata[i].gc_mark;
				end

			end

		end
	end

	always_ff @(posedge axi_lookup.aclk) begin

		axi_results.tvalid		<= lookup_en_ff2;
		axi_results.tlast		<= lookup_en_ff2;
		axi_results.tuser		<= lookup_hit_comb;
		axi_results.tdata		<= lookup_dst_port_comb;
		axi_results.tdest		<= dest_ff2;
		axi_results.tid			<= id_ff2;

		//Print status when a new packet arrives.
		//Nothing else to do at this point, we have to wait 2 clocks for the RAM to give us data
		if(axi_lookup.tvalid) begin
			$display("[%t] Packet on interface %d, vlan %d, from %x:%x:%x:%x:%x:%x to %x:%x:%x:%x:%x:%x",
				$realtime(),
				lookup_src_port,
				lookup_src_vlan,
				lookup_src_mac[47:40], lookup_src_mac[39:32], lookup_src_mac[31:24], lookup_src_mac[23:16], lookup_src_mac[15:8], lookup_src_mac[7:0],
				lookup_dst_mac[47:40], lookup_dst_mac[39:32], lookup_dst_mac[31:24], lookup_dst_mac[23:16], lookup_dst_mac[15:8], lookup_dst_mac[7:0]
			);
		end

		//Process completed lookups
		if(lookup_en_ff2) begin

			//If this address needs to have the GC mark bit set, do that
			if(hit_comb) begin
				$display("[%t] Hit - Destination %x:%x:%x:%x:%x:%x in vlan %d is on port %d",
					$realtime(),
					lookup_dst_mac_ff2[47:40], lookup_dst_mac_ff2[39:32], lookup_dst_mac_ff2[31:24],
					lookup_dst_mac_ff2[23:16], lookup_dst_mac_ff2[15:8], lookup_dst_mac_ff2[7:0],
					lookup_src_ff2.vlan,
					lookup_dst_port_comb
				);

				if(need_to_refresh_comb) begin
					$display("             Need to set GC mark");
				end
			end

			//No hit in any cache set
			else begin
				$display("[%t] Miss - Destination %x:%x:%x:%x:%x:%x in vlan %d is not in table",
					$realtime(),
					lookup_dst_mac_ff2[47:40], lookup_dst_mac_ff2[39:32], lookup_dst_mac_ff2[31:24],
					lookup_dst_mac_ff2[23:16], lookup_dst_mac_ff2[15:8], lookup_dst_mac_ff2[7:0],
					lookup_src_ff2.vlan
				);
			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pipeline read results for timing

	logic[ASSOC_BITS-1:0]	lookup_way_ff		= 0;
	logic					need_to_refresh_ff	= 0;
	entry_t					lookup_rdata_ff[ASSOC_WAYS-1:0];

	always_ff @(posedge axi_lookup.aclk) begin
		lookup_way_ff			<= lookup_way_comb;
		need_to_refresh_ff		<= need_to_refresh_comb;

		for(integer i=0; i<ASSOC_WAYS; i=i+1)
			lookup_rdata_ff[i]	<= lookup_rdata[i];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Table refreshing

	logic					refresh_wr_en	= 0;
	entry_t					refresh_wr_data	= 0;
	logic[ROW_BITS-1:0]		refresh_wr_addr	= 0;
	logic[ASSOC_BITS-1:0]	refresh_wr_way	= 0;

	logic					refresh_wr_ack	= 0;

	always_ff @(posedge axi_lookup.aclk) begin

		refresh_wr_en	<= 0;

		//TODO: save address, don't recompute pointlessly
		if(need_to_refresh_ff) begin
			refresh_wr_en			<= 1;
			refresh_wr_data			<= lookup_rdata_ff[lookup_way_ff];
			refresh_wr_data.gc_mark	<= 1;
			refresh_wr_addr			<= CacheHash(lookup_rdata_ff[lookup_way_ff].mac, lookup_rdata_ff[lookup_way_ff].vlan);
			refresh_wr_way			<= lookup_way_ff;
		end

		if(refresh_wr_ack)
			refresh_wr_en	<= 0;

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Arbitration for address learning and management traffic

	/*
		Prioritization (highest to lowest precedence):
			1) Looking up addresses to be learned
			2) Writing learned addresses to the table
			3) Refreshing the GC mark on existing table entries
			4) Garbage collection
			5) Interactive UI
	 */

	logic					pend_wr_en		= 0;
	entry_t					pend_wr_data	= 0;
	logic[ROW_BITS-1:0]		pend_wr_addr	= 0;
	logic					pend_wr_ack		= 0;
	logic[ASSOC_BITS-1:0]	pend_wr_way		= 0;

	logic					pend_wr_ack_fwd	= 0;

	//New data being added to the pending queue
	logic					need_to_learn	= 0;
	logic[47:0]				pend_addr		= 0;
	logic[11:0]				pend_vlan		= 0;
	logic[PORT_BITS-1:0]	pend_port		= 0;
	logic[ASSOC_BITS-1:0]	pend_way		= 0;

	//Memory requests from the garbage collector
	logic[ROW_BITS-1:0]		gc_row			= 0;
	logic[ASSOC_BITS-1:0]	gc_way			= 0;
	logic					gc_rd_en		= 0;
	logic					gc_rd_ack		= 0;
	logic					gc_rd_ack_fwd;
	entry_t					gc_wdata 		= 0;
	logic					gc_wr_en		= 0;
	logic					gc_wr_ack		= 0;
	logic					gc_wr_ack_fwd;
	logic					mgmt_ack_fwd;

	//Memory requests from the refreshing logic
	logic					refresh_wr_ack_fwd;

	always_comb begin

		//Default to not doing anything
		learn_en			= 0;
		learn_wr			= 0;
		learn_addr			= 0;
		learn_wdata			= 0;

		pend_wr_ack_fwd		= 0;
		gc_rd_ack_fwd		= 0;
		gc_wr_ack_fwd		= 0;
		refresh_wr_ack_fwd	= 0;
		mgmt_ack_fwd		= 0;

		//If an incoming packet is arriving, look up the source
		if(axi_lookup.tvalid) begin
			learn_en			= 1;
			learn_addr			= lookup_src_index;
		end

		//Write pending data to the table
		else if(pend_wr_en && !pend_wr_ack) begin
			learn_en				= 1;
			learn_wr[pend_wr_way]	= 1;
			learn_addr				= pend_wr_addr;
			learn_wdata				= pend_wr_data;
			pend_wr_ack_fwd			= 1;
		end

		//Write refresh data to the table
		else if(refresh_wr_en) begin
			learn_en					= 1;
			learn_addr					= refresh_wr_addr;
			learn_wr[refresh_wr_way]	= 1;
			learn_wdata					= refresh_wr_data;
			refresh_wr_ack_fwd			= 1;
		end

		//Garbage collector reads
		else if(gc_rd_en && !gc_rd_ack) begin
			learn_en		= 1;
			learn_addr		= gc_row;
			gc_rd_ack_fwd	= 1;
		end

		//Garbage collector writes
		else if(gc_wr_en && !gc_wr_ack) begin
			learn_en			= 1;
			learn_addr			= gc_row;
			learn_wr[gc_way]	= 1;
			learn_wdata			= gc_wdata;
			gc_wr_ack_fwd		= 1;
		end

		//Management engine reads
		else if(mgmt_rd_en && !mgmt_ack_fwd) begin
			learn_en			= 1;
			learn_addr			= mgmt_addr;
			mgmt_ack_fwd		= 1;
		end

		//Management engine writes
		else if(mgmt_del_en) begin
			learn_en			= 1;
			learn_addr			= mgmt_addr;
			learn_wr[mgmt_way]	= 1;
			learn_wdata			= 0;
			mgmt_ack_fwd		= 1;
		end

	end

	always_ff @(posedge axi_lookup.aclk) begin
		pend_wr_ack		<= pend_wr_ack_fwd;
		gc_rd_ack		<= gc_rd_ack_fwd;
		gc_wr_ack		<= gc_wr_ack_fwd;
		refresh_wr_ack	<= refresh_wr_ack_fwd;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Handle output for the management engine

	logic	mgmt_rd_ack		= 0;
	logic	mgmt_rd_ack_ff	= 0;

	always_ff @(posedge axi_lookup.aclk) begin
		mgmt_rd_ack		<= mgmt_ack_fwd && mgmt_rd_en;
		mgmt_rd_ack_ff	<= mgmt_rd_ack;

		mgmt_ack		<= 0;

		//Readback
		if(mgmt_rd_ack_ff) begin
			mgmt_ack		<= 1;
			mgmt_rd_valid	<= learn_rdata[mgmt_way].valid;
			mgmt_rd_gc_mark	<= learn_rdata[mgmt_way].gc_mark;
			mgmt_rd_mac		<= learn_rdata[mgmt_way].mac;
			mgmt_rd_port	<= learn_rdata[mgmt_way].port;
			mgmt_rd_vlan	<= learn_rdata[mgmt_way].vlan;
		end

		//ack writes immediately
		if(mgmt_ack_fwd && mgmt_del_en)
			mgmt_ack	<= 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Set of addresses that need to be learned but haven't yet been pushed to the table

	//The pending queue
	entry_t					pending[PENDING_SIZE-1:0];
	logic[ASSOC_BITS-1:0]	pending_way[PENDING_SIZE-1:0];

	//Clear completed entries once written to memory
	logic					pend_clear		= 0;
	localparam				PEND_BITS		= $clog2(PENDING_SIZE);
	logic[PEND_BITS-1:0]	pend_clear_slot	= 0;

	//Wipe the table
	initial begin
		for(integer i=0; i<PENDING_SIZE; i++) begin
			pending[i].gc_mark	<= 0;
			pending[i].mac		<= 0;
			pending[i].vlan		<= 0;
			pending[i].port		<= 0;
			pending[i].valid	<= 0;
			pending_way[i]		<= 0;
		end
	end

	//Add new entries to the table, avoiding duplication
	//TODO: this should probably be refactored into a standalone module?
	logic					already_pending	= 0;
	logic					found_opening	= 0;
	always_ff @(posedge axi_lookup.aclk) begin

		already_pending	= 0;
		found_opening	= 0;

		if(need_to_learn) begin
			$display("[%t] Need to learn -  Source %x:%x:%x:%x:%x:%x in vlan %d (from port %d) is not in table, adding to way %d",
					$realtime(),
					pend_addr[47:40], pend_addr[39:32], pend_addr[31:24],
					pend_addr[23:16], pend_addr[15:8], pend_addr[7:0],
					pend_vlan,
					pend_port,
					pend_way
				);

			//Iterate over table entries and see if it's already in the learn queue
			for(integer i=0; i<PENDING_SIZE; i++) begin

				//Already pending, no action required
				if(pending[i].valid &&
					(pending[i].mac == pend_addr) &&
					(pending[i].vlan == pend_vlan) &&
					(pending[i].port == pend_port)
				) begin
					$display("             Already in pending set");
					already_pending	= 1;
				end

			end

			//Not in the learn queue. Find the first free spot in the set and insert it
			if(!already_pending) begin
				for(integer i=0; i<PENDING_SIZE; i=i+1) begin

					//Stop if we already did the insert
					if(found_opening) begin
					end

					//Insert when we find a free spot
					else if(!pending[i].valid) begin
						pending[i].valid	<= 1;
						pending[i].vlan		<= pend_vlan;
						pending[i].port		<= pend_port;
						pending[i].mac		<= pend_addr;
						pending_way[i]		<= pend_way;
						found_opening		= 1;
						$display("              Added to pending set (slot %d)", i[7:0]);
					end

				end
			end

		end

		//Once we've written a pending item to the table, remove it from the queue
		if(pend_clear) begin
			pending[pend_clear_slot].valid	<= 0;

			$display("              Clearing slot %d of pending set", pend_clear_slot);
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Check if the source address is already learned. If not, add to the learning queue

	logic				learned_comb 	= 0;

	always_ff @(posedge axi_lookup.aclk) begin

		need_to_learn	<= 0;
		bump_set		<= 0;

		if(lookup_en_ff2) begin

			learned_comb	= 0;

			for(integer i=0; i<ASSOC_WAYS; i=i+1) begin

				//Row valid plus vlan/mac match? All good
				if( learn_rdata[i].valid &&
					(learn_rdata[i].vlan == lookup_src_ff2.vlan) &&
					(learn_rdata[i].mac == lookup_src_ff2.mac) ) begin

					//It's a hit! Report the target
					learned_comb		= 1;
					$display("[%t] OK - Source %x:%x:%x:%x:%x:%x in vlan %d is on port %d",
						$realtime(),
						lookup_src_ff2.mac[47:40], lookup_src_ff2.mac[39:32], lookup_src_ff2.mac[31:24],
						lookup_src_ff2.mac[23:16], lookup_src_ff2.mac[15:8], lookup_src_ff2.mac[7:0],
						lookup_src_ff2.vlan,
						learn_rdata[i].port
					);


					//TODO: handle this situation
					if(learn_rdata[i].port != lookup_src_ff2.port) begin
						$display("FIXME: Host appears to have jumped to another port, this isn't implemented yet");
					end

				end

			end

			//Don't learn broadcast/multicast addresses
			if(lookup_src_ff2.mac[40]) begin
				$display("[%t] Not learning address %x:%x:%x:%x:%x:%x because it is a broadcast or multicast group",
					$realtime(),
					lookup_src_ff2.mac[47:40], lookup_src_ff2.mac[39:32], lookup_src_ff2.mac[31:24],
					lookup_src_ff2.mac[23:16], lookup_src_ff2.mac[15:8], lookup_src_ff2.mac[7:0]);
			end

			//No hit in any cache set
			else if(!learned_comb) begin
				need_to_learn	<= 1;
				pend_addr		<= lookup_src_ff2.mac;
				pend_vlan		<= lookup_src_ff2.vlan;
				pend_port		<= lookup_src_ff2.port;

				pend_way		<= cache_set_fwd;
				bump_set		<= 1;
			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pop data from the pending set and push it into the table proper

	logic	found_slot		= 0;

	//Clear slots out combinatorially
	always_comb begin
		pend_clear	<= pend_wr_ack;
	end

	always_ff @(posedge axi_lookup.aclk) begin

		pend_wr_addr	<= 0;

		found_slot		= 0;

		if(pend_wr_ack_fwd)
			pend_wr_en	<= 0;

		//If we don't have another write in progress, go look for a free table slot and write it
		if(!pend_wr_en || pend_wr_ack) begin

			for(integer i=0; i<PENDING_SIZE; i++) begin

				//If we're in the process of clearing this slot, don't look at it
				if(pend_clear && (pend_clear_slot == i)) begin
					//$display("[%t] Ignoring slot %d because we just finished adding it", $realtime(), i);
				end

				//This slot is eligible to be looked at
				else if(pending[i].valid && !found_slot) begin
					found_slot				= 1;

					pend_clear_slot			<= i;

					pend_wr_en				<= 1;
					pend_wr_data.gc_mark	<= 1;
					pend_wr_data.valid		<= 1;
					pend_wr_data.vlan		<= pending[i].vlan;
					pend_wr_data.port		<= pending[i].port;
					pend_wr_data.mac		<= pending[i].mac;
					pend_wr_addr			<= CacheHash(pending[i].mac, pending[i].vlan);
					pend_wr_way				<= pending_way[i];

					$display("[%t] Learning address %x:%x:%x:%x:%x:%x in vlan %d (from port %d) to way %d",
						$realtime(),
						pending[i].mac[47:40], pending[i].mac[39:32], pending[i].mac[31:24],
						pending[i].mac[23:16], pending[i].mac[15:8], pending[i].mac[7:0],
						pending[i].vlan,
						pending[i].port,
						pending_way[i]
					);
				end
			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Garbage collection. Simple and unoptimized, but doesn't have to be fast!

	enum logic[2:0]
	{
		GC_STATE_IDLE 		= 0,
		GC_STATE_READ_WAIT	= 1,
		GC_STATE_READ_VALID	= 2,
		GC_STATE_WRITE_WAIT	= 3,
		GC_STATE_NEXT		= 4
	} gc_state = GC_STATE_IDLE;

	wire entry_t gc_rdata = learn_rdata[gc_way];

	always_ff @(posedge axi_lookup.aclk) begin

		gc_done		<= 0;

		case(gc_state)

			GC_STATE_IDLE: begin

				if(gc_en) begin
					$display("[%t] Starting garbage collector", $realtime());
					gc_state	<= GC_STATE_READ_WAIT;
					gc_row		<= 0;
					gc_way		<= 0;
					gc_rd_en	<= 1;
				end

			end	//end GC_STATE_IDLE

			//Wait for ACK to come back, then pipeline delay
			GC_STATE_READ_WAIT: begin
				if(gc_rd_ack) begin
					gc_rd_en	<= 0;
					gc_state	<= GC_STATE_READ_VALID;
				end
			end	//end GC_STATE_READ_WAIT

			GC_STATE_READ_VALID: begin

				//If entry is not valid, no action required. Continue on to the next entry of the table.
				if(!gc_rdata.valid)
					gc_state		<= GC_STATE_NEXT;

				//Entry is valid. If it has the GC mark bit set, clear it but don't change anything else.
				else if(gc_rdata.gc_mark) begin
					gc_wdata			<= gc_rdata;
					gc_wdata.gc_mark	<= 0;
					gc_wr_en			<= 1;
					gc_state			<= GC_STATE_WRITE_WAIT;

					$display("[%t] GC: Clearing mark bit on %x:%x:%x:%x:%x:%x in vlan %d (from port %d) in way %d",
						$realtime(),
						gc_rdata.mac[47:40], gc_rdata.mac[39:32], gc_rdata.mac[31:24],
						gc_rdata.mac[23:16], gc_rdata.mac[15:8], gc_rdata.mac[7:0],
						gc_rdata.vlan,
						gc_rdata.port,
						gc_way
					);
				end

				//If GC mark bit is not set, wipe the entry since it hasn't been used in a while.
				else begin
					gc_wdata			<= 0;
					gc_wr_en			<= 1;

					$display("[%t] GC: Garbage collecting address %x:%x:%x:%x:%x:%x in vlan %d (from port %d) in way %d",
						$realtime(),
						gc_rdata.mac[47:40], gc_rdata.mac[39:32], gc_rdata.mac[31:24],
						gc_rdata.mac[23:16], gc_rdata.mac[15:8], gc_rdata.mac[7:0],
						gc_rdata.vlan,
						gc_rdata.port,
						gc_way
					);

					gc_state			<= GC_STATE_WRITE_WAIT;
				end

			end	//end GC_STATE_READ_VALID

			//Wait for write to complete, then move on
			GC_STATE_WRITE_WAIT: begin
				if(gc_wr_ack) begin
					gc_wr_en		<= 0;
					gc_state		<= GC_STATE_NEXT;
				end
			end	//end GC_STATE_WRITE_WAIT

			//Go on to next state
			GC_STATE_NEXT: begin

				//Not necessary, just makes sim traces cleaner. OK to remove for timing reasons if needed.
				gc_wdata			<= 0;

				//End of the current way?
				if(gc_row == TABLE_ROWS - 1) begin

					//Last way? We're done
					if(gc_way == ASSOC_WAYS-1) begin
						gc_done		<= 1;
						$display("[%t] Garbage collection complete", $realtime());
						gc_state	<= GC_STATE_IDLE;
					end

					//Nope, go to next way
					else begin
						gc_way		<= gc_way + 1;
						gc_row		<= gc_row + 1;
						gc_rd_en	<= 1;
						gc_state	<= GC_STATE_READ_WAIT;
					end

				end

				//Nope, read the next row
				else begin
					gc_row		<= gc_row + 1;
					gc_rd_en	<= 1;
					gc_state	<= GC_STATE_READ_WAIT;
				end

			end	//end GC_STATE_NEXT

		endcase

	end

endmodule
