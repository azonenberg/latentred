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
	@brief Read-side logic for the RX FIFO
 */

module LineCardFIFOReader #(

	//Global index of the first port in our line card
	parameter BASE_PORT		= 0,

	parameter NUM_PORTS		= 50,
	localparam PORT_BITS	= $clog2(NUM_PORTS)

) (
	input wire				clk,

	//Read FIFO state
	input wire[12:0]			wr_ptr_committed[23:0],
	input wire					rd_ptr_reset[23:0],
	output logic[12:0]			rd_ptr[23:0],

	//URAM interface
	output logic				rd_en	= 0,
	output logic[16:0]			rd_addr	= 0,
	input wire[71:0]			rd_data,
	input wire					rd_valid,

	//Request/lookup interface to MAC address table
	output logic				mac_lookup_en		= 0,
	output vlan_t				mac_lookup_src_vlan	= 0,
	output macaddr_t			mac_lookup_src_mac	= 0,
	output logic[4:0]			mac_lookup_src_port	= 0,	//NOTE: this is port within the line card, not global port ID
	output macaddr_t			mac_lookup_dst_mac	= 0,

	input wire					mac_lookup_done,
	input wire					mac_lookup_hit,
	input wire[PORT_BITS-1:0]	mac_lookup_dst_port,

	//AXI interface to core crossbar
	AXIStream.transmitter		axi_tx
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Validate buses are the right size

	if(axi_tx.DATA_WIDTH != 64)
		axi_bus_width_inconsistent();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Hook up AXI control signals

	assign axi_tx.aclk		= clk;
	assign axi_tx.twakeup	= 1;

	initial begin
		axi_tx.areset_n		= 0;
		axi_tx.tvalid		= 0;
		axi_tx.tdata		= 0;
		axi_tx.tkeep		= 0;
		axi_tx.tstrb		= 0;
		axi_tx.tdest		= 0;
		axi_tx.tuser		= 0;
		axi_tx.tlast		= 0;
	end
	always_ff @(posedge clk) begin
		axi_tx.areset_n		<= 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Per-port state tables

	typedef enum logic[2:0]
	{
		PORT_STATE_IDLE					= 0,	//nothing to do
		PORT_STATE_DATA_READY			= 1,	//frame ready to start forwarding
		PORT_STATE_HEADER_WAIT			= 2,	//read of header was dispatched
		PORT_STATE_WORD_0				= 3,	//read of first payload word was dispatched
		PORT_STATE_WORD_1				= 4,	//read of second payload word was dispatched
		PORT_STATE_MAC_LOOKUP			= 5,	//mac address lookup in progress
		PORT_STATE_FWD_READY			= 6,	//ready to forward
		PORT_STATE_FORWARDING			= 7		//actively forwarding
	} PortState;

	//Current forwarding state
	PortState				port_states[23:0];

	//VLAN of the current frame
	vlan_t					port_vlans[23:0];

	//Dest MAC of the current frame
	macaddr_t				port_dst_mac[23:0];

	//Source MAC of the current frame
	macaddr_t				port_src_mac[23:0];

	//First 4 payload bytes of the current frame (ethertype and two more after)
	logic[31:0]				port_first4[23:0];

	//Length of the current frame
	logic[10:0]				port_lens[23:0];

	//Destination port of the current frame
	logic[PORT_BITS-1:0]	port_dst_port[23:0];
	logic					port_dst_is_broadcast[23:0];

	initial begin
		for(integer i=0; i<24; i++) begin
			port_states[i]				= PORT_STATE_IDLE;
			port_vlans[i]				= 0;
			port_lens[i]				= 0;
			port_dst_mac[i]				= 0;
			port_src_mac[i]				= 0;
			port_first4[i]				= 0;
			port_dst_port[i]			= 0;
			port_dst_is_broadcast[i]	= 0;

			rd_ptr[i]					= 0;
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO read helpers

	logic[12:0] fifo_rd_size[23:0];
	always_comb begin
		for(integer i=0; i<24; i=i+1)
			fifo_rd_size[i] = wr_ptr_committed[i] - rd_ptr[i];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Remember which ports we sent MAC lookups for

	wire[4:0]	next_mac_local_port;

	SingleClockFifo #(
		.WIDTH(5),
		.DEPTH(32),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) lookup_src_fifo (
		.clk(clk),

		.wr(mac_lookup_en),
		.din(mac_lookup_src_port),

		.rd(mac_lookup_done),
		.dout(next_mac_local_port),

		.overflow(),
		.underflow(),
		.empty(),
		.full(),
		.rsize(),
		.wsize(),
		.reset()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State for in-progress packets

	typedef enum logic[2:0]
	{
		//0 reserved for now
		MTYPE_HEADER	= 1,	//header read
		MTYPE_WORD0		= 2,
		MTYPE_WORD1		= 3,
		MTYPE_BODY		= 4
	} mtype_t;

	typedef struct packed
	{
		mtype_t		mtype;
		logic[4:0]	port;
	} PendingMetadata;

	logic			meta_wr_en	= 0;
	PendingMetadata meta_wdata;

	wire			meta_empty;
	logic			meta_rd_en = 0;
	PendingMetadata	meta_rdata;

	SingleClockFifo #(
		.WIDTH($bits(PendingMetadata)),
		.DEPTH(32),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) meta_fifo (
		.clk(clk),

		.wr(meta_wr_en),
		.din(meta_wdata),

		.rd(meta_rd_en),
		.dout(meta_rdata),

		.overflow(),
		.underflow(),
		.empty(meta_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(!axi_tx.areset_n)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main reader block

	//Round robin port counter
	logic[4:0]	main_rr_port	= 0;

	logic[4:0]	fwd_port		= 0;

	//FIFO read pointer of the round robin winner
	logic[11:0]	main_rr_ptr;

	//FIFO read pointer of the most recent read transaction
	logic[11:0] meta_rdata_ptr;

	//FIFO read pointer of the frame being forwarded
	logic[11:0] fwd_ptr;

	always_comb begin
		main_rr_ptr		= rd_ptr[main_rr_port][11:0];
		meta_rdata_ptr	= rd_ptr[meta_rdata.port][11:0];
		fwd_ptr			= rd_ptr[fwd_port][11:0];
	end

	logic[10:0]	fwd_bytesToRead	= 0;
	logic[10:0]	fwd_bytesToSend	= 0;

	enum logic[1:0]
	{
		FWD_STATE_IDLE,
		FWD_STATE_HEADER_1,
		FWD_STATE_BODY
	} fwd_state = FWD_STATE_IDLE;

	always_ff @(posedge clk) begin

		rd_en					<= 0;
		meta_wr_en				<= 0;
		meta_rd_en				<= 0;
		mac_lookup_en			<= 0;

		//Clear AXI stuff on ack
		if(axi_tx.tready) begin
			axi_tx.tvalid		<= 0;
			axi_tx.tkeep		<= 0;
			axi_tx.tstrb		<= 0;
			axi_tx.tdata		<= 0;
			axi_tx.tlast		<= 0;
		end

		for(integer i=0; i<24; i++) begin

			//Reset read pointer on request
			if(rd_ptr_reset[i])
				rd_ptr[i]		<= 0;

			//Check all ports in parallel for having data ready to go
			if( (port_states[i] == PORT_STATE_IDLE) && (fifo_rd_size[i] != 0) )
				port_states[i]	<= PORT_STATE_DATA_READY;
		end

		//Handle MAC address lookups coming back
		if(mac_lookup_done) begin
			port_dst_is_broadcast[next_mac_local_port]	<= !mac_lookup_hit;
			port_dst_port[next_mac_local_port]			<= mac_lookup_dst_port;
			port_states[next_mac_local_port]			<= PORT_STATE_FWD_READY;

			`ifdef SIMULATION
				$display("[%t] Frame on interface %d is ready to forward",
					$realtime(),
					next_mac_local_port + BASE_PORT);
			`endif
		end

		//Forwarding payload body
		/*
			assuming 5 cycle gap here
			this is a net loss of 320 bit times
			ethernet interframe gap is 96 bits, plus preamble/SFD is another 64, plus FCS is 32: total 192 bits
			so we waste 128 bits per packet
			with min sized packets we forward 24 Gbps * 1.488 Mpps/Gbps = 35.712 Mpps, so 4.571 Gbps of overhead
			we can only afford 1 Gbps to be fully wire speed, so this needs to improve!
		 */
		if(fwd_state == FWD_STATE_BODY) begin

			//Forward data
			if(rd_valid && meta_rdata.mtype == MTYPE_BODY) begin

				//Full word?
				if(fwd_bytesToSend > 8) begin
					fwd_bytesToSend				<= fwd_bytesToSend - 8;
					axi_tx.tstrb				<= 8'hff;
				end

				//Partial word? We're done
				else begin
					case(fwd_bytesToSend)
						7:	axi_tx.tstrb		<= 8'b01111111;
						6:	axi_tx.tstrb		<= 8'b00111111;
						5:	axi_tx.tstrb		<= 8'b00011111;
						4:	axi_tx.tstrb		<= 8'b00001111;
						3:	axi_tx.tstrb		<= 8'b00000111;
						2:	axi_tx.tstrb		<= 8'b00000011;
						1:	axi_tx.tstrb		<= 8'b00000001;
						default: begin
							axi_tx.tstrb		<= 8'b00000000;
						end
					endcase

					axi_tx.tlast				<= 1;

					//Clear lots of state
					fwd_state					<= FWD_STATE_IDLE;
					port_states[fwd_port]		<= PORT_STATE_IDLE;

				end

				axi_tx.tvalid					<= 1;
				axi_tx.tdata					<=
				{
					rd_data[63:0]
				};
				axi_tx.tkeep					<= 8'hff;

			end

			//Request more data unless we're done
			if(fwd_bytesToRead > 0) begin

				if(fwd_bytesToRead >= 8)
					fwd_bytesToRead				<= fwd_bytesToRead - 8;
				else
					fwd_bytesToRead				<= 0;

				//Request a read of the data, then bump the upstream pointer
				rd_en							<= 1;
				rd_addr							<= { fwd_port, fwd_ptr };
				rd_ptr[fwd_port]				<= rd_ptr[fwd_port] + 1;

				//Record that we have a data read pending
				meta_wr_en						<= 1;
				meta_wdata.mtype				<= MTYPE_BODY;
				meta_wdata.port					<= fwd_port;

			end

			//TODO: if we're almost at the end of the frame, start prefetching next frame?

		end

		//Read data will always show up after the metadata, so no need to check if there's data in the metadata fifo
		if(rd_valid) begin

			//Figure out why we read it
			case(meta_rdata.mtype)

				//It's a header
				MTYPE_HEADER: begin

					//Save the header
					port_vlans[meta_rdata.port]			<= rd_data[27:16];
					port_lens[meta_rdata.port]			<= rd_data[10:0];

					//Request read of the first frame word and bump the pointer
					rd_en								<= 1;
					rd_addr								<= { meta_rdata.port, meta_rdata_ptr };
					rd_ptr[meta_rdata.port]				<= rd_ptr[meta_rdata.port] + 1;

					port_states[meta_rdata.port]		<= PORT_STATE_WORD_0;

					//Save metadata
					meta_wr_en							<= 1;
					meta_wdata.mtype					<= MTYPE_WORD0;
					meta_wdata.port						<= meta_rdata.port;

				end //MTYPE_HEADER

				//It's the first packet word
				MTYPE_WORD0: begin

					//Save the header we have so far
					port_dst_mac[meta_rdata.port]		<=
					{
						rd_data[0*8 +: 8],
						rd_data[1*8 +: 8],
						rd_data[2*8 +: 8],
						rd_data[3*8 +: 8],
						rd_data[4*8 +: 8],
						rd_data[5*8 +: 8]
					};

					port_src_mac[meta_rdata.port][47:32]	<=
					{
						rd_data[6*8 +: 8],
						rd_data[7*8 +: 8]
					};

					//Request read of the second frame word and bump the pointer
					rd_en								<= 1;
					rd_addr								<= { meta_rdata.port, meta_rdata_ptr };
					rd_ptr[meta_rdata.port]				<= rd_ptr[meta_rdata.port] + 1;
					port_states[meta_rdata.port]		<= PORT_STATE_WORD_1;

					//Save metadata
					meta_wr_en							<= 1;
					meta_wdata.mtype					<= MTYPE_WORD1;
					meta_wdata.port						<= meta_rdata.port;

				end //MTYPE_WORD0

				//Second packet word
				MTYPE_WORD1: begin

					//Save the remaining headers
					port_src_mac[meta_rdata.port][31:0]	<=
					{
						rd_data[0*8 +: 8],
						rd_data[1*8 +: 8],
						rd_data[2*8 +: 8],
						rd_data[3*8 +: 8]
					};

					port_first4[meta_rdata.port]		<=
					{
						rd_data[4*8 +: 8],
						rd_data[5*8 +: 8],
						rd_data[6*8 +: 8],
						rd_data[7*8 +: 8]
					};

					//Don't dispatch a new memory request
					//Just mark the state as ready to go for routing lookup
					port_states[meta_rdata.port]		<= PORT_STATE_MAC_LOOKUP;

					//Dispatch the MAC address lookup
					mac_lookup_en						<= 1;
					mac_lookup_src_vlan					<= port_vlans[meta_rdata.port];
					mac_lookup_dst_mac					<= port_dst_mac[meta_rdata.port];
					mac_lookup_src_mac[47:32]			<= port_src_mac[meta_rdata.port][47:32];
					mac_lookup_src_mac[31:0]			<=
					{
						rd_data[0*8 +: 8],
						rd_data[1*8 +: 8],
						rd_data[2*8 +: 8],
						rd_data[3*8 +: 8]
					};
					mac_lookup_src_port					<= meta_rdata.port;

				end	//MTYPE_WORD1

				//Don't know why? Ignore the read
				default: begin
				end
			endcase

			//Pop the word
			meta_rd_en	<= 1;

		end

		else if(fwd_state != FWD_STATE_IDLE) begin

			case(fwd_state)

				//First header word sent, send second
				FWD_STATE_HEADER_1: begin

					//Request a read of the data, then bump the upstream pointer
					rd_en							<= 1;
					rd_addr							<= { fwd_port, fwd_ptr };
					rd_ptr[fwd_port]				<= rd_ptr[fwd_port] + 1;

					//Record that we have a data read pending
					meta_wr_en						<= 1;
					meta_wdata.mtype				<= MTYPE_BODY;
					meta_wdata.port					<= fwd_port;

					//Send the next data word
					fwd_bytesToRead					<= fwd_bytesToRead - 8;
					fwd_bytesToSend					<= fwd_bytesToSend - 8;
					axi_tx.tvalid					<= 1;
					axi_tx.tdata					<=
					{
						port_first4[fwd_port][0*8 +: 8],
						port_first4[fwd_port][1*8 +: 8],
						port_first4[fwd_port][2*8 +: 8],
						port_first4[fwd_port][3*8 +: 8],
						port_src_mac[fwd_port][0*8 +: 8],
						port_src_mac[fwd_port][1*8 +: 8],
						port_src_mac[fwd_port][2*8 +: 8],
						port_src_mac[fwd_port][3*8 +: 8]
					};
					axi_tx.tstrb					<= 8'hff;
					axi_tx.tkeep					<= 8'hff;

					fwd_state						<= FWD_STATE_BODY;

				end

				//Forward data handled elsewhere
				FWD_STATE_BODY: begin
				end

				default: begin
				end
			endcase

		end

		//No action needed based on a previously read word.
		//Start processing new stuff, if we have something to do.
		else begin

			//Default to bumping round robin counter
			main_rr_port						<= main_rr_port + 1;
			if(main_rr_port == 23)
				main_rr_port					<= 0;

			//See what the current port state is and if any action is needed
			case(port_states[main_rr_port])

				//New frame ready to forward
				PORT_STATE_DATA_READY: begin

					`ifdef SIMULATION
						$display("[%t] Frame arrived on interface %d, starting lookup process",
							$realtime(),
							main_rr_port + BASE_PORT);
					`endif

					//Request a read of the header, then bump the pointer
					rd_en							<= 1;
					rd_ptr[main_rr_port]			<= rd_ptr[main_rr_port] + 1;
					rd_addr							<= { main_rr_port, main_rr_ptr };
					port_states[main_rr_port]		<= PORT_STATE_HEADER_WAIT;

					//Record that we have a header read pending so we know what to do when the response comes in
					meta_wr_en						<= 1;
					meta_wdata.mtype				<= MTYPE_HEADER;
					meta_wdata.port					<= main_rr_port;

				end	//PORT_STATE_DATA_READY

				PORT_STATE_FWD_READY: begin

					//TODO: only proceed if fabric is ready to take a frame?

					`ifdef SIMULATION
						$display("[%t] Starting forward of frame from interface %d",
							$realtime(),
							main_rr_port + BASE_PORT);
					`endif

					//Request a read of the data, then bump the pointer
					rd_en							<= 1;
					rd_addr							<= { main_rr_port, main_rr_ptr };
					rd_ptr[main_rr_port]			<= rd_ptr[main_rr_port] + 1;

					//We've started to forward the frame
					//8 bytes forwarded so far, 24 read (8 we just kicked off, 16 in headers)
					fwd_state						<= FWD_STATE_HEADER_1;
					fwd_bytesToRead					<= port_lens[main_rr_port] - 24;
					fwd_bytesToSend					<= port_lens[main_rr_port] - 8;

					//Save the port number
					fwd_port						<= main_rr_port;

					//Start sending previously-read data out the AXI bus
					//TODO: can we avoid this much inter-frame gap somehow?
					axi_tx.tvalid					<= 1;
					axi_tx.tdata					<=
					{
						port_src_mac[main_rr_port][4*8 +: 8],
						port_src_mac[main_rr_port][5*8 +: 8],
						port_dst_mac[main_rr_port][0*8 +: 8],
						port_dst_mac[main_rr_port][1*8 +: 8],
						port_dst_mac[main_rr_port][2*8 +: 8],
						port_dst_mac[main_rr_port][3*8 +: 8],
						port_dst_mac[main_rr_port][4*8 +: 8],
						port_dst_mac[main_rr_port][5*8 +: 8]
					};
					axi_tx.tstrb					<= 8'hff;
					axi_tx.tkeep					<= 8'hff;
					axi_tx.tuser					<= port_vlans[main_rr_port];
					axi_tx.tdest					<=
					{
						port_dst_is_broadcast[main_rr_port],
						port_dst_port[main_rr_port]
					};

					//Record that we have a data read pending
					meta_wr_en						<= 1;
					meta_wdata.mtype				<= MTYPE_BODY;
					meta_wdata.port					<= main_rr_port;

				end

				default: begin
				end

			endcase

		end

	end

endmodule
