set_max_delay -datapath_only -from [get_cells [list apb1/devinfo/sync_die_serial/sync_en/rx_a_ff_reg apb1/devinfo/sync_idcode/sync_en/rx_a_ff_reg bridge/sync_apb_ack/sync_en/rx_a_ff_reg bridge/sync_apb_completion/sync_en/rx_a_ff_reg]] -to [get_cells [list {apb1/devinfo/sync_die_serial/reg_b_reg[0]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[10]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[11]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[12]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[13]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[14]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[15]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[16]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[17]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[18]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[19]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[1]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[20]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[21]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[22]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[23]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[24]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[25]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[26]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[27]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[28]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[29]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[2]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[30]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[31]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[32]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[33]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[34]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[35]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[36]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[37]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[38]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[39]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[3]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[40]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[41]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[42]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[43]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[44]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[45]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[46]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[47]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[48]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[49]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[4]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[50]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[51]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[52]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[53]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[54]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[55]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[56]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[57]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[58]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[59]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[5]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[60]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[61]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[62]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[63]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[6]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[7]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[8]} \
          {apb1/devinfo/sync_die_serial/reg_b_reg[9]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[0]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[10]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[11]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[12]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[13]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[14]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[15]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[16]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[17]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[18]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[19]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[1]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[20]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[21]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[22]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[23]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[24]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[25]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[26]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[27]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[28]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[29]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[2]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[30]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[31]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[3]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[4]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[5]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[6]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[7]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[8]} \
          {apb1/devinfo/sync_idcode/reg_b_reg[9]} \
          {bridge/sync_apb_ack/reg_b_reg[0]} \
          {bridge/sync_apb_ack/reg_b_reg[10]} \
          {bridge/sync_apb_ack/reg_b_reg[11]} \
          {bridge/sync_apb_ack/reg_b_reg[12]} \
          {bridge/sync_apb_ack/reg_b_reg[13]} \
          {bridge/sync_apb_ack/reg_b_reg[14]} \
          {bridge/sync_apb_ack/reg_b_reg[15]} \
          {bridge/sync_apb_ack/reg_b_reg[16]} \
          {bridge/sync_apb_ack/reg_b_reg[17]} \
          {bridge/sync_apb_ack/reg_b_reg[18]} \
          {bridge/sync_apb_ack/reg_b_reg[19]} \
          {bridge/sync_apb_ack/reg_b_reg[1]} \
          {bridge/sync_apb_ack/reg_b_reg[20]} \
          {bridge/sync_apb_ack/reg_b_reg[21]} \
          {bridge/sync_apb_ack/reg_b_reg[22]} \
          {bridge/sync_apb_ack/reg_b_reg[23]} \
          {bridge/sync_apb_ack/reg_b_reg[24]} \
          {bridge/sync_apb_ack/reg_b_reg[25]} \
          {bridge/sync_apb_ack/reg_b_reg[26]} \
          {bridge/sync_apb_ack/reg_b_reg[27]} \
          {bridge/sync_apb_ack/reg_b_reg[28]} \
          {bridge/sync_apb_ack/reg_b_reg[29]} \
          {bridge/sync_apb_ack/reg_b_reg[2]} \
          {bridge/sync_apb_ack/reg_b_reg[30]} \
          {bridge/sync_apb_ack/reg_b_reg[31]} \
          {bridge/sync_apb_ack/reg_b_reg[32]} \
          {bridge/sync_apb_ack/reg_b_reg[3]} \
          {bridge/sync_apb_ack/reg_b_reg[4]} \
          {bridge/sync_apb_ack/reg_b_reg[5]} \
          {bridge/sync_apb_ack/reg_b_reg[6]} \
          {bridge/sync_apb_ack/reg_b_reg[7]} \
          {bridge/sync_apb_ack/reg_b_reg[8]} \
          {bridge/sync_apb_ack/reg_b_reg[9]} \
          {bridge/sync_apb_completion/reg_b_reg[0]} \
          {bridge/sync_apb_completion/reg_b_reg[10]} \
          {bridge/sync_apb_completion/reg_b_reg[11]} \
          {bridge/sync_apb_completion/reg_b_reg[12]} \
          {bridge/sync_apb_completion/reg_b_reg[13]} \
          {bridge/sync_apb_completion/reg_b_reg[14]} \
          {bridge/sync_apb_completion/reg_b_reg[15]} \
          {bridge/sync_apb_completion/reg_b_reg[16]} \
          {bridge/sync_apb_completion/reg_b_reg[17]} \
          {bridge/sync_apb_completion/reg_b_reg[18]} \
          {bridge/sync_apb_completion/reg_b_reg[19]} \
          {bridge/sync_apb_completion/reg_b_reg[1]} \
          {bridge/sync_apb_completion/reg_b_reg[20]} \
          {bridge/sync_apb_completion/reg_b_reg[21]} \
          {bridge/sync_apb_completion/reg_b_reg[22]} \
          {bridge/sync_apb_completion/reg_b_reg[23]} \
          {bridge/sync_apb_completion/reg_b_reg[24]} \
          {bridge/sync_apb_completion/reg_b_reg[25]} \
          {bridge/sync_apb_completion/reg_b_reg[26]} \
          {bridge/sync_apb_completion/reg_b_reg[27]} \
          {bridge/sync_apb_completion/reg_b_reg[28]} \
          {bridge/sync_apb_completion/reg_b_reg[29]} \
          {bridge/sync_apb_completion/reg_b_reg[2]} \
          {bridge/sync_apb_completion/reg_b_reg[30]} \
          {bridge/sync_apb_completion/reg_b_reg[31]} \
          {bridge/sync_apb_completion/reg_b_reg[32]} \
          {bridge/sync_apb_completion/reg_b_reg[33]} \
          {bridge/sync_apb_completion/reg_b_reg[3]} \
          {bridge/sync_apb_completion/reg_b_reg[4]} \
          {bridge/sync_apb_completion/reg_b_reg[5]} \
          {bridge/sync_apb_completion/reg_b_reg[6]} \
          {bridge/sync_apb_completion/reg_b_reg[7]} \
          {bridge/sync_apb_completion/reg_b_reg[8]} \
          {bridge/sync_apb_completion/reg_b_reg[9]}]] 5.000
