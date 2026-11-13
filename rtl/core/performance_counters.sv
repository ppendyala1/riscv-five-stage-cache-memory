module performance_counters (
    input logic clk, rst, retire, stall, dependency_stall,
    output logic [63:0] cycles, instructions, stall_cycles, dependency_stalls
);
    always_ff @(posedge clk) begin
        if (rst) begin cycles <= 0; instructions <= 0; stall_cycles <= 0; dependency_stalls <= 0; end
        else begin
            cycles <= cycles + 1;
            if (retire) instructions <= instructions + 1;
            if (stall) stall_cycles <= stall_cycles + 1;
            if (dependency_stall) dependency_stalls <= dependency_stalls + 1;
        end
    end
endmodule
