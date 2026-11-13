module forwarding_unit (
    input logic [4:0] rs1, rs2, memory_rd, writeback_rd,
    input logic [31:0] register_a, register_b, memory_result, writeback_result,
    input logic memory_write, writeback_write,
    output logic [31:0] operand_a, operand_b
);
    // The younger MEM producer wins when both stages target the same register.
    assign operand_a = memory_write && memory_rd != 0 && rs1 == memory_rd ? memory_result :
        writeback_write && writeback_rd != 0 && rs1 == writeback_rd ? writeback_result : register_a;
    assign operand_b = memory_write && memory_rd != 0 && rs2 == memory_rd ? memory_result :
        writeback_write && writeback_rd != 0 && rs2 == writeback_rd ? writeback_result : register_b;
endmodule