set_max_delay -from [get_cells [list bridge/link_layer/sync_rx_to_tx_ll_link_up/dout0_reg bridge/tx_cdc/sync_ctl/sync_tx_ack/dout0_reg bridge/tx_cdc/sync_ctl/sync_tx_en/dout0_reg]] -to [get_cells [list apb1/devinfo/sync_die_serial/sync_ack/sync/dout1_reg \
          apb1/devinfo/sync_die_serial/sync_en/sync/dout1_reg \
          apb1/devinfo/sync_idcode/sync_ack/sync/dout1_reg \
          apb1/devinfo/sync_idcode/sync_en/sync/dout1_reg \
          bridge/link_layer/sync_rx_to_tx_ll_link_up/dout1_reg \
          bridge/sync_apb_ack/sync_ack/sync/dout1_reg \
          bridge/sync_apb_ack/sync_en/sync/dout1_reg \
          bridge/sync_apb_completion/sync_ack/sync/dout1_reg \
          bridge/sync_apb_completion/sync_en/sync/dout1_reg \
          bridge/tx_cdc/sync_ctl/sync_tx_ack/dout1_reg \
          bridge/tx_cdc/sync_ctl/sync_tx_en/dout1_reg]] 5.000
########################################################################################################################
# Pinout constraints
set_property PACKAGE_PIN W19 [get_ports clk_25mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_25mhz]
set_property PACKAGE_PIN AB20 [get_ports {led[3]}]
set_property PACKAGE_PIN AA21 [get_ports {led[2]}]
set_property PACKAGE_PIN AB21 [get_ports {led[1]}]
set_property PACKAGE_PIN AB22 [get_ports {led[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_a_hi[0]}]
set_property PACKAGE_PIN C22 [get_ports {fmc_a_hi[0]}]
set_property PACKAGE_PIN B22 [get_ports {fmc_a_hi[1]}]
set_property PACKAGE_PIN D21 [get_ports {fmc_a_hi[2]}]
set_property PACKAGE_PIN M22 [get_ports {fmc_a_hi[3]}]
set_property PACKAGE_PIN N22 [get_ports {fmc_a_hi[4]}]
set_property PACKAGE_PIN N20 [get_ports {fmc_a_hi[5]}]
set_property PACKAGE_PIN L19 [get_ports {fmc_a_hi[6]}]
set_property PACKAGE_PIN M21 [get_ports {fmc_a_hi[7]}]
set_property PACKAGE_PIN K21 [get_ports {fmc_a_hi[8]}]
set_property PACKAGE_PIN J22 [get_ports {fmc_a_hi[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_ad[0]}]
set_property PACKAGE_PIN A20 [get_ports {fmc_ad[15]}]
set_property PACKAGE_PIN A21 [get_ports {fmc_ad[14]}]
set_property PACKAGE_PIN B20 [get_ports {fmc_ad[13]}]
set_property PACKAGE_PIN B18 [get_ports {fmc_ad[12]}]
set_property PACKAGE_PIN A19 [get_ports {fmc_ad[11]}]
set_property PACKAGE_PIN B21 [get_ports {fmc_ad[10]}]
set_property PACKAGE_PIN L20 [get_ports {fmc_ad[9]}]
set_property PACKAGE_PIN A18 [get_ports {fmc_ad[8]}]
set_property PACKAGE_PIN B16 [get_ports {fmc_ad[7]}]
set_property PACKAGE_PIN B17 [get_ports {fmc_ad[6]}]
set_property PACKAGE_PIN D16 [get_ports {fmc_ad[5]}]
set_property PACKAGE_PIN A16 [get_ports {fmc_ad[4]}]
set_property PACKAGE_PIN H20 [get_ports {fmc_ad[3]}]
set_property PACKAGE_PIN H19 [get_ports {fmc_ad[2]}]
set_property PACKAGE_PIN E16 [get_ports {fmc_ad[1]}]
set_property PACKAGE_PIN D22 [get_ports {fmc_ad[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_nbl[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fmc_nbl[0]}]
set_property PACKAGE_PIN K19 [get_ports {fmc_nbl[1]}]
set_property PACKAGE_PIN L21 [get_ports {fmc_nbl[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_clk]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_ne1]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_ne2]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_ne3]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_nl_nadv]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_noe]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_nwait]
set_property IOSTANDARD LVCMOS33 [get_ports fmc_nwe]
set_property PACKAGE_PIN J19 [get_ports fmc_clk]
set_property PACKAGE_PIN E22 [get_ports fmc_ne1]
set_property PACKAGE_PIN E21 [get_ports fmc_ne3]
set_property PACKAGE_PIN K22 [get_ports fmc_nl_nadv]
set_property PACKAGE_PIN J21 [get_ports fmc_ne2]
set_property PACKAGE_PIN J20 [get_ports fmc_noe]
set_property PACKAGE_PIN G20 [get_ports fmc_nwait]
set_property PACKAGE_PIN H22 [get_ports fmc_nwe]
set_property IOSTANDARD LVCMOS33 [get_ports eth_mdc]

