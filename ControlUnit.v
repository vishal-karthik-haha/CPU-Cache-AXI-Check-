`timescale 1ns / 1ps
module ControlUnit (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input        funct7_5,
    input        zero,

    output       reg_write,
    output       alu_src,
    output [2:0] alu_control,
    output       mem_write,
    output       mem_read,
    output       mem_to_reg,
    output       pc_src,
    output [1:0] imm_sel
);

    wire [1:0] alu_op;
    wire branch;
    wire jump;

    MainDecoder md (
        .opcode(opcode),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jump(jump),
        .imm_sel(imm_sel)
    );

    ALU_Decoder ad (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .alu_control(alu_control)
    );

    assign pc_src = (branch & zero) | jump;

endmodule
