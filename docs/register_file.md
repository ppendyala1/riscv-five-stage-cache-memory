# Register file contract

The register file contains x1 through x31 as 32-bit storage. Reads of x0 always return zero, and writes to x0 are ignored. A rising clock edge with `rst=1` clears all stored registers, taking priority over a write. Reset does not mask asynchronous reads before that edge.

At a rising edge with `rst=0` and `write_en=1`, a nonzero `write_addr` stores `write_data`. Both read ports are combinational and independent. When a read address matches an enabled, nonzero write address and reset is inactive, that port returns `write_data` before the edge. Disabling `write_en` exposes the stored value again.

A pipeline must drive `write_en` only for a valid instruction that actually commits a register write. This bypass can cover a concurrent writeback/decode dependency. It does not provide execute-stage forwarding, load-use hazard detection, or pipeline control.

The synchronous reset loop and two combinational ports are suitable for a small flop/distributed-logic register file. FPGA mapping and timing must be measured after synthesis; block-RAM inference is not assumed.

## Verification scope

The testbench checks every writable register, both read ports, writes to x0, disabled writes, repeated writes, matching writes on either or both ports, and reset priority. Each driven cycle checks reads before the write edge, after the edge, and after disabling bypass. A fixed-seed xorshift sequence drives 1,000 additional cycles, including periodic resets. Case inequality detects unknown read values as failures.

The test covers the standalone register file. The pipeline, cache, instruction execution counts, CPI counters, and memory expansion model are not implemented or verified by this commit.

## Suggested commit

`Add RV32I register file with write-through and self-checking tests`

Next component: instruction decoder and immediate generator, verified across instruction formats and illegal encodings.

## Validation result

Icarus Verilog 12.0 compilation and simulation passed with `PASS: register_file (3297 read checks)`. Simulation completed at 10.997 microseconds. Vivado synthesis and timing have not been run.
