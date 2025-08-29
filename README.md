# RISC-V Core Implementation
This repository features an ongoing project including the development of a RISC-V core implementing the 32-bit integer instruction set. The project is planned to move in phases.

1) Design and verification of the single cycle RV32I core using SystemVerilog and UVM
2) Pipelining and verifying the 5-stage core, adding simple branch prediction and forwarding logic
3) Adding one or two RISC-V extensions (very likely M and F, maybe going all the way to RV32G)
4) Design and verification of a simple cache heirarchy
5) Extending the top-level to a multicore system (2 cores, implementing coherency management)

# Background
This project will very likely last multiple years. I am currently wrapping up stage 1 (have been working on the core for 2 months, and have verified the core at unit level and run basic programs).

# High Level Description

# Directory Structure
The top level directory is divided into source RTL, testbenches

# Usage and Build
Usage is complicated right now. I do not any institutional access to a simulator capable of running UVM testbenches, and have been copying and pasting files into EDAplayground. Feel free to copy and paste modules and play around woth testbenches.