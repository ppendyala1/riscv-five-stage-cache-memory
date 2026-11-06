module load_store_unit (
    input logic [31:0] address, store_value, read_word,
    input logic [2:0] funct3,
    output logic [31:0] write_word, load_value,
    output logic [3:0] byte_enable,
    output logic misaligned
);
    logic [31:0] shifted;
    always_comb begin
        shifted = read_word >> (8 * address[1:0]);
        write_word = store_value << (8 * address[1:0]);
        byte_enable = 0; misaligned = 0;
        case (funct3[1:0])
            0: byte_enable = 4'b0001 << address[1:0];
            1: begin byte_enable = 4'b0011 << address[1:0]; misaligned = address[0]; end
            2: begin byte_enable = 4'b1111; misaligned = |address[1:0]; end
            default: misaligned = 1;
        endcase
        case (funct3)
            0: load_value = {{24{shifted[7]}}, shifted[7:0]};
            1: load_value = {{16{shifted[15]}}, shifted[15:0]};
            4: load_value = {24'b0, shifted[7:0]};
            5: load_value = {16'b0, shifted[15:0]};
            default: load_value = shifted;
        endcase
    end
endmodule
