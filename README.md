# linreg

Hardware-accelerated gradient descent for linear regression on an FPGA.

The design pairs a **MicroBlaze soft processor** with a **custom AXI4-Stream IP core** that computes the gradient descent update rule in a single combinational pass:

```
θ := θ − (α/m) · Xᵀ · (Xθ − Y)
```

On a small dataset this yields an **8× speedup** over a pure software MicroBlaze implementation.

![](https://i.imgur.com/IPszi4A.png)

---

## Source Navigation

```
ip_repo/gradientdescent_1.0/
├── src/                          ← core algorithm (portable VHDL-2008)
│   ├── Types.vhd                   Q20.11 fixed-point types and arithmetic
│   ├── MiniBatchGradientDescent.vhd  top-level combinational pipeline
│   ├── matrix_multiply_by_vector.vhd m×n parallel multiply-accumulate
│   ├── matrix_transpose.vhd        pure wire routing, zero logic cost
│   ├── vector_subtract.vhd         parallel element-wise subtraction
│   ├── vector_multiply_by_scalar.vhd parallel Q20.11 scalar scaling
│   └── gradientdescent_testbench.vhd stimulus-only simulation testbench
└── hdl/                          ← AXI4-Stream interface wrappers
    ├── gradientdescent_v1_0.vhd    top-level IP wrapper (exposes m, n generics)
    ├── gradientdescent_v1_0_S00_AXIS.vhd  slave: decodes 6-instruction protocol,
    │                                      holds X/Y/θ/α registers, latches
    │                                      theta_new → theta for multi-iteration runs
    └── gradientdescent_v1_0_M00_AXIS.vhd  master: streams theta_new back word-by-word

linreg.sdk/microblaze/src/        ← MicroBlaze C application
    ├── helloworld.c                main loop: drives accelerator, reads results, benchmarks
    ├── instructions.c/h            encodes opcodes into 32-bit FSL words (putfsl)
    └── linreg.c/h                  convergence check and result printing

linreg.srcs/constrs_1/.../Nexys4_Master.xdc  ← constraints (only clock pin E3/100 MHz is active)
linreg.srcs/sources_1/bd/design_1/           ← Xilinx-generated block design (MicroBlaze, AXI interconnect, BRAM, UART)
```

### Key design details

**Fixed-point arithmetic** — all values use Q20.11 (32-bit signed, scale factor 2¹¹ = 2048). `element_multiply` uses a 64-bit intermediate and right-shifts 11 bits; all other ops work directly on signed 32-bit values.

**Instruction set** — the slave interface decodes the top 3 bits of each 32-bit AXI-Stream word:

| Opcode (bits 31:29) | Instruction | Payload |
|---|---|---|
| `000` | Store `X[i][j]` | bits 28:26 = row, 25:23 = col, 22:0 = value |
| `001` | Store `Y[i]` | bits 28:26 = index, 25:0 = value |
| `010` | Store `θ[i]` | bits 28:26 = index, 25:0 = value |
| `011` | Run iteration | bits 28:0 = count; if >1, latches theta_new → theta each cycle |
| `100` | Reset | clears all registers |
| `101` | Store `α` | bits 28:0 = learning rate |

**MicroBlaze ↔ IP communication** — uses the Fast Simplex Link (FSL) bus via `putfsl()`. Results are streamed back over the AXI master interface, one 32-bit word per clock cycle.

**Timing** — a fixed-interval timer fires every 100,000 clock cycles; the ISR increments `irqCount`. Elapsed time: `T = period × irqCount × fit`.

---

## Build on macOS with Docker

Vivado does not run natively on macOS. Use Docker to run it in an Ubuntu container.

### 1. Simulate (no Vivado needed)

Install the open-source VHDL toolchain natively:

```bash
brew install ghdl gtkwave
```

Simulate the core algorithm:

```bash
cd ip_repo/gradientdescent_1.0

ghdl -a --std=08 \
  src/Types.vhd \
  src/matrix_transpose.vhd \
  src/vector_subtract.vhd \
  src/vector_multiply_by_scalar.vhd \
  src/matrix_multiply_by_vector.vhd \
  src/MiniBatchGradientDescent.vhd \
  src/gradientdescent_testbench.vhd

ghdl -e --std=08 MiniBatchGradientDescentTest
ghdl -r --std=08 MiniBatchGradientDescentTest --vcd=sim.vcd
gtkwave sim.vcd
```

To add self-checking assertions (the current testbench is stimulus-only), use [cocotb](https://www.cocotb.org/):

```bash
pip install cocotb
```

```python
# test_gradient_descent.py
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_convergence(dut):
    await Timer(1, units="ns")
    theta0 = int(dut.theta_new[0].value) / 2048  # Q20.11 → float
    assert abs(theta0 - expected_theta0) < 0.01
```

### 2. Synthesize with Vivado in Docker

```bash
# Start an Ubuntu container with the project mounted
docker run -it --rm \
  -v $(pwd):/workspace \
  ubuntu:22.04 bash
```

Inside the container, install Vivado 2024.x (download from AMD, free WebPACK tier — Artix-7 is included), then run synthesis non-interactively:

```tcl
# synth_core.tcl
read_vhdl -vhdl2008 [glob ip_repo/gradientdescent_1.0/src/*.vhd]
read_xdc linreg.srcs/constrs_1/imports/Downloads/Nexys4_Master.xdc
synth_design -top MiniBatchGradientDescent -part xc7a100tcsg324-1
opt_design
place_design
route_design
write_bitstream -force output.bit
```

```bash
vivado -mode batch -source synth_core.tcl
```

---

## Flash to FPGA

[openFPGALoader](https://trabucayre.github.io/openFPGALoader/) supports common FPGA boards via their on-board FTDI USB chip — no Vivado Hardware Manager or proprietary drivers needed.

```bash
# macOS
brew install openfpgaloader

# Ubuntu / Debian
sudo apt install openfpgaloader
```

### Common boards

```bash
# Detect connected board
openFPGALoader --detect

# Nexys4 / Nexys4 DDR (Artix-7)
openFPGALoader -b nexys4 output.bit               # SRAM (lost on power cycle)
openFPGALoader -b nexys4 --write-flash output.bit # SPI flash (persistent)

# Basys3 (Artix-7)
openFPGALoader -b basys3 output.bit

# Arty A7-35T / A7-100T (Artix-7)
openFPGALoader -b arty output.bit
openFPGALoader -b arty_a7_100 output.bit

# iCE40 boards (e.g. iCEBreaker)
openFPGALoader -b icebreaker output.bit

# ECP5 boards (e.g. ULX3S)
openFPGALoader -b ulx3s output.bit
```

> **Note:** this design targets the Nexys4 (xc7a100tcsg324-1). To target a different Artix-7 board, change the `-part` flag in `synth_core.tcl` and the `-b` flag above. Other FPGA families require porting the block design (MicroBlaze, AXI interconnect).
