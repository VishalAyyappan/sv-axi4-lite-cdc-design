# Cadence Conformal CDC Analysis Script for AXI4 Multi-Clock Domain Register File

# 1. Read Design
# ----------------------------------------
read_design -systemverilog \
    ../rtl/synchronizer.sv \
    ../rtl/cdc_fifo.sv \
    ../rtl/axi4_cdc_reg_file.sv

# Elaborate top level
elaborate axi4_cdc_reg_file

# 2. Clock Definition
# ----------------------------------------
# PCLK domain 
create_clock -name pclk -period 10 pclk
# SCLK domain 
create_clock -name sclk -period 26 sclk

# 3. Reset Definition
# ----------------------------------------
create_reset -name presetn -active_low presetn
create_reset -name sresetn -active_low sresetn

# 4. CDC Custom Synchronizers Configuration
# ----------------------------------------
# Register our custom 3-stage module
set_cdc_synchronizer -name sync_3stage -stages 3

# Register multi-bit Gray code sync 
set_cdc_synchronizer_type -name gray_sync -type gray_code

# Register custom Toggle pulse sync
set_cdc_synchronizer_type -name toggle_pulse_sync -type pulse

# 5. Setup path exceptions
# ----------------------------------------
# AXI read/write addresses expected to be stable during valid handshakes
set_cdc_false_path -from [get_ports s_axi_awaddr*]
set_cdc_false_path -from [get_ports s_axi_araddr*]

# 6. Run Analysis & Report
# ----------------------------------------
check_cdc -detail -out cdc_reports/cdc_violations.rpt
report_cdc_synchronizers > cdc_reports/cdc_synchronizers.rpt

puts "Formal CDC Analysis Configuration completed."
