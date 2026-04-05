module ProgramCounter #(
    parameter WIDTH = 16
)(
    input clk,
    input reset,
    input PCWrite,
    input [WIDTH-1:0] next_pc,
    output reg [WIDTH-1:0] pc
);

always @(posedge clk or posedge reset) begin
    if (reset)
        pc <= 0;
    else if (PCWrite)
        pc <= next_pc;
end

endmodule
