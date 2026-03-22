#!/bin/bash
# Script to compile and simulate AXI4 CDC Register File with Cadence Xcelium
set -e

echo "Starting Xcelium Compilation and Simulation..."

# Create reports directory if not exists
mkdir -p xmsim_reports

# Run Xcelium
xrun -sv \
    -incdir ../rtl \
    ../rtl/synchronizer.sv \
    ../rtl/cdc_fifo.sv \
    ../rtl/axi4_cdc_reg_file.sv \
    ../rtl/axi4_sva.sv \
    ../tb/tb_axi4_cdc_reg_file.sv \
    -access +rwc \
    -assert \
    -nocopyright \
    -vtimescale 1ns/1ps \
    -coverage all \
    -covoverwrite \
    -l xmsim_reports/xrun.log

echo "Simulation completed. Reports generated in xmsim_reports/"
