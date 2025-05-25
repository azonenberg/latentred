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
	@file
	@author Andrew D. Zonenberg
	@brief Ingress FIFO controller for a single 10/100/1000 baseT port

	Assumes a single URAM288 as the fifo
		4K words x 72 bits (32 kB usable capacity)
		This is 21.8 MTU-sized frames or 512 min-sized frames

	Input: ethernet frames on 32-bit axi-stream, already shifted to the core fabric clock domain

	Buffer format:
		64 bits wide (trying not to use the ECC bits in case we want actual ECC later on)

		First word:
			27:16		VLAN ID
			10:0		frame length

		Subsequent words: packet data
 */
module GigabitIngressFIFO #(
	parameter	DEPTH	= 4096,
	parameter	ADDR_BITS = $clog2(DEPTH)
)(

	//32-bit AXI in (switch fabric clock domain)
	AXIStream.receiver			axi_rx,

	//64-bit (plus ecc or metadata) write bus to URAM
	output logic				wr_en	= 0,
	output logic[ADDR_BITS-1:0]	wr_addr	= 0,
	output logic[71:0]			wr_data	= 0,

	//Write pointer
	output logic[ADDR_BITS:0]	wr_ptr_committed = 0,

	//Read-side bus
	//(we do not actually read the URAM here, just do address calc)
	input wire[ADDR_BITS:0]		rd_ptr
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pipeline the incoming data

	logic[2:0]	wr_valid 	= 0;
	logic		tvalid_ff	= 0;
	logic[31:0]	tdata_ff	= 0;
	logic		tlast_ff	= 0;
	vlan_t		tdest_ff	= 0;

	always_ff @(posedge axi_rx.aclk or negedge axi_rx.areset_n) begin
		if(!axi_rx.areset_n) begin
			wr_valid	<= 0;
			tvalid_ff	<= 0;
			tdata_ff	<= 0;
		end

		else begin

			//Extract the number of valid bytes from the AXI byte strobes
			if(axi_rx.tstrb[3])
				wr_valid	<= 4;
			else if(axi_rx.tstrb[2])
				wr_valid	<= 3;
			else if(axi_rx.tstrb[1])
				wr_valid	<= 2;
			else if(axi_rx.tstrb[0])
				wr_valid	<= 1;
			else
				wr_valid	<= 0;

			//Pipeline stuff
			tvalid_ff		<= axi_rx.tvalid && axi_rx.tready;
			tdata_ff		<= axi_rx.tdata;
			tlast_ff		<= axi_rx.tlast;
			tdest_ff		<= axi_rx.tdest;

		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO write logic

	logic[ADDR_BITS:0]			wr_ptr = 0;

	//Amount of space available for writes
	wire[ADDR_BITS:0]			wr_size;
	assign wr_size = DEPTH + rd_ptr - wr_ptr;

	//Main RX state machine
	enum logic[1:0]
	{
		WR_IDLE		= 0,
		WR_HIGH		= 1,
		WR_LOW		= 2,
		WR_HEADER	= 3

	} wr_state = WR_IDLE;

	//Pointer to the 0th word of the packet (in-band header just before the packet itself)
	logic[ADDR_BITS-1:0]	sof_ptr		= 0;

	//Running length of current frame
	logic[ADDR_BITS-1:0]	frame_len	= 0;

	//VLAN ID of the frame (may be from port or 802.1q tag)
	vlan_t					frame_vlan	= 0;

	//Ready to accept new data if we're not full or writing the metadata word
	assign axi_rx.tready = (wr_size > 2) && !tlast_ff;

	always_ff @(posedge axi_rx.aclk or negedge axi_rx.areset_n) begin

		//Reset pointers when the RX link flaps
		if(!axi_rx.areset_n) begin
			wr_en				<= 0;
			wr_addr				<= 0;
			wr_data				<= 0;
			wr_ptr_committed	<= 0;
			wr_ptr				<= 0;
			wr_state			<= WR_IDLE;
			sof_ptr				<= 0;
			frame_len			<= 0;
			frame_vlan			<= 0;
		end

		else begin

			wr_en				<= 0;

			//always clear high/ECC byte
			wr_data[71:63]		<= 0;

			//Write pointer management at the end of a write cycle
			if(wr_en) begin

				//Not writing header? bump pointer
				if(wr_state != WR_IDLE)
					wr_ptr	<= wr_ptr + 1;

				//Header is valid, the reader can start consuming data up to the previous high water mark
				else
					wr_ptr_committed	<= wr_ptr;
			end

			case(wr_state)

				//Starting a new frame?
				WR_IDLE: begin

					if(tvalid_ff) begin

						//Save start pointer so we know where to write the header when we're done
						sof_ptr			<= wr_ptr;

						//Prepare to write the first data word to the word after the header
						wr_ptr			<= wr_ptr + 1;

						//Write the first data block to the working buffer but don't commit to memory yet
						frame_len		<= wr_valid;
						wr_data[63:32]	<= 0;
						wr_data[31:0]	<= tdata_ff;
						wr_state		<= WR_HIGH;

					end

				end	//WR_IDLE

				//Write the high half of a 64-bit block and commit to memory
				WR_HIGH: begin

					if(tvalid_ff) begin

						//Default to writing the low half of the next word
						wr_state		<= WR_LOW;

						//Default to writing the data to URAM
						frame_len		<= frame_len + wr_valid;
						wr_en			<= 1;
						wr_addr			<= wr_ptr;
						wr_data[63:32]	<= tdata_ff;

						//Last word needs special handling
						if(tlast_ff) begin

							//Errors? Roll back to the starting point
							//OK to let the write commit - we'll never use it, and it wastes a tiny bit of power
							//but this is infrequent and letting it happen probably saves a bit of timing overhead
							if(axi_rx.tuser[0]) begin
								wr_ptr			<= sof_ptr;
								wr_state		<= WR_IDLE;
							end

							//If good, we're doing the header next cycle
							else begin
								wr_state		<= WR_HEADER;
								frame_vlan		<= tdest_ff;
							end

						end

					end

				end	//WR_HIGH

				//Write the low half of a 64-bit block to the working buffer but don't push to URAM (yet)
				WR_LOW: begin

					if(tvalid_ff) begin

						//Default to writing the high half of the next word
						wr_state		<= WR_HIGH;

						//Track the data but don't push to RAM
						frame_len		<= frame_len + wr_valid;
						wr_data[31:0]	<= tdata_ff;

						//Last word needs special handling
						if(tlast_ff) begin

							//Errors? Roll back to the starting point (no active write to cancel)
							if(axi_rx.tuser[0]) begin
								wr_ptr			<= sof_ptr;
								wr_state		<= WR_IDLE;
							end

							//If good, we're doing the header next cycle. Write the last word of the frame this cycle
							else begin
								frame_vlan		<= tdest_ff;
								wr_state		<= WR_HEADER;

								//Make sure we actually have a partial word
								//(rather than TLAST with no content)
								if(wr_valid > 0) begin
									wr_data[63:32]	<= 0;
									wr_en			<= 1;

									//forward pending write enable
									if(wr_en)
										wr_addr		<= wr_ptr + 1;
									else
										wr_addr		<= wr_ptr;
								end

							end

						end

					end

				end //WR_LOW

				//Write the header to the start of the buffer
				WR_HEADER: begin
					wr_en				<= 1;
					wr_addr				<= sof_ptr;
					wr_data[63:32]		<= 0;
					wr_data[31:28]		<= 0;
					wr_data[27:16]		<= frame_vlan;
					wr_data[15:11]		<= 0;
					wr_data[10:0]		<= frame_len;

					wr_state			<= WR_IDLE;
				end

			endcase

		end

	end

endmodule
