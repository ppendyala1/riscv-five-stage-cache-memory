module hazard_unit (
    input logic execute_valid, execute_load, memory_valid, memory_load, memory_complete,
    input logic decode_valid, uses_rs1, uses_rs2,
    input logic [4:0] rs1, rs2, execute_rd, memory_rd,
    output logic memory_stall, load_use_stall, stall, dependency_stall
);
    assign memory_stall = memory_valid && !memory_complete;
    assign load_use_stall = execute_valid && execute_load && decode_valid && execute_rd != 0 &&
        ((uses_rs1 && rs1 == execute_rd) || (uses_rs2 && rs2 == execute_rd));
    assign stall = memory_stall || load_use_stall;
    assign dependency_stall = load_use_stall ||
        (memory_stall && memory_load && decode_valid && memory_rd != 0 &&
        ((uses_rs1 && rs1 == memory_rd) || (uses_rs2 && rs2 == memory_rd)));
endmodule
