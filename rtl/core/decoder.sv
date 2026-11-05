// ALU operation encodings match alu.sv. Invalid encodings never have effects.
module decoder (
    input logic [31:0] instruction,
    output logic [3:0] alu_op,
    output logic uses_rs1, uses_rs2, reg_write, alu_immediate,
    output logic load, store, branch, jal, jalr, lui, auipc,
    output logic illegal, ecall, ebreak
);
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    always_comb begin
        opcode = instruction[6:0];
        funct3 = instruction[14:12];
        funct7 = instruction[31:25];
        alu_op = 0;
        uses_rs1 = 0; uses_rs2 = 0; reg_write = 0; alu_immediate = 0;
        load = 0; store = 0; branch = 0; jal = 0; jalr = 0;
        lui = 0; auipc = 0; illegal = 0; ecall = 0; ebreak = 0;
        case (opcode)
            7'h33, 7'h13: begin
                uses_rs1 = 1; uses_rs2 = opcode == 7'h33;
                reg_write = 1; alu_immediate = opcode == 7'h13;
                case (funct3)
                    0: begin
                        alu_op = (uses_rs2 && funct7 == 7'h20) ? 1 : 0;
                        if (uses_rs2 && funct7 != 0 && funct7 != 7'h20) illegal = 1;
                    end
                    1: begin alu_op = 5; if (funct7 != 0) illegal = 1; end
                    2: begin alu_op = 8; if (uses_rs2 && funct7 != 0) illegal = 1; end
                    3: begin alu_op = 9; if (uses_rs2 && funct7 != 0) illegal = 1; end
                    4: begin alu_op = 4; if (uses_rs2 && funct7 != 0) illegal = 1; end
                    5: begin
                        alu_op = funct7 == 7'h20 ? 7 : 6;
                        if (funct7 != 0 && funct7 != 7'h20) illegal = 1;
                    end
                    6: begin alu_op = 3; if (uses_rs2 && funct7 != 0) illegal = 1; end
                    7: begin alu_op = 2; if (uses_rs2 && funct7 != 0) illegal = 1; end
                endcase
            end
            7'h03: begin
                uses_rs1 = 1; load = 1; reg_write = 1; alu_immediate = 1;
                if (!(funct3 == 0 || funct3 == 1 || funct3 == 2 || funct3 == 4 || funct3 == 5)) illegal = 1;
            end
            7'h23: begin
                uses_rs1 = 1; uses_rs2 = 1; store = 1; alu_immediate = 1;
                if (funct3 > 2) illegal = 1;
            end
            7'h63: begin
                uses_rs1 = 1; uses_rs2 = 1; branch = 1;
                if (funct3 == 2 || funct3 == 3) illegal = 1;
            end
            7'h6f: begin jal = 1; reg_write = 1; end
            7'h67: begin jalr = 1; reg_write = 1; uses_rs1 = 1; if (funct3 != 0) illegal = 1; end
            7'h37: begin lui = 1; reg_write = 1; end
            7'h17: begin auipc = 1; reg_write = 1; end
            7'h0f: begin
                // Single-outstanding memory operations complete in program order.
                if (funct3 != 0) illegal = 1;
            end
            7'h73: begin
                ecall = instruction == 32'h00000073;
                ebreak = instruction == 32'h00100073;
                illegal = !(ecall || ebreak);
            end
            default: illegal = 1;
        endcase
        if (illegal) begin
            reg_write = 0; load = 0; store = 0; branch = 0; jal = 0; jalr = 0;
        end
    end
endmodule
