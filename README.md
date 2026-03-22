# AXI4-Lite Register File with Multi-Clock Domain CDC

A fully verified AXI4-Lite compliant slave interface featuring a dual-FSM architecture managing **8 memory-mapped registers** across asynchronous `PCLK` and `SCLK` clock domains. Designed and validated for **Cadence Xcelium** simulation with formal CDC verification support via Cadence Conformal CDC.

---

## Features

- **AXI4-Lite Slave Interface** — Full read/write FSM with proper handshake sequencing (`AWVALID/AWREADY`, `WVALID/WREADY`, `BVALID/BREADY`, `ARVALID/ARREADY`, `RVALID/RREADY`)
- **Dual Clock Domain Design** — Asynchronous `PCLK` (AXI bus) and `SCLK` (peripheral) domains with no shared clock assumption
- **3-Stage Gray Code Synchronizers** — CDC-safe multi-bit data transfer using asynchronous FIFO with Gray-coded pointers
- **Toggle-Based Pulse Synchronizers** — Guaranteed interrupt delivery across clock domains with no pulse loss
- **8 Memory-Mapped Registers** — Control, Status, Data In/Out, Interrupt Enable, Interrupt Status (W1C), and two Scratchpad registers
- **30+ SystemVerilog Assertions** — AXI4-Lite protocol compliance, handshake stability, reset recovery, and address range checks
- **Cadence Conformal CDC Script** — Formal CDC verification constraints with custom synchronizer topology declarations

---

## Architecture Overview

```
        PCLK Domain                          SCLK Domain
   ┌─────────────────────┐             ┌──────────────────────┐
   │   AXI4-Lite Slave   │             │  Peripheral Logic    │
   │  ┌───────────────┐  │             │                      │
   │  │  Write FSM    │  │──Reg[0]────►│  app_ctrl_reg        │
   │  │  Read  FSM    │  │  (3-stage   │  (Gray Sync)         │
   │  └───────────────┘  │   sync)     │                      │
   │                     │             │                      │
   │  8 Register File    │──Reg[2]────►│  app_data_out        │
   │  [0] Control   (RW) │  (Async     │  (CDC FIFO P→S)      │
   │  [1] Status    (RO) │   FIFO)     │                      │
   │  [2] Data Out  (RW) │◄─Reg[3]────│  app_data_in         │
   │  [3] Data In   (RO) │  (Async     │  (CDC FIFO S→P)      │
   │  [4] Intr En   (RW) │   FIFO)     │                      │
   │  [5] Intr Stat (W1C)│◄───────────│  app_intr_req        │
   │  [6] Scratch0  (RW) │  (Toggle    │  (Pulse Sync S→P)    │
   │  [7] Scratch1  (RW) │   Sync)     │                      │
   └─────────────────────┘             └──────────────────────┘
```

---

## Repository Structure

```
AXI4/
├── rtl/
│   ├── synchronizer.sv         # sync_3stage, toggle_pulse_sync, gray_sync
│   ├── cdc_fifo.sv             # Asynchronous FIFO with Gray-coded pointers
│   ├── axi4_cdc_reg_file.sv    # Top-level: AXI FSMs + 8 register file + CDC
│   └── axi4_sva.sv             # 30+ SVA protocol checker (bind-based)
├── tb/
│   └── tb_axi4_cdc_reg_file.sv # Self-checking testbench (6 directed tests)
├── scripts/
│   ├── run_xcelium.sh          # Cadence Xcelium compilation & simulation script
│   └── conformal_cdc.tcl       # Cadence Conformal CDC formal verification script
└── README.md
```

---

## Register Map

| Offset | Register       | Access | Description                              |
|--------|----------------|--------|------------------------------------------|
| `0x00` | Control        | RW     | Control bits, synced to SCLK via 3-stage |
| `0x04` | Status         | RO     | Status from SCLK peripheral, synced to PCLK |
| `0x08` | Data Out       | RW     | PCLK→SCLK data path via Async FIFO      |
| `0x0C` | Data In        | RO     | SCLK→PCLK data path via Async FIFO      |
| `0x10` | Interrupt En   | RW     | Bit[0] enables interrupt output          |
| `0x14` | Interrupt Stat | W1C    | Bit[0] set by SCLK interrupt, write-1-clear |
| `0x18` | Scratchpad 0   | RW     | General purpose scratchpad               |
| `0x1C` | Scratchpad 1   | RW     | General purpose scratchpad               |

