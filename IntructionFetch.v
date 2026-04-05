module InstructionFetch #(
    parameter WIDTH = 16,
    parameter DEPTH = 256
)(
    input clk,
    input reset,
    input [WIDTH-1:0] next_pc,
    output [WIDTH-1:0] instruction,
    output [WIDTH-1:0] pc_out
);

reg [WIDTH-1:0] memory [0:DEPTH-1];
wire [WIDTH-1:0] pc_current;

integer i;

ProgramCounter #(WIDTH) pc (
    .clk(clk),
    .reset(reset),
    .PCWrite(1'b1),
    .next_pc(next_pc),
    .pc(pc_current)
);

initial begin
    for (i = 0; i < DEPTH; i = i + 1)
        memory[i] = 16'h0000;

    memory[0] = 16'b0000_001_010_011_000;
    memory[1] = 16'b0001_011_001_100_000;
    memory[2] = 16'b0010_100_010_101_000;
    memory[3] = 16'b0011_101_001_110_000;
end

assign instruction = memory[pc_current];
assign pc_out = pc_current;

endmodule
