`timescale 1ns/1ps
module decoder_tb;
    `include "waveform.svh"
    logic [31:0] instruction, immediate;
    wire [3:0] alu_op;
    wire uses_rs1, uses_rs2, reg_write, alu_immediate, load, store, branch, jal, jalr, lui, auipc, illegal, ecall, ebreak;
    integer checks = 0;
    logic expected_illegal;
    decoder dut(.*);
    immediate_generator imm(.instruction, .immediate);
    `include "encoding.svh"
    task automatic check_illegal(input logic [31:0] ins, input bit bad);
        instruction = ins; #1;
        if (illegal !== bad) $fatal(1, "decoder instruction=%h illegal=%b expected=%b", instruction, illegal, bad);
        if (bad && (reg_write || load || store || branch || jal || jalr)) $fatal(1, "illegal side effect enabled");
        checks++;
    endtask
    initial begin
        // Sweep all funct3/funct7 combinations of register arithmetic and shifts.
        for (integer f3 = 0; f3 < 8; f3++) begin
            for (integer f7 = 0; f7 < 128; f7++) begin
                expected_illegal = !(f7 == 0 || (f7 == 32 && (f3 == 0 || f3 == 5)));
                check_illegal(enc_r(f7, 2, 1, f3, 3), expected_illegal);
                expected_illegal = (f3 == 1 && f7 != 0) || (f3 == 5 && f7 != 0 && f7 != 32);
                check_illegal(enc_i(f7 << 5, 1, f3, 3, 'h13), expected_illegal);
            end
            check_illegal(enc_i(0, 1, f3, 3, 3), !(f3 == 0 || f3 == 1 || f3 == 2 || f3 == 4 || f3 == 5));
            check_illegal(enc_s(0, 2, 1, f3), f3 > 2);
            check_illegal(enc_b(8, 2, 1, f3), f3 == 2 || f3 == 3);
            check_illegal(enc_i(0, 1, f3, 3, 'h67), f3 != 0);
        end
        check_illegal(32'h00000073, 0); if (!ecall) $fatal(1, "ecall");
        check_illegal(32'h00100073, 0); if (!ebreak) $fatal(1, "ebreak");
        check_illegal(32'h30200073, 1);
        check_illegal(32'h0000100f, 1); // FENCE.I belongs to Zifencei.
        check_illegal(32'hffffffff, 1);
        for (integer v = -2048; v < 2048; v += 17) begin
            instruction = enc_i(v, 1, 0, 2, 'h13); #1;
            if (immediate !== 32'(v)) $fatal(1, "I immediate");
            instruction = enc_s(v, 2, 1, 2); #1;
            if (immediate !== 32'(v)) $fatal(1, "S immediate");
            checks += 2;
        end
        for (integer v = -4096; v < 4096; v += 34) begin
            instruction = enc_b(v, 2, 1, 0); #1;
            if (immediate !== 32'(v)) $fatal(1, "B immediate");
            checks++;
        end
        for (integer v = -1048576; v < 1048576; v += 8190) begin
            instruction = enc_j(v, 1); #1;
            if (immediate !== 32'(v)) $fatal(1, "J immediate");
            checks++;
        end
        instruction = 32'hfedcb137; #1;
        if (immediate != 32'hfedcb000) $fatal(1, "U immediate");
        $display("PASS: decoder (%0d encoding/immediate checks)", checks);
        $finish;
    end
endmodule
