# Single-Cycle RV32IM Processor

A modular SystemVerilog implementation of a 32-bit RISC-V processor supporting the RV32I base integer instruction set and RV32M multiplication and division extension.

Developed as part of the Computer Organization and Design (COD) course project at PES University.

## Project Overview

The processor implements:
- RV32I integer arithmetic and logical operations.
- Immediate arithmetic and logical operations.
- Conditional branches and jumps.
- Load and store instructions.
- RV32M multiplication, division and remainder operations.
- Register-file access and writeback.
- External instruction and data memory interfaces for course evaluation.

The design is organised into modular SystemVerilog components for instruction decoding, immediate generation, register access, execution, program-counter control and writeback.

## Architecture

```text
External Instruction Memory
           |
           v
     Instruction Fetch
           |
           v
    Instruction Decode
           |
           v
      Register Bank
           |
           v
     Execution Unit
       /        \
      v          v
  RV32I ALU   RV32M ALU
       \        /
        v      v
      ALU Result
           |
           v
   External Data Memory
           |
           v
       Writeback
           |
           v
      Register Bank
```

## RV32I Instruction Support

| Category | Instructions |
|---|---|
| Arithmetic | ADD, SUB |
| Logical | AND, OR, XOR |
| Shifts | SLL, SRL, SRA |
| Comparisons | SLT, SLTU |
| Immediate operations | ADDI, ANDI, ORI, XORI, SLTI, SLTIU |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jumps | JAL, JALR |
| Upper immediate | LUI, AUIPC |
| Loads | LB, LH, LW, LBU, LHU |
| Stores | SB, SH, SW |

## RV32M Extension

RV32M instructions use opcode `0110011` and funct7 `0000001`.

| funct3 | Instruction | Operation |
|---|---|---|
| 000 | MUL | Lower 32 bits of product |
| 001 | MULH | Upper 32 bits, signed × signed |
| 010 | MULHSU | Upper 32 bits, signed × unsigned |
| 011 | MULHU | Upper 32 bits, unsigned × unsigned |
| 100 | DIV | Signed division, rounded toward zero |
| 101 | DIVU | Unsigned division |
| 110 | REM | Signed remainder |
| 111 | REMU | Unsigned remainder |

### Special Cases

The implementation handles the RISC-V division corner cases:
- Division by zero returns `0xFFFFFFFF`.
- Remainder by zero returns the dividend.
- `INT_MIN / -1` returns `INT_MIN`.
- `INT_MIN % -1` returns zero.

## Course Evaluation Interface

The required top-level module is:

`single_cycle_riscv_m`

### Module Ports

| Port | Direction | Width | Description |
|---|---|---:|---|
| clk | Input | 1 | Rising-edge clock |
| reset | Input | 1 | Asynchronous active-high reset |
| stall | Input | 1 | Stall input; driven low by course CI |
| instruction | Input | 32 | Instruction supplied for the current address |
| mem_out | Input | 32 | Already-extended load data |
| rs2_data | Output | 32 | Full second source-register value |
| alu_out | Output | 32 | ALU result / data-memory address |
| mem_write | Output | 1 | Store control |
| mem_read | Output | 1 | Load control |
| fn3 | Output | 3 | Load/store funct3 |
| opcode | Output | 7 | Opcode of executing instruction |
| address | Output | 32 | PC of instruction being fetched |

### Reset Behaviour

On an active-high reset:
- Program counter is set to `0x80000000`.
- All general-purpose registers are cleared.
- Register `x0` remains zero.

### Memory Organisation

The course evaluation environment provides separate instruction and data memories.

| Memory | Organisation | Address indexing |
|---|---|---|
| Instruction memory | 512 × 32-bit words | `address[10:2]` |
| Data memory | 256 × 32-bit words | `alu_out[9:2]` |

Both memories are zero-initialised. The program is loaded at `0x80000000`. Data-memory writes occur on the rising clock edge when `mem_write` is asserted.

The course-evaluation top module exposes the memory interface externally.

## Repository Structure

