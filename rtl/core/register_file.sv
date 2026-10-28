module register_file (
    input  logic        clk,
    input  logic        rst,
    input  logic        write_en,
    input  logic [4:0]  write_addr,
    input  logic [31:0] write_data,
    input  logic [4:0]  read_addr_a,
    input  logic [4:0]  read_addr_b,
    output logic [31:0] read_data_a,
    output logic [31:0] read_data_b
);
    // x0 has no storage. Reset is synchronous, active high.
    logic [31:0] registers [1:31];
    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 1; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else if (write_en && write_addr != 5'd0) begin
            registers[write_addr] <= write_data;
        end
    end

    // Write-through lets decode see a concurrent writeback value before
    // the edge. Execute-stage forwarding is a separate pipeline feature.
    always_comb begin
        read_data_a = 32'b0;
        read_data_b = 32'b0;
        if (read_addr_a != 5'd0) begin
            if (!rst && write_en && write_addr == read_addr_a)
                read_data_a = write_data;
            else
                read_data_a = registers[read_addr_a];
        end
        if (read_addr_b != 5'd0) begin
            if (!rst && write_en && write_addr == read_addr_b)
                read_data_b = write_data;
            else
                read_data_b = registers[read_addr_b];
        end
    end
endmodule
