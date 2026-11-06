`timescale 1ns/1ps
module load_store_unit_tb;
    logic [31:0] address, store_value = 32'ha1b2c3d4, read_word = 32'h80ff7f01;
    logic [2:0] funct3;
    wire [31:0] write_word, load_value;
    wire [3:0] byte_enable;
    wire misaligned;
    integer checks = 0;
    load_store_unit dut(.*);

    task automatic check(input logic [2:0] operation, input logic [31:0] addr,
        input logic [31:0] expected_load, expected_store, input logic [3:0] expected_mask);
        funct3 = operation; address = addr; #1;
        if (misaligned !== 0 || load_value !== expected_load || write_word !== expected_store || byte_enable !== expected_mask)
            $fatal(1, "operation=%0d address=%h load=%h store=%h mask=%b misaligned=%b",
                operation, addr, load_value, write_word, byte_enable, misaligned);
        checks++;
    endtask

    initial begin
        // The same word supplies positive/negative byte and halfword cases.
        check(0, 0, 32'h00000001, 32'ha1b2c3d4, 4'b0001);
        check(0, 1, 32'h0000007f, 32'hb2c3d400, 4'b0010);
        check(0, 2, 32'hffffffff, 32'hc3d40000, 4'b0100);
        check(0, 3, 32'hffffff80, 32'hd4000000, 4'b1000);
        check(4, 0, 32'h00000001, 32'ha1b2c3d4, 4'b0001);
        check(4, 1, 32'h0000007f, 32'hb2c3d400, 4'b0010);
        check(4, 2, 32'h000000ff, 32'hc3d40000, 4'b0100);
        check(4, 3, 32'h00000080, 32'hd4000000, 4'b1000);
        check(1, 0, 32'h00007f01, 32'ha1b2c3d4, 4'b0011);
        check(1, 2, 32'hffff80ff, 32'hc3d40000, 4'b1100);
        check(5, 0, 32'h00007f01, 32'ha1b2c3d4, 4'b0011);
        check(5, 2, 32'h000080ff, 32'hc3d40000, 4'b1100);
        check(2, 0, 32'h80ff7f01, 32'ha1b2c3d4, 4'b1111);
        check(2, 32'h1000001c, 32'h80ff7f01, 32'ha1b2c3d4, 4'b1111);
        // Alignment depends on the byte address for both signed/unsigned loads.
        for (integer offset = 0; offset < 4; offset++) begin
            address = 32'h10000000 + 32'(offset);
            funct3 = 1; #1;
            if (misaligned !== 1'(offset % 2)) $fatal(1, "halfword alignment");
            funct3 = 5; #1;
            if (misaligned !== 1'(offset % 2)) $fatal(1, "unsigned halfword alignment");
            funct3 = 2; #1;
            if (misaligned !== (offset != 0)) $fatal(1, "word alignment");
            checks += 3;
        end
        $display("PASS: load_store_unit (%0d lane, extension, and alignment checks)", checks);
        $finish;
    end
endmodule
