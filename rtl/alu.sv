module alu (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result
);

    localparam logic [3:0]
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_AND  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_XOR  = 4'd4,
        ALU_SLL  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_SLT  = 4'd8,
        ALU_SLTU = 4'd9;

    always_comb begin
        result = 32'b0;

        case (alu_op)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;

            ALU_SLL:  result = operand_a << operand_b[4:0];
            ALU_SRL:  result = operand_a >> operand_b[4:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[4:0];

            ALU_SLT:  result =
                {31'b0, ($signed(operand_a) < $signed(operand_b))};

            ALU_SLTU: result =
                {31'b0, (operand_a < operand_b)};

            default:  result = 32'b0;
        endcase
    end

endmodule