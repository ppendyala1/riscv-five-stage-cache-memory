module immediate_generator (
    input logic [31:0] instruction,
    output logic [31:0] immediate
);
    always_comb begin
        case (instruction[6:0])
            7'h23: immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            7'h63: immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            7'h37, 7'h17: immediate = {instruction[31:12], 12'b0};
            7'h6f: immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            default: immediate = {{20{instruction[31]}}, instruction[31:20]};
        endcase
    end
endmodule
