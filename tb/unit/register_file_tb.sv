`timescale 1ns/1ps
module register_file_tb;
    `include "waveform.svh"
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst, write_en;
    logic [4:0] write_addr, read_addr_a, read_addr_b;
    logic [31:0] write_data, read_data_a, read_data_b;
    logic [31:0] model [0:31];
    logic [31:0] rng = 32'h411cafe1;
    integer checks = 0;
    integer i;

    register_file dut (.*);

    function automatic logic [31:0] next_random(input logic [31:0] x);
        logic [31:0] y;
        y = x ^ (x << 13);
        y = y ^ (y >> 17);
        return y ^ (y << 5);
    endfunction

    task automatic check_reads(input bit bypass);
        logic [31:0] expected_a, expected_b;
        expected_a = model[read_addr_a];
        expected_b = model[read_addr_b];
        if (bypass && !rst && write_en && write_addr != 0) begin
            if (write_addr == read_addr_a) expected_a = write_data;
            if (write_addr == read_addr_b) expected_b = write_data;
        end
        if (read_data_a !== expected_a || read_data_b !== expected_b)
            $fatal(1, "check %0d: rs1=x%0d got=%h expected=%h; rs2=x%0d got=%h expected=%h",
                checks, read_addr_a, read_data_a, expected_a,
                read_addr_b, read_data_b, expected_b);
        checks++;
    endtask

    task automatic cycle(input bit reset_value, input bit enable,
                         input logic [4:0] destination,
                         input logic [31:0] value,
                         input logic [4:0] source_a, source_b);
        @(negedge clk);
        rst = reset_value;
        write_en = enable;
        write_addr = destination;
        write_data = value;
        read_addr_a = source_a;
        read_addr_b = source_b;
        #1;
        check_reads(1);
        @(posedge clk);
        if (rst)
            for (integer j = 0; j < 32; j++) model[j] = 0;
        else if (write_en && write_addr != 0)
            model[write_addr] = write_data;
        #1;
        check_reads(1);
        // Disable bypass to prove the value was actually stored.
        write_en = 0;
        #1;
        check_reads(0);
    endtask

    initial begin
        rst = 1; write_en = 0; write_addr = 0; write_data = 0;
        read_addr_a = 0; read_addr_b = 0;
        for (i = 0; i < 32; i++) model[i] = 0;
        @(posedge clk);
        #1;
        for (i = 1; i < 32; i++)
            cycle(0, 1, i[4:0], 32'h80000000 + i, i[4:0], i[4:0]);
        for (i = 0; i < 32; i++)
            cycle(0, 0, i[4:0], 32'hdeadbeef, i[4:0], 5'd31-i[4:0]);
        cycle(0, 1, 0, 32'hffffffff, 0, 0);
        cycle(0, 1, 7, 32'hffffffff, 7, 8);
        cycle(0, 1, 7, 32'h00000000, 8, 7);
        // Reset must override a simultaneous write and clear every register.
        cycle(1, 1, 7, 32'hdeadbeef, 7, 7);
        for (i = 0; i < 32; i++)
            cycle(0, 0, 0, 0, i[4:0], 5'd31-i[4:0]);
        for (i = 0; i < 1000; i++) begin
            rng = next_random(rng);
            cycle(i % 127 == 0, rng[0], rng[5:1], rng,
                  rng[10:6], rng[15:11]);
        end
        $display("PASS: register_file (%0d read checks)", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Simulation timeout");
    end
endmodule
