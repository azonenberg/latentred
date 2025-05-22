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
	@brief Control registers for a single LATENTRED line card

	Moved into its own module since most of these get used in multiple places
 */
module LineCardControlRegisters(

	//The APB bus
	APB.completer 			apb,

	//Control registers
	output logic[11:0]		port_vlan[23:0],
	output logic			port_drop_tagged[23:0],
	output logic			port_drop_untagged[23:0]
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity check

	if(apb.DATA_WIDTH != 32)
		apb_bus_width_is_invalid();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Tie off unused APB signals

	assign apb.pruser = 0;
	assign apb.pbuser = 0;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clear everything on POR

	initial begin

		//Default configuration for TESTING until firmware knows how to talk to this
		for(integer i=0; i<24; i=i+1) begin
			port_vlan[i]			= 5;
			port_drop_tagged[i]		= 0;
			port_drop_untagged[i]	= 0;
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register IDs

	/*
		We have 1 kB of total address space to work with (0x400 bytes or 256 32-bit words)
		With 24 ports this is enough for a maximum of ten registers per port, but this doesn't divide evenly
		If we use power of two alignment, allocate 32 ports of address space with 8 registers per port
	 */
	typedef enum logic[2:0]
	{
		REG_VLAN_CFG	= 'h00,		//31	drop tagged
									//30	drop untagged
									//11:0	port vlan ID

		//7 more register IDs reserved for future use

		REG_MAX			= 'h01
	} regid_t;

	wire[4:0]	port_id;
	wire[2:0]	reg_id;

	assign port_id	= apb.paddr[9:5];
	assign reg_id	= apb.paddr[4:2];

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register logic

	//Combinatorial readback
	always_comb begin

		apb.pready	= apb.psel && apb.penable;
		apb.prdata	= 0;
		apb.pslverr	= 0;

		if(apb.pready) begin

			//Reject bogus register IDs
			if( (port_id >= 24) || (reg_id >= REG_MAX) )
				apb.pslverr	= 1;

			//Valid register path
			else begin

				//read
				if(!apb.pwrite) begin

					case(reg_id)
						REG_VLAN_CFG: begin
							apb.prdata[31]		= port_drop_tagged[port_id];
							apb.prdata[30]		= port_drop_untagged[port_id];
							apb.prdata[11:0]	= port_vlan[port_id];
						end

						default:		apb.pslverr	= 1;
					endcase

				end

				//writes: nothing needed, we already validated the register ID

			end

		end
	end

	always_ff @(posedge apb.pclk or negedge apb.preset_n) begin

		//Reset
		if(!apb.preset_n) begin
			for(integer i=0; i<24; i=i+1) begin
				port_vlan[i]			<= 0;
				port_drop_tagged[i]		<= 0;
				port_drop_untagged[i]	<= 0;
			end
		end

		//Normal path
		else begin

			if(apb.pready && apb.pwrite) begin

				case(reg_id)

					REG_VLAN_CFG: begin
						port_drop_tagged[port_id]	<= apb.prdata[31];
						port_drop_untagged[port_id]	<= apb.prdata[30];
						port_vlan[port_id]			<= apb.prdata[11:0];
					end

					default: begin
					end
				endcase

			end

		end

	end
endmodule
