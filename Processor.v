module Processor (
    input clk,
    input reset,
    output [15:0] pc_out,
    output [15:0] instruction,
    output [7:0]  alu_result
);

//////////////////// IF ////////////////////
wire [15:0] instr_IF, pc_IF;

InstructionFetch if_stage (
    .clk(clk),
    .reset(reset),
    .next_pc(pc_IF + 1),
    .instruction(instr_IF),
    .pc_out(pc_IF)
);

assign pc_out = pc_IF;
assign instruction = instr_IF;

//////////////////// IF/ID ////////////////////
reg [15:0] IF_ID_instr;

always @(posedge clk or posedge reset) begin
    if (reset)
        IF_ID_instr <= 0;
    else
        IF_ID_instr <= instr_IF;
end

//////////////////// ID ////////////////////
wire [3:0] opcode = IF_ID_instr[15:12];
wire [2:0] rs1 = IF_ID_instr[11:9];
wire [2:0] rs2 = IF_ID_instr[8:6];
wire [2:0] rd  = IF_ID_instr[5:3];

wire [7:0] read_data1, read_data2;
wire [7:0] write_back_data;

// 🔥 DIRECT CONTROL (FIXED)
reg [2:0] alu_control;
reg reg_write;

always @(*) begin
    reg_write = 1'b1;

    case (opcode)
        4'b0000: alu_control = 3'b000; // ADD
        4'b0001: alu_control = 3'b001; // SUB
        4'b0010: alu_control = 3'b010; // AND
        4'b0011: alu_control = 3'b011; // OR
        default: alu_control = 3'b000;
    endcase
end

RegisterFile rf (
    .clk(clk),
    .write_enable(MEM_WB_reg_write),
    .read_reg1(rs1),
    .read_reg2(rs2),
    .write_reg(MEM_WB_rd),
    .write_data(write_back_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
);

//////////////////// ID/EX ////////////////////
reg [7:0] ID_EX_A, ID_EX_B;
reg [2:0] ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
reg ID_EX_reg_write;
reg [2:0] ID_EX_alu_control;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        ID_EX_A <= 0;
        ID_EX_B <= 0;
        ID_EX_rs1 <= 0;
        ID_EX_rs2 <= 0;
        ID_EX_rd <= 0;
        ID_EX_reg_write <= 0;
        ID_EX_alu_control <= 0;
    end else begin
        ID_EX_A <= read_data1;
        ID_EX_B <= read_data2;
        ID_EX_rs1 <= rs1;
        ID_EX_rs2 <= rs2;
        ID_EX_rd <= rd;

        ID_EX_reg_write <= reg_write;
        ID_EX_alu_control <= alu_control;
    end
end

//////////////////// Forwarding ////////////////////
wire [1:0] forwardA, forwardB;

ForwardingUnit fwd (
    .EX_MEM_reg_write(EX_MEM_reg_write),
    .MEM_WB_reg_write(MEM_WB_reg_write),
    .EX_MEM_rd(EX_MEM_rd),
    .MEM_WB_rd(MEM_WB_rd),
    .ID_EX_rs1(ID_EX_rs1),
    .ID_EX_rs2(ID_EX_rs2),
    .forwardA(forwardA),
    .forwardB(forwardB)
);

wire [7:0] forwardA_data =
    (forwardA == 2'b10) ? EX_MEM_alu :
    (forwardA == 2'b01) ? write_back_data :
    ID_EX_A;

wire [7:0] forwardB_data =
    (forwardB == 2'b10) ? EX_MEM_alu :
    (forwardB == 2'b01) ? write_back_data :
    ID_EX_B;

//////////////////// EX ////////////////////
wire [7:0] alu_out;
wire zero, carry, negative, overflow;

ALU1 alu (
    .A(forwardA_data),
    .B(forwardB_data),
    .alu_op(ID_EX_alu_control),
    .result(alu_out),
    .zero(zero),
    .carry(carry),
    .negative(negative),
    .overflow(overflow)
);

assign alu_result = alu_out;

//////////////////// EX/MEM ////////////////////
reg [7:0] EX_MEM_alu;
reg [2:0] EX_MEM_rd;
reg EX_MEM_reg_write;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        EX_MEM_alu <= 0;
        EX_MEM_rd <= 0;
        EX_MEM_reg_write <= 0;
    end else begin
        EX_MEM_alu <= alu_out;
        EX_MEM_rd <= ID_EX_rd;
        EX_MEM_reg_write <= ID_EX_reg_write;
    end
end

//////////////////// MEM/WB ////////////////////
reg [7:0] MEM_WB_alu;
reg [2:0] MEM_WB_rd;
reg MEM_WB_reg_write;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        MEM_WB_alu <= 0;
        MEM_WB_rd <= 0;
        MEM_WB_reg_write <= 0;
    end else begin
        MEM_WB_alu <= EX_MEM_alu;
        MEM_WB_rd <= EX_MEM_rd;
        MEM_WB_reg_write <= EX_MEM_reg_write;
    end
end

//////////////////// WB ////////////////////
assign write_back_data = MEM_WB_alu;

endmodule
