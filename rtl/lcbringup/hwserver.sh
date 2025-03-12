#!/bin/bash
source /opt/Xilinx/Vivado/2024.1/settings64.sh
hw_server -e "set jtag-port-filter Digilent/JTAG-HS2/210249BAA59F" -stcp::3190 -p 3090
