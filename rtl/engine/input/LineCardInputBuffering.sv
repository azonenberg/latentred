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
	@brief Input buffering for a LATENTRED line card

	Output stream
		TUSER is VLAN
		TDEST is {broadcast flag, dest port}
 */
module LineCardInputBuffering #(

	//Config for incoming CDC FIFOs
	parameter CDC_FIFO_DEPTH		= 256,
	parameter CDC_FIFO_USE_BLOCK	= 1,

	//Global index of the first port in our line card
	parameter BASE_PORT				= 0,

	//Index of the crossbar port we're attached to
	parameter XBAR_PORT				= 0,

	parameter NUM_PORTS				= 50,
	localparam PORT_BITS			= $clog2(NUM_PORTS),

	parameter MATRIX_ID				= "NONE"		//Nickname for the RAM cascade block for power reporting
)(

	//Main switch fabric clock
	input wire					clk_fabric,

	//VLAN configuration
	input wire vlan_t			port_vlan[23:0],
	input wire					drop_tagged[23:0],
	input wire					drop_untagged[23:0],

	//Interface to MAC address table
	AXIStream.transmitter		axi_lookup,
	AXIStream.receiver			axi_results,

	//Incoming data stream from each port (32-bit AXI4-Stream)
	AXIStream.receiver			axi_rx_portclk[23:0],

	//Outbound data stream to crossbar (64-bit AXI4-Stream)
	AXIStream.transmitter		axi_tx
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Validate buses are the correct size

	for(genvar g=0; g<24; g++) begin : bus_width_checks
		if(axi_rx_portclk[g].DATA_WIDTH != 32)
			axi_bus_width_bad();
		if(axi_rx_portclk[g].USER_WIDTH != 1)
			axi_bus_width_bad();
		if(axi_rx_portclk[g].ID_WIDTH != 0)
			axi_bus_width_bad();
		if(axi_rx_portclk[g].DEST_WIDTH != 0)
			axi_bus_width_bad();
	end

	if(axi_lookup.DATA_WIDTH != (108 + PORT_BITS) )
		axi_bus_width_bad();
	if(axi_lookup.ID_WIDTH != 5)
		axi_bus_width_bad();
	if(axi_lookup.DEST_WIDTH != 2)
		axi_bus_width_bad();

	if(axi_results.DATA_WIDTH != PORT_BITS)
		axi_bus_width_bad();
	if(axi_results.ID_WIDTH != 5)
		axi_bus_width_bad();
	if(axi_results.USER_WIDTH != 1)
		axi_bus_width_bad();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shift all of the incoming data to the fabric clock domain

	AXIStream #(.DATA_WIDTH(32), .ID_WIDTH(0), .DEST_WIDTH(0), .USER_WIDTH(1)) axi_rx_coreclk[23:0]();

	for(genvar g=0; g<24; g++) begin : incoming_cdc
		AXIS_CDC #(
			.FIFO_DEPTH(CDC_FIFO_DEPTH),
			.USE_BLOCK(CDC_FIFO_USE_BLOCK)
		) cdc (
			.axi_rx(axi_rx_portclk[g]),
			.tx_clk(clk_fabric),
			.axi_tx(axi_rx_coreclk[g])
		);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helpers for CASCADE_ORDER parameter

	function string CascadeOrder(input integer i);
		if(i == 0)
			return "FIRST";
		else if(i == 23)
			return "LAST";
		else
			return "MIDDLE";
	endfunction

	function string CascadeRegB(input integer i);
		case(i)
			5:	return "TRUE";
			10:	return "TRUE";
			15: return "TRUE";
			21: return "TRUE";
			default:	return "FALSE";
		endcase
	endfunction

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The RAM cascade chain itself

	//A port is not cascaded (separate write port for each incoming port)
	//B port is cascaded

	//South end of each port on the B side
	//[0] is tied to ground to start the cascade
	//[1] is cascade from block 0 to 1
	//[2] is cascade from block 1 to 2, etc
	UltraRAMCascadeBus portb_cascade[24:0]();
	UltraRAMCascadeTieoff tieoff_south_b(.tieoff(portb_cascade[0]));

	//Port A signals (writing data from CDCs to main FIFO)
	wire		wr_en[23:0];
	wire[11:0]	wr_addr[23:0];
	wire[71:0]	wr_data[23:0];

	//Port B bus (inputs on block 0, outputs on block 23)
	wire		rd_en;
	wire[16:0]	rd_addr;
	wire[71:0]	rd_data;
	wire		rd_valid;

	for(genvar g=0; g<24; g++) begin : core_ram

		//Tieoffs for cascade ports on the A side
		UltraRAMCascadeBus porta_cascade_north();
		UltraRAMCascadeBus porta_cascade_south();
		//north cascade gets floated, no need to tie off since they're all outputs
		UltraRAMCascadeTieoff porta_tieoff_south(.tieoff(porta_cascade_south));

		//Port B signals (mostly unused and tied off except for first/last block)
		wire		portb_en;
		wire[22:0]	portb_addr;
		wire[71:0]	portb_rdata;
		wire		portb_rvalid;

		//Drive port B inputs to block 0, tie off others
		if(g == 0) begin
			assign portb_en		= rd_en;
			assign portb_addr	= { 6'h0, rd_addr };
		end
		else begin
			assign portb_en		= 0;
			assign portb_addr	= 23'h0;
		end

		//Pick off the outputs from block 23
		if(g == 23) begin
			assign rd_data		= portb_rdata;
			assign rd_valid		= portb_rvalid;
		end

		UltraRAMWrapper #(
			.CASCADE_ORDER_A("NONE"),
			.CASCADE_ORDER_B(CascadeOrder(g)),
			.OUT_REG_B("TRUE"),
			.CASCADE_REG_B(CascadeRegB(g)),
			.SELF_ADDR_A(11'h000),
			.SELF_ADDR_B(g[10:0]),
			.SELF_MASK_A(11'h7ff),
			.SELF_MASK_B(11'h7e0)	//bitmask 16:12 valid, high bits not needed
		) uram (

			//Shared clock and power management
			.clk(clk_fabric),
			.sleep(1'b0),

			//Port A: write only, not cascaded, no byte lane masking
			.a_en(wr_en[g]),
			.a_addr({11'h0, wr_addr[g]}),
			.a_wr(wr_en[g]),
			.a_bwe(9'h1ff),
			.a_wdata(wr_data[g]),
			.a_inject_seu(1'b0),
			.a_inject_deu(1'b0),
			.a_core_ce(1'b1),
			.a_ecc_ce(1'b1),
			.a_rst(1'b0),
			.a_rdata(),
			.a_rdaccess(),
			.a_seu(),
			.a_deu(),

			.b_en(portb_en),
			.b_addr(portb_addr),
			.b_wr(1'b0),
			.b_bwe(9'h0),
			.b_wdata(72'h0),
			.b_inject_seu(1'b0),
			.b_inject_deu(1'b0),
			.b_core_ce(1'b1),
			.b_ecc_ce(1'b1),
			.b_rst(1'b0),
			.b_rdata(portb_rdata),
			.b_rdaccess(portb_rvalid),
			.b_seu(),
			.b_deu(),

			.a_cascade_south(porta_cascade_south),
			.a_cascade_north(porta_cascade_north),

			.b_cascade_south(portb_cascade[g]),
			.b_cascade_north(portb_cascade[g+1])
		);

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO write logic: pop frames from CDC, check CRC status, write to URAM

	wire		rd_ptr_reset[23:0];
	wire[12:0]	rd_ptr[23:0];
	wire[12:0]	wr_ptr_committed[23:0];

	for(genvar g=0; g<24; g=g+1) begin : fifos

		//Decode VLAN tags
		AXIStream #(.DATA_WIDTH(32), .ID_WIDTH(0), .DEST_WIDTH(12), .USER_WIDTH(1)) decoded();

		AXIS_VLANTagDecoder vlan_decoder(
			.axi_rx(axi_rx_coreclk[g]),
			.axi_tx(decoded),

			.port_vlan(port_vlan[g]),
			.drop_tagged(drop_tagged[g]),
			.drop_untagged(drop_untagged[g])
		);

		//The actual FIFO controller
		GigabitIngressFIFO ctrl(
			.axi_rx(decoded),

			.wr_en(wr_en[g]),
			.wr_addr(wr_addr[g]),
			.wr_data(wr_data[g]),

			.wr_ptr_committed(wr_ptr_committed[g]),
			.rd_ptr(rd_ptr[g])
		);

		assign rd_ptr_reset[g] = !decoded.areset_n;

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Reading and routing logic

	LineCardFIFOReader #(
		.BASE_PORT(BASE_PORT),
		.XBAR_PORT(XBAR_PORT)
	) reader (
		.clk(clk_fabric),

		.rd_en(rd_en),
		.rd_addr(rd_addr),
		.rd_data(rd_data),
		.rd_valid(rd_valid),

		.rd_ptr(rd_ptr),
		.rd_ptr_reset(rd_ptr_reset),
		.wr_ptr_committed(wr_ptr_committed),

		.axi_lookup(axi_lookup),
		.axi_results(axi_results),

		.axi_tx(axi_tx)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug ILA

	//Debug: register axi signals so we can see them in the ILA with proper netnames
	logic		tvalid_ff	= 0;
	logic[63:0]	tdata_ff	= 0;
	logic[7:0]	tkeep_ff	= 0;
	logic[7:0]	tstrb_ff	= 0;
	logic[6:0]	tdest_ff	= 0;
	logic[11:0]	tuser_ff	= 0;
	logic		tlast_ff	= 0;
	logic		tready_ff	= 0;

	always_ff @(posedge clk_fabric) begin
		tvalid_ff	<= axi_tx.tvalid;
		tdata_ff	<= axi_tx.tdata;
		tkeep_ff	<= axi_tx.tkeep;
		tstrb_ff	<= axi_tx.tstrb;
		tlast_ff	<= axi_tx.tlast;
		tdest_ff	<= axi_tx.tdest;
		tuser_ff	<= axi_tx.tuser;
		tready_ff	<= axi_tx.tready;
	end

	ila_2 ila(
		.clk(clk_fabric),

		.probe0(rd_ptr[0]),
		.probe1(rd_ptr_reset[0]),
		.probe2(wr_ptr_committed[0]),
		.probe3(rd_en),
		.probe4(rd_addr),
		.probe5(rd_data),
		.probe6(rd_valid),
		.probe7(axi_lookup.tvalid),
		.probe8(axi_lookup.tid),
		.probe9(axi_results.tvalid),
		.probe10(axi_results.tuser),
		.probe11(tuser_ff),
		.probe12(tvalid_ff),
		.probe13(tdata_ff),
		.probe14(tkeep_ff),
		.probe15(tstrb_ff),
		.probe16(tlast_ff),
		.probe17(tdest_ff),
		.probe18(reader.port_states[0]),
		.probe19(reader.port_vlans[0]),
		.probe20(reader.port_src_mac[0]),
		.probe21(reader.port_dst_mac[0]),
		.probe22(reader.port_lens[0]),
		.probe23(reader.meta_rdata),
		.probe24(reader.prefetch_wr_en),
		.probe25(reader.fwd_bytesToRead),
		.probe26(reader.fwd_bytesToSend),
		.probe27(reader.fifo_rd_size[0]),
		.probe28(reader.fwd_state),
		.probe29(fifos[0].decoded.tvalid),
		.probe30(fifos[0].decoded.tdata),
		.probe31(fifos[0].decoded.tstrb),
		.probe32(fifos[0].decoded.tlast),
		.probe33(fifos[0].ctrl.wr_en),
		.probe34(fifos[0].ctrl.wr_state),
		.probe35(fifos[0].ctrl.frame_len),
		.probe36(fifos[0].ctrl.wr_data),
		.probe37(reader.prefetch_rd_addr),
		.probe38(tready_ff)
	);

endmodule
