module sync_fifo #(
    parameter integer WIDTH = 32,
    parameter integer DEPTH = 4,
    parameter integer PTR_WIDTH = DEPTH > 1 ? $clog2(DEPTH) : 1
) (
    input logic clk, rst,
    input logic in_valid,
    output logic in_ready,
    input logic [WIDTH-1:0] in_data,
    output logic out_valid,
    input logic out_ready,
    output logic [WIDTH-1:0] out_data
);
    logic [WIDTH-1:0] storage [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] head, tail;
    logic [PTR_WIDTH:0] count;
    assign in_ready = count < DEPTH && !rst;
    assign out_valid = count != 0 && !rst;
    assign out_data = storage[head];
    always_ff @(posedge clk) begin
        if (rst) begin head <= 0; tail <= 0; count <= 0; end
        else begin
            case ({in_valid && in_ready, out_valid && out_ready})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: ;
            endcase
            if (in_valid && in_ready) begin
                storage[tail] <= in_data;
                if (tail == DEPTH-1) tail <= 0; else tail <= tail + 1'b1;
            end
            if (out_valid && out_ready) begin
                if (head == DEPTH-1) head <= 0; else head <= head + 1'b1;
            end
        end
    end
endmodule
