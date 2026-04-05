module ForwardingUnit (
    input        EX_MEM_reg_write,
    input        MEM_WB_reg_write,
    input  [2:0] EX_MEM_rd,
    input  [2:0] MEM_WB_rd,
    input  [2:0] ID_EX_rs1,
    input  [2:0] ID_EX_rs2,

    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);

always @(*) begin
    forwardA = 2'b00;
    forwardB = 2'b00;

    // EX hazard
    if (EX_MEM_reg_write && (EX_MEM_rd != 0) &&
        (EX_MEM_rd == ID_EX_rs1))
        forwardA = 2'b10;

    if (EX_MEM_reg_write && (EX_MEM_rd != 0) &&
        (EX_MEM_rd == ID_EX_rs2))
        forwardB = 2'b10;

    // MEM hazard
    if (MEM_WB_reg_write && (MEM_WB_rd != 0) &&
        (MEM_WB_rd == ID_EX_rs1))
        forwardA = 2'b01;

    if (MEM_WB_reg_write && (MEM_WB_rd != 0) &&
        (MEM_WB_rd == ID_EX_rs2))
        forwardB = 2'b01;
end

endmodule
