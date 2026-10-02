# 3-Stage RISC-V Processor with 2-Way L1 Cache

A processor project in SystemVerilog targeting the RV32I instruction set. The design combines a three-stage pipeline with a two-way set-associative L1 data cache for instruction execution and efficient memory access.

## Planned Architecture

- Three-stage RV32I pipeline
- Operand forwarding and hazard detection
- Pipeline stalls and branch flushing
- 8 KB two-way set-associative L1 data cache
- 32-byte cache lines and 128 sets
- Parallel tag lookup and LRU replacement
- Write-back and write-allocate policies
- FSM-based controller for dirty-line eviction and 256-bit cache-line refills
- Performance counters for cache hits, misses, stall cycles, and CPI

## Applications

The processor is intended as a foundation for FPGA soft processors and customizable embedded systems. Potential applications include sensor interfaces, control systems, and coordinating data movement and configuration for hardware accelerators.

The project also supports evaluation of pipeline hazards, cache behavior, and memory access performance.

## Repository Structure

- `rtl/' - Processor and cache SystemVerilog modules
- `tb/` - Simulation testbenches
- `docs/' - Architecture documentation and verification results

## Current Status

Initial project setup is underway. Processor and cache implementation and verification are planned.