set_property PACKAGE_PIN W22 [get_ports eth_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports mdio]
set_property IOSTANDARD LVCMOS33 [get_ports mdio_tx_en]
set_property PACKAGE_PIN V22 [get_ports mdio_tx_en]
set_property PACKAGE_PIN Y22 [get_ports mdio]

########################################################################################################################
# Clocks

create_clock -period 40.000 -name clk_25mhz -waveform {0.000 20.000} [get_ports clk_25mhz]
create_clock -period 7.273 -name fmc_clk -waveform {0.000 3.637} [get_ports fmc_clk]

########################################################################################################################
# CDC constraints

# Synchronizer max delays: 5 ns (200 MHz) is << 1 cycle of both clocks
set_max_delay -datapath_only -from [get_cells -hierarchical -filter { NAME =~  "*sync*" && NAME =~  "*a_ff*" }] -to [get_cells -hierarchical -filter { NAME =~  "*sync*" && NAME =~  "*reg_b*" }] 5.000
set_max_delay -from [get_cells -hierarchical -filter { NAME =~  "*sync*" && NAME =~  "*dout0_reg*" }] -to [get_cells -hierarchical -filter { NAME =~  "*sync*" && NAME =~  "*dout1_reg*" }] 5.000

# APB clock domain crossings: 5 ns (200 MHz) is << 1 cycle of both clocks

# Async clock domains
set_clock_groups -asynchronous -group [get_clocks clk_25mhz] -group [get_clocks pclk_raw]

########################################################################################################################
# Put the timestamp in the bitstream USERCODE

set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]

set_property PACKAGE_PIN F6 [get_ports gtp_refclk_p]
set_property PACKAGE_PIN A8 [get_ports sfp_rx_n]
create_clock -period 6.400 -name gtp_refclk_p -waveform {0.000 3.200} [get_ports gtp_refclk_p]

set_clock_groups -asynchronous -group [get_clocks clkout0] -group [get_clocks clkout0_1]
set_clock_groups -asynchronous -group [get_clocks pclk_raw] -group [get_clocks clkout0_1]
set_clock_groups -asynchronous -group [get_clocks clkout0_1] -group [get_clocks pclk_raw]
