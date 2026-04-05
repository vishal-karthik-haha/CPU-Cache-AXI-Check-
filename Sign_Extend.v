module Sign_Extend (
    input  [15:0] instr,
    output [7:0] imm
);

assign imm = instr[5:0];

endmodule