```text
Single-Cycle-RV32IM/
│
├── rtl/
│   ├── RV32I processor modules
│   ├── RV32M ALU and control
│   └── single_cycle_riscv_m.sv
│
├── verification/
│   └── RTL verification sources
│
├── compliance/
│   ├── config/
│   ├── README.md
│   ├── sim_main.cpp
│   ├── run_tests.sh
│   └── testcase.md
│
├── rnr-stage.yaml
└── README.md
```

## Implementation Modules

| Module | Responsibility |
|---|---|
| `rv32i_decoder` | Instruction-field decoding |
| `rv32i_immediate_unit` | Immediate generation |
| `rv32i_register_bank` | 32 general-purpose registers |
| `rv32i_alu` | RV32I arithmetic and logic |
| `rv32i_alu_control` | Base ALU operation selection |
| `rv32m_control` | RV32M instruction detection |
| `rv32m_alu` | Multiplication, division and remainder |
| `rv32i_ex_stage` | RV32I and RV32M execution integration |
| `rv32i_if_stage` | Instruction fetch and PC updates |
| `rv32i_wb_stage` | Register writeback selection |
| `rv32i_soc_top` | Internal-memory SoC wrapper used by compliance simulation |
| `single_cycle_riscv_m` | External-memory interface for course evaluation |

## Verification

This project contains **two separate verification flows**, with different testbenches and purposes.

### 1. Course RISC-n-Roll CI

The course-provided RISC-n-Roll GitHub App checks the RTL submitted to the group repository.

Configuration:

`rnr-stage.yaml`

The CI checks:
- Configuration and source-file paths.
- RTL synthesis and top-level interface compatibility.
- Design validation constraints.
- Processor behaviour by comparing committed store sequences against a trusted reference.

The CI runs periodically after commits. Its result is available under the latest commit's Checks section.

### 2. RISC-V Architectural Compliance Testbench

A separate architectural-compliance testbench is implemented under the `compliance/` directory.

It uses:
- RISC-V Architectural Certification Tests (ACT4).
- Sail RISC-V reference model.
- Verilator simulation.
- RISC-V GCC toolchain.

**Testbench components:**

| File | Purpose |
|---|---|
| `compliance/sim_main.cpp` | C++ Verilator testbench, ELF loader, simulation loop and signature extraction |
| `compliance/run_tests.sh` | Executes compliance programs and compares DUT signatures against reference signatures |
| `compliance/config/` | DUT and reference-model configuration files |
| `compliance/README.md` | Setup instructions, execution procedure, results and limitations |

The Verilator testbench loads the program into the processor's instruction and data memories, runs the processor, extracts the signature region and compares it byte-for-byte against the Sail reference result.

The compliance report documents **47/47 passing tests**:
- 39 RV32I tests.
- 8 RV32M tests.

The tests use the documented ACT4 configuration and are not an exhaustive verification of every possible instruction combination.

**Important:** This compliance testbench is independent of the course RISC-n-Roll CI. Its reported result does not imply that the college CI has passed.

For environment setup, commands, configuration details and limitations, refer to [`compliance/README.md`](compliance/README.md).

## Tools and Technologies

- SystemVerilog
- Git and GitHub
- Yosys
- Verilator
- RISC-V GCC toolchain
- Sail RISC-V
- RISC-V Architectural Certification Tests

## Scope and Limitations

The documented architectural-compliance configuration covers RV32I + M, including Zmmul. It does not cover CSRs, traps or privileged-mode behaviour.

The compliance memory model uses separate instruction and data memories. Self-modifying code is not supported. Misaligned accesses crossing word boundaries are also unsupported.

Refer to [`compliance/README.md`](compliance/README.md) for the complete test scope and limitations.

## Contributors

- **Aditya Chinchore**
- **Aditya KS**
- **Acchutya**

## References

- [RISC-V Unprivileged ISA Specifications](https://riscv.org/technical/specifications/)
- [RISC-V Architectural Certification Tests](https://github.com/riscv/riscv-arch-test)
- [Sail RISC-V](https://github.com/riscv/sail-riscv)
- [Verilator Documentation](https://verilator.org/guide/latest/)
