// Five stages: IF (PC), ID (IF/ID), EX (ID/EX), MEM (EX/MEM), WB (MEM/WB).
// A blocking MEM freezes the younger stages while WB drains exactly once.
module rv32_core #(
    parameter logic [31:0] RESET_PC = 0
) (
    input logic clk, rst,
    output logic [31:0] instruction_address,
    input logic [31:0] instruction_data,
    output logic request_valid, request_write,
    input logic request_ready,
    output logic [31:0] request_address, request_data,
    output logic [3:0] request_strobe,
    input logic response_valid,
    output logic response_ready,
    input logic [31:0] response_data,
    input logic response_error,
    output logic halted,
    output logic [31:0] trap_pc, trap_cause,
    output logic retire_valid,
    output logic [31:0] retire_pc, retire_instruction,
    output logic [4:0] retire_rd,
    output logic [31:0] retire_data,
    output logic [63:0] cycles, instructions, stall_cycles, dependency_stalls
);
    typedef struct packed {
        logic valid;
        logic [31:0] pc, instruction;
    } decode_stage_t;
    typedef struct packed {
        logic valid;
        logic [31:0] pc, instruction, a, b, immediate;
        logic [3:0] alu_op;
        logic reg_write, alu_immediate, load, store, branch, jal, jalr, lui, auipc;
        logic illegal, ecall, ebreak;
    } execute_stage_t;
    typedef struct packed {
        logic valid;
        logic [31:0] pc, instruction, result, address, store_value;
        logic reg_write, load, store, fault;
        logic [31:0] cause;
    } memory_stage_t;
    typedef struct packed {
        logic valid;
        logic [31:0] pc, instruction, result;
        logic reg_write, fault;
        logic [31:0] cause;
    } writeback_stage_t;
    decode_stage_t d;
    execute_stage_t x;
    memory_stage_t m;
    writeback_stage_t w;
    logic [31:0] pc, immediate, rf_a, rf_b, operand_a, operand_b;
    logic [3:0] d_alu;
    logic d_rs1, d_rs2, d_write, d_imm, d_load, d_store, d_branch, d_jal, d_jalr, d_lui, d_auipc;
    logic d_illegal, d_ecall, d_ebreak;
    logic [31:0] alu_result, x_result, target, load_value, m_result;
    logic taken, redirect, x_fault, x_misaligned, m_misaligned, m_fault;
    logic [31:0] x_cause, m_cause;
    logic sent, m_complete, memory_stall, load_use_stall, stall, dependency_stall, writeback;
    logic [31:0] unused_write_word, unused_load;
    logic [3:0] unused_strobe;

    decoder decode(.instruction(d.instruction), .alu_op(d_alu), .uses_rs1(d_rs1), .uses_rs2(d_rs2),
        .reg_write(d_write), .alu_immediate(d_imm), .load(d_load), .store(d_store), .branch(d_branch),
        .jal(d_jal), .jalr(d_jalr), .lui(d_lui), .auipc(d_auipc), .illegal(d_illegal), .ecall(d_ecall), .ebreak(d_ebreak));
    immediate_generator immediate_decode(.instruction(d.instruction), .immediate);
    register_file registers(.clk, .rst, .write_en(writeback), .write_addr(w.instruction[11:7]), .write_data(w.result),
        .read_addr_a(d.instruction[19:15]), .read_addr_b(d.instruction[24:20]), .read_data_a(rf_a), .read_data_b(rf_b));
    forwarding_unit forwarding(.rs1(x.instruction[19:15]), .rs2(x.instruction[24:20]),
        .memory_rd(m.instruction[11:7]), .writeback_rd(w.instruction[11:7]),
        .register_a(x.a), .register_b(x.b), .memory_result(m_result), .writeback_result(w.result),
        .memory_write(m.valid && m.reg_write && m_complete && !m_fault), .writeback_write(writeback), .operand_a, .operand_b);
    alu execute_alu(.operand_a, .operand_b(x.alu_immediate ? x.immediate : operand_b), .alu_op(x.alu_op), .result(alu_result));
    // Alignment is checked in EX; lane selection and load extension occur in MEM.
    load_store_unit alignment(.address(alu_result), .store_value(32'b0), .read_word(32'b0), .funct3(x.instruction[14:12]),
        .write_word(unused_write_word), .load_value(unused_load), .byte_enable(unused_strobe), .misaligned(x_misaligned));
    load_store_unit memory_lsu(.address(m.address), .store_value(m.store_value), .read_word(response_data), .funct3(m.instruction[14:12]),
        .write_word(request_data), .load_value, .byte_enable(request_strobe), .misaligned(m_misaligned));
    hazard_unit hazards(.execute_valid(x.valid), .execute_load(x.load), .memory_valid(m.valid), .memory_load(m.load), .memory_complete(m_complete),
        .decode_valid(d.valid), .uses_rs1(d_rs1), .uses_rs2(d_rs2), .rs1(d.instruction[19:15]), .rs2(d.instruction[24:20]),
        .execute_rd(x.instruction[11:7]), .memory_rd(m.instruction[11:7]), .memory_stall, .load_use_stall, .stall, .dependency_stall);
    performance_counters counters(.clk, .rst, .retire(retire_valid), .stall(stall && !halted),
        .dependency_stall(dependency_stall && !halted), .cycles, .instructions, .stall_cycles, .dependency_stalls);

    always_comb begin
        taken = 0;
        case (x.instruction[14:12])
            0: taken = operand_a == operand_b;
            1: taken = operand_a != operand_b;
            4: taken = $signed(operand_a) < $signed(operand_b);
            5: taken = $signed(operand_a) >= $signed(operand_b);
            6: taken = operand_a < operand_b;
            7: taken = operand_a >= operand_b;
            default: taken = 0;
        endcase
        redirect = x.valid && (x.jal || x.jalr || (x.branch && taken));
        target = x.jalr ? ((operand_a + x.immediate) & 32'hfffffffe) : x.pc + x.immediate;
        x_result = alu_result;
        if (x.lui) x_result = x.immediate;
        if (x.auipc) x_result = x.pc + x.immediate;
        if (x.jal || x.jalr) x_result = x.pc + 4;
        x_fault = 0; x_cause = 0;
        if (x.illegal) begin x_fault = 1; x_cause = 2; end
        else if (x.ecall) begin x_fault = 1; x_cause = 11; end
        else if (x.ebreak) begin x_fault = 1; x_cause = 3; end
        else if (redirect && target[1:0] != 0) begin x_fault = 1; x_cause = 0; end
        else if ((x.load || x.store) && x_misaligned) begin x_fault = 1; x_cause = x.store ? 6 : 4; end
    end
    assign m_result = m.load ? load_value : m.result;
    assign m_fault = m.fault || (sent && response_valid && response_error);
    assign m_cause = m.fault ? m.cause : (m.store ? 32'd7 : 32'd5);
    assign m_complete = m_fault || !(m.load || m.store) || (sent && response_valid);
    assign retire_valid = w.valid && !w.fault && !halted && !rst;
    assign writeback = retire_valid && w.reg_write;
    assign retire_pc = w.pc;
    assign retire_instruction = w.instruction;
    assign retire_rd = w.reg_write ? w.instruction[11:7] : 5'd0;
    assign retire_data = w.result;
    assign instruction_address = pc;
    assign request_address = m.address;
    assign request_write = m.store;
    assign request_valid = m.valid && (m.load || m.store) && !m_fault && !sent &&
        !(w.valid && w.fault) && !halted && !rst;
    assign response_ready = sent && !halted && !rst;

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= RESET_PC; d <= '0; x <= '0; m <= '0; w <= '0;
            sent <= 0; halted <= 0; trap_pc <= 0; trap_cause <= 0;
        end else if (!halted) begin
            // WB drains even while MEM is waiting; no repeated retirement.
            w.valid <= 0;
            if (w.valid && w.fault) begin
                halted <= 1; trap_pc <= w.pc; trap_cause <= w.cause;
                d.valid <= 0; x.valid <= 0; m.valid <= 0; sent <= 0;
            end else begin
                if (request_valid && request_ready) sent <= 1;
                if (memory_stall) begin
                    // Preserve a WB-forwarded value when EX remains held after WB drains.
                    x.a <= operand_a; x.b <= operand_b;
                end else begin
                    sent <= 0;
                    w.valid <= m.valid; w.pc <= m.pc; w.instruction <= m.instruction;
                    w.result <= m_result; w.reg_write <= m.reg_write; w.fault <= m_fault; w.cause <= m_cause;
                    if (m.valid && m_fault) begin
                        // An older MEM fault wins over every younger redirect/effect.
                        m.valid <= 0; x.valid <= 0; d.valid <= 0;
                    end else begin
                        m.valid <= x.valid; m.pc <= x.pc; m.instruction <= x.instruction;
                        m.result <= x_result; m.address <= alu_result; m.store_value <= operand_b;
                        m.reg_write <= x.reg_write; m.load <= x.load; m.store <= x.store;
                        m.fault <= x_fault; m.cause <= x_cause;
                        if (x.valid && (redirect || x_fault)) begin
                            if (redirect && !x_fault) pc <= target;
                            x.valid <= 0; d.valid <= 0;
                        end else if (load_use_stall) begin
                            // Load advances to MEM; insert one EX bubble and hold IF/ID.
                            x.valid <= 0;
                        end else begin
                            pc <= pc + 4;
                            d.valid <= 1; d.pc <= pc; d.instruction <= instruction_data;
                            x.valid <= d.valid; x.pc <= d.pc; x.instruction <= d.instruction;
                            x.a <= rf_a; x.b <= rf_b; x.immediate <= immediate; x.alu_op <= d_alu;
                            x.reg_write <= d_write; x.alu_immediate <= d_imm; x.load <= d_load; x.store <= d_store;
                            x.branch <= d_branch; x.jal <= d_jal; x.jalr <= d_jalr; x.lui <= d_lui; x.auipc <= d_auipc;
                            x.illegal <= d_illegal; x.ecall <= d_ecall; x.ebreak <= d_ebreak;
                        end
                    end
                end
            end
        end
    end
endmodule
