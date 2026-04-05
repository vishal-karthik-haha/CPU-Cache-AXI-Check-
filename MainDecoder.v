`timescale 1ns / 1ps
module MainDecoder (
    input  [6:0] opcode,
    // Control signals
    output reg       reg_write,
    output reg       alu_src,
    output reg [1:0] alu_op,
    output reg       mem_write,
    output reg       mem_read,
    output reg       mem_to_reg,
    output reg       branch,
    output reg       jump,
    output reg [1:0] imm_sel
);
    // Opcodes (RISC-V)
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;

    // ALUOp encoding - must match ALU_Decoder ALUP_* constants
    localparam ALU_ADD  = 2'b00;  // force ADD  (LOAD, STORE, JAL, JALR)
    localparam ALU_SUB  = 2'b01;  // force SUB  (BRANCH)
    localparam ALU_FUNC = 2'b10;  // decode via funct3/funct7 (R-type, I-type)

    // ImmSel encoding
    localparam IMM_I = 2'b00;

    always @(*) begin
        // Defaults - prevents latches
        reg_write  = 0;
        alu_src    = 0;
        alu_op     = ALU_ADD;
        mem_write  = 0;
        mem_read   = 0;
        mem_to_reg = 0;
        branch     = 0;
        jump       = 0;
        imm_sel    = IMM_I;

        case (opcode)
            // --------------------------------------------------
            // R-TYPE  (ADD, SUB, AND, OR, XOR)
            // ALU operands: rs1, rs2
            // ALU op decoded via funct3/funct7 in ALU_Decoder
            // --------------------------------------------------
            OP_RTYPE: begin
                reg_write = 1;
                alu_src   = 0;       // use register B
                alu_op    = ALU_FUNC;
            end

            // --------------------------------------------------
            // I-TYPE  (ADDI, ANDI, ORI, XORI)
            // ALU operands: rs1, imm
            // ALU op decoded via funct3 in ALU_Decoder
            // --------------------------------------------------
            OP_ITYPE: begin
                reg_write = 1;
                alu_src   = 1;       // use immediate
                alu_op    = ALU_FUNC;
                imm_sel   = IMM_I;
            end

            // All other opcodes: outputs stay at safe defaults
            default: begin
                reg_write  = 0;
                alu_src    = 0;
                alu_op     = ALU_ADD;
                mem_write  = 0;
                mem_read   = 0;
                mem_to_reg = 0;
                branch     = 0;
                jump       = 0;
                imm_sel    = IMM_I;
            end
        endcase
    end
endmodule
