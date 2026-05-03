# AES-128 Hardware Accelerator Implementation

## Project Overview

This project implements a NIST FIPS-197 compliant AES-128 hardware accelerator in VHDL for the Basys 3 development board. The design focuses on a clear embedded-systems architecture: a reusable AES core, a small control FSM, deterministic key expansion, self-checking simulation testbenches, and hardware-in-the-loop validation from a host PC.

The intent is to show a complete engineering flow rather than a line-by-line source commentary. The README therefore explains the system architecture, the role of each VHDL module, the verification strategy, and the HIL workflow.

**Technical Summary**
- Algorithm: AES-128, 10 rounds, 128-bit block size
- Target clock: 100 MHz
- Typical timing result: above 120 MHz on the XC7A35T-1 device used on Basys 3
- Latency: 15 clock cycles per block
- Throughput: approximately 853 Mbps at 100 MHz
- Interface: synchronous start/done control
- Validation: VHDL simulation plus hardware-in-the-loop testing
- Host interface: USB serial UART

---

## Table of Contents

1. [Platform and Device](#1-platform-and-device)
2. [Architecture Overview](#2-architecture-overview)
3. [VHDL Module Roles](#3-vhdl-module-roles)
4. [Verification Strategy](#4-verification-strategy)
5. [Hardware-in-the-Loop Testing](#5-hardware-in-the-loop-testing)
6. [Synthesis and Constraints](#6-synthesis-and-constraints)
7. [Performance Summary](#7-performance-summary)
8. [Getting Started](#8-getting-started)
9. [References](#9-references)

---

## 1. Platform and Device

The design targets the Basys 3 board built around the AMD/Xilinx XC7A35T-1CPG236C Artix-7 FPGA.

**Relevant platform facts**
- 33,280 logic cells
- 20,800 6-input LUTs
- 41,600 flip-flops
- 50 block RAMs of 36 Kb each
- 90 DSP48E1 slices
- 5 clock management tiles
- 100 MHz onboard oscillator
- USB-UART interface on board
- 16 switches, 16 LEDs, 5 pushbuttons
- 4-digit seven-segment display

For this project, the important point is not only the device capacity but also the board-level simplicity: a stable 100 MHz clock, onboard USB connectivity, and enough I/O for basic control and status without external hardware.

**Why this board fits the project**
- The AES core is small enough that the XC7A35T has ample area margin.
- The onboard USB-UART bridge makes HIL testing straightforward.
- The 100 MHz oscillator matches the intended clock target.
- The board is common in teaching and prototyping, which makes the design easy to reproduce.
 - [add_round_key.vhd](design/transformations/add_round_key.vhd)

### 2.1 High-Level Data Flow

1. The host or testbench loads a 128-bit input block and a 128-bit key.
5. The result is presented on the output bus and flagged with `done`.

### 2.2 Why the Architecture Is Structured This Way

| Decision | Chosen Approach | Reason |
|---|---|---|
| Top-level structure | Single wrapper around FSM, datapath, and key expansion | Keeps integration clean and makes simulation easier |
| Datapath split | Separate datapath from control logic | Improves readability and lets control be tested independently |
| Key schedule split | Dedicated key expansion module | Avoids mixing round-key generation with round processing |
| External interface | Simple start/done handshake | Good fit for embedded validation and HIL use |

This is a classic embedded FPGA organization: control, data path, and reference-oriented verification are separated so each piece can be checked on its own.

---

## 3. VHDL Module Roles

### 3.1 Top Level
**[aes_top.vhd](design/aes_top.vhd)**

Role:
- Provides the external interface for clock, reset, start, mode, input data, key, output data, and done.
- Instantiates the FSM, datapath, and key expansion blocks.

Why it is separate:
- The top level is the integration boundary between the AES engine and the outside world.
- Keeping it thin makes synthesis, simulation, and board integration easier.

### 3.2 Control Logic

- Sequences the AES operation through idle, load, round, final-round, output, and wait behavior.
- Generates control signals for the datapath and key loading.

Why it is separate:
- AES control is easier to verify when it is isolated from the arithmetic logic.
- A dedicated FSM makes the handshake behavior explicit and predictable.

### 3.3 Datapath

**[aes_datapath.vhd](design/aes_datapath.vhd)**

Role:
- Performs the AES state transformations for encryption and decryption.
 Note about AddRoundKey and inverses:
 - The AddRoundKey operation is a 128-bit XOR of the state and the round key. XOR is self-inverse, so there is no separate "inverse" AddRoundKey module required — the same module can be used for both encryption and decryption paths.
- Selects the forward or inverse path based on mode.

Why it is separate:
- Datapath logic is the core cryptographic function, so keeping it independent from control improves reuse and testability.
- This also makes it easier to reason about timing closure.

### 3.4 Key Expansion
Why it is separate:
- Key schedule logic has different structure and verification needs from the round transformation datapath.
- A separate module keeps the design easier to maintain and compare against reference vectors.

### 3.5 Transformation Modules

The primitive transformations are implemented as separate VHDL blocks under [design/transformations](design/transformations).

- [mix_columns.vhd](design/transformations/mix_columns.vhd)
- [inv_mix_columns.vhd](design/transformations/inv_mix_columns.vhd)

Role:
- Each block implements one AES primitive.
- The forward and inverse paths stay structurally similar, which simplifies verification.

Why they are separate:
- Each transformation can be unit-tested independently.
- Separate blocks make simulation failure localization much easier.
- The design remains close to the AES specification while still being synthesizable.
### 3.6 Testbenches

The testbenches under [simulation/testbenches](simulation/testbenches) verify each functional block and the full system.

| Testbench | Purpose |
|---|---|
| [tb_sub_bytes.vhd](simulation/testbenches/tb_sub_bytes.vhd) | Verifies forward S-box behavior |
| [tb_inv_sub_bytes.vhd](simulation/testbenches/tb_inv_sub_bytes.vhd) | Verifies inverse S-box behavior |
| [tb_shift_rows.vhd](simulation/testbenches/tb_shift_rows.vhd) | Verifies forward byte permutation |
| [tb_inv_shift_rows.vhd](simulation/testbenches/tb_inv_shift_rows.vhd) | Verifies inverse byte permutation |
| [tb_mix_columns.vhd](simulation/testbenches/tb_mix_columns.vhd) | Verifies forward column mixing |
| [tb_inv_mix_columns.vhd](simulation/testbenches/tb_inv_mix_columns.vhd) | Verifies inverse column mixing |
| [tb_key_expansion.vhd](simulation/testbenches/tb_key_expansion.vhd) | Verifies round-key generation |
| [tb_aes_top.vhd](simulation/testbenches/tb_aes_top.vhd) | Verifies end-to-end encryption, decryption, and round-trip behavior |

- They make regression testing practical.
- They let each module be validated against known vectors before full integration.

---

### 4.1 Unit Verification

Each primitive transformation has its own dedicated testbench. That is the fastest way to catch defects in a controlled scope.

### 4.2 Integration Verification

The top-level testbench validates complete AES transactions:
- encryption against known vectors
- decryption against known vectors
- round-trip correctness

### 4.3 Why This Strategy Was Chosen
| Option | Why it was or was not chosen |
|---|---|
| Only top-level testing | Not enough isolation for debugging |
| Only unit testing | Does not prove system integration |
| Unit plus integration testing | Chosen, because it gives both local and system confidence |

### 4.4 Test Vector Basis

The project uses NIST FIPS-197 vectors as the primary reference set. That is the right choice because the implementation goal is specification compliance, not just internal consistency.

---

## 5. Hardware-in-the-Loop Testing

HIL testing validates the bitstream on the actual board against a software reference model on the PC.

### 5.1 HIL Components

- [hil/python/aes_hil_test.py](hil/python/aes_hil_test.py): Python test harness using pyserial and pycryptodome
- [hil/python/generate_vectors.py](hil/python/generate_vectors.py): Generates additional AES test vectors
- [hil/hil_verify.py](hil/hil_verify.py): Checks that the HIL environment is ready
- [hil/requirements.txt](hil/requirements.txt): Python dependencies
- [hil/vectors/test_vectors.txt](hil/vectors/test_vectors.txt): Reference vectors
### 5.3 HIL Communication Model
The HIL setup uses a simple ASCII serial protocol:
- `KEY` loads the key
- `MODE` selects encryption or decryption
- `DATA` loads the block
- `START` begins the operation

This was chosen because it is easy to debug, easy to log, and sufficient for a single-block validation workflow.

### 5.4 Why Not a More Complex Protocol

| Alternative | Why it was not chosen |
|---|---|
| Binary framed packets | Faster, but harder to inspect and debug |
| Interrupt-driven host control | More complex than needed for validation |
| Simple ASCII commands | Chosen, because clarity matters more than throughput here |

---

## 6. Synthesis and Constraints

### 6.1 Synthesis View

The design is intended to be small enough for the XC7A35T while still leaving headroom for timing closure and future integration.

### 6.2 Constraint Strategy

The constraint file [constraints/basys3_aes.xdc](constraints/basys3_aes.xdc) captures the board clock and the basic I/O mapping required for implementation.

### 6.3 Why the Constraint Set Is Minimal

This project is primarily a cryptographic accelerator and verification platform. Keeping the external interface minimal reduces risk and makes timing easier to close.

---

## 7. Performance Summary

At 100 MHz, the expected behavior is:

- 15 cycles per block
- about 150 ns per block
- about 853 Mbps throughput
- modest area use relative to the XC7A35T device

### 7.1 Why This Performance Is a Good Tradeoff

| Design Goal | Outcome |
|---|---|
| High clarity | Achieved through modular RTL and simple control |
| Good board fit | Achieved with low resource usage |
| Predictable validation | Achieved with self-checking testbenches and HIL |
| Very high throughput | Not the primary goal for this board class |

The design is therefore best viewed as a balanced embedded implementation, not an aggressively over-pipelined accelerator.

---

## 8. Getting Started

### 8.1 Simulation

Use Vivado or GHDL to run the testbenches. The top-level bench is [tb_aes_top.vhd](simulation/testbenches/tb_aes_top.vhd), and the module-level benches can be run independently.

### 8.2 Hardware Bring-Up

1. Program the Basys 3 board with the synthesized bitstream.
2. Connect the board to the PC using the onboard micro-USB cable.
3. Run the HIL environment from the [hil](hil) directory.
4. Execute [run_hil_tests.ps1](hil/run_hil_tests.ps1).

### 8.3 PC-to-FPGA Connection

For this project, you normally do not need extra hardware beyond the Basys 3 board and a data-capable micro-USB cable. The board already provides USB-JTAG and USB-UART on board, so the same connection is used for programming and for HIL communication.

If your laptop has only USB-C ports, then you should use a USB-C to micro-USB data cable or a USB-C adapter that supports data transfer.

---

## 9. References

- NIST FIPS-197, Advanced Encryption Standard (AES)
- Basys 3 reference documentation for board features and pinout
- VHDL-2008, IEEE 1076-2008
- pycryptodome documentation
- pyserial documentation

---

**Project Status:** Ready for simulation, synthesis, and HIL validation  
**Document Intent:** High-level engineering overview, module roles, and verification strategy  
**Last Updated:** April 30, 2026