---

## CDC Architecture

| Signal Path          | Technique                  | Why                                     |
|----------------------|----------------------------|-----------------------------------------|
| Control (PCLK→SCLK)  | 3-stage synchronizer       | Slow-changing control bits              |
| Status (SCLK→PCLK)   | 3-stage synchronizer       | Slow-changing status bits               |
| Data Out (PCLK→SCLK) | Async FIFO (Gray pointers) | Multi-bit — prevents structural hazards |
| Data In (SCLK→PCLK)  | Async FIFO (Gray pointers) | Multi-bit — prevents structural hazards |
| Interrupt (SCLK→PCLK)| Toggle pulse synchronizer  | Guarantees no pulse is lost             |

---

## Simulation Results (Cadence Xcelium 23.09)

All 6 directed tests pass with **0 errors** and **0 assertion failures**:

```
✅ Test 1: Control sync passed!          (PCLK→SCLK via 3-stage sync)
✅ Test 2: Interrupt Enable written
✅ Test 3: Interrupt sync passed!        (SCLK→PCLK toggle pulse)
✅ Test 4: Interrupt cleared successfully (W1C register)
✅ Test 5: PCLK->SCLK Data Transferred  (Async FIFO, 32-bit data)
✅ Test 6: SCLK->PCLK Data Transferred  (Async FIFO, 32-bit data)

All tests passed! Simulation complete at 925 NS.
```

| Metric           | Value           |
|------------------|-----------------|
| Compilation Errors | 0             |
| Simulation Errors  | 0             |
| SVA Assertions     | 26 active, 0 fired |
| FSMs Extracted     | 2 (Write FSM, Read FSM) |
| Coverage Types     | Block, Expression, FSM, Toggle |

---

## How to Run

### Prerequisites
- Cadence Xcelium (tested on version `23.09-s003`)
- Linux environment with Cadence tools sourced

### Simulation
```bash
# 1. Source your Cadence environment
source /tools/cadence/xcelium/bin/cdsvars.sh

# 2. Navigate to scripts directory
cd AXI4/scripts

# 3. Run simulation
chmod +x run_xcelium.sh
./run_xcelium.sh
```

### Formal CDC Analysis (Optional)
```bash
# Requires Cadence Conformal CDC license
conformal -cdc -tcl conformal_cdc.tcl
```

Coverage reports are generated in `scripts/cov_work/`. Waveforms are saved to `scripts/wave.vcd` and can be opened with SimVision:
```bash
simvision wave.vcd
```

---

## Tools & Technologies

![SystemVerilog](https://img.shields.io/badge/SystemVerilog-RTL%20%2B%20SVA-blue)
![Cadence Xcelium](https://img.shields.io/badge/Cadence-Xcelium%2023.09-red)
![TCL](https://img.shields.io/badge/TCL-Conformal%20CDC-green)

- **HDL**: SystemVerilog (IEEE 1800-2017)
- **Simulator**: Cadence Xcelium (`xrun`)
- **Formal CDC**: Cadence Conformal CDC (TCL constraints)
- **Waveform Viewer**: Cadence SimVision
- **Scripting**: Bash, TCL

---

## Key Design Decisions

- **Why Toggle Sync for interrupts?** A simple 2/3-stage flip-flop sync can miss a pulse if it's shorter than the destination clock period. The toggle-based synchronizer converts a pulse into a level change that is guaranteed to be captured regardless of the relative clock frequencies.
- **Why Async FIFO for multi-bit data?** Sending all 32 data bits through individual synchronizers creates structural CDC hazards (bits may be captured in different clock edges). The Async FIFO with Gray-coded pointers ensures atomicity — the read side only sees a valid, complete data word.
- **Why bind-based SVA?** Keeping SVA assertions in a separate module bound to the DUT keeps the RTL clean and synthesizable, while the checker is simulation-only and can be cleanly excluded from synthesis.

---

## Author

**Vishal Ayyappan**  
ECE Graduate | Hardware Design & Verification  
