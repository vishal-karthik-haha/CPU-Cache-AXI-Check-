module Processor (
    input clk,
    input reset,
    output [15:0] pc_out,
    output [15:0] instruction,
    output [7:0]  alu_result
);

//////////////////// IF ////////////////////
wire [15:0] instr_IF, pc_IF, next_pc;
wire PCWrite;

assign next_pc = pc_IF + 1;

InstructionFetch if_stage (
    .clk(clk),
    .reset(reset),
    .next_pc(PCWrite ? next_pc : pc_IF),  // ✅ stall support
    .instruction(instr_IF),
    .pc_out(pc_IF)
);

assign pc_out = pc_IF;
assign instruction = instr_IF;

//////////////////// IF/ID ////////////////////
reg [15:0] IF_ID_instr;

//////////////////// ID ////////////////////
wire [2:0] rs1 = IF_ID_instr[11:9];
wire [2:0] rs2 = IF_ID_instr[8:6];
wire [2:0] rd  = IF_ID_instr[5:3];
wire [2:0] funct3 = IF_ID_instr[2:0];
wire [3:0] opcode_4 = IF_ID_instr[15:12];

reg [6:0] opcode_7;
always @(*) begin
    case (opcode_4)
        4'b0000: opcode_7 = 7'b0110011;
        4'b0001: opcode_7 = 7'b0010011;
        default: opcode_7 = 7'b0000000;
    endcase
end

wire reg_write, alu_src, mem_write, mem_read, mem_to_reg;
wire [2:0] alu_control;
wire zero;

ControlUnit cu (
    .opcode(opcode_7),
    .funct3(funct3),
    .funct7_5(1'b0),
    .zero(zero),
    .reg_write(reg_write),
    .alu_src(alu_src),
    .alu_control(alu_control),
    .mem_write(mem_write),
    .mem_read(mem_read),
    .mem_to_reg(mem_to_reg),
    .pc_src(),
    .imm_sel()
);

wire [7:0] read_data1, read_data2;
wire [7:0] write_back_data;

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

//////////////////// Hazard ////////////////////
wire stall;
assign PCWrite = ~stall;

HazardUnit hazard (
    .ID_EX_mem_read(ID_EX_mem_read),
    .ID_EX_rd(ID_EX_rd),
    .IF_ID_rs1(rs1),
    .IF_ID_rs2(rs2),
    .stall(stall)
);

//////////////////// IF/ID UPDATE ////////////////////
always @(posedge clk or posedge reset) begin
    if (reset)
        IF_ID_instr <= 0;
    else if (~stall)
        IF_ID_instr <= instr_IF;
end

//////////////////// ID/EX ////////////////////
reg [7:0] ID_EX_A, ID_EX_B, ID_EX_imm;
reg [2:0] ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
reg ID_EX_reg_write, ID_EX_mem_write, ID_EX_mem_read, ID_EX_mem_to_reg;
reg ID_EX_alu_src;
reg [2:0] ID_EX_alu_control;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        ID_EX_reg_write <= 0;
    end
    else if (stall) begin
        ID_EX_reg_write <= 0;
        ID_EX_mem_write <= 0;
        ID_EX_mem_read  <= 0;
        ID_EX_mem_to_reg <= 0;
        ID_EX_alu_src <= 0;
        ID_EX_alu_control <= 0;
    end
    else begin
        ID_EX_A <= read_data1;
        ID_EX_B <= read_data2;
        ID_EX_imm <= {{2{1'b0}}, IF_ID_instr[5:0]};  // ✅ FIXED
        ID_EX_rs1 <= rs1;
        ID_EX_rs2 <= rs2;
        ID_EX_rd <= rd;

        ID_EX_reg_write <= reg_write;
        ID_EX_mem_write <= mem_write;
        ID_EX_mem_read  <= mem_read;
        ID_EX_mem_to_reg <= mem_to_reg;
        ID_EX_alu_src <= alu_src;
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
wire [7:0] alu_in2 = ID_EX_alu_src ? ID_EX_imm : forwardB_data;

wire [7:0] alu_out;
wire carry, negative, overflow;

ALU1 alu (
    .A(forwardA_data),
    .B(alu_in2),
    .alu_op(ID_EX_alu_control),
    .result(alu_out),
    .zero(zero),
    .carry(carry),
    .negative(negative),
    .overflow(overflow)
);

assign alu_result = alu_out;

//////////////////// EX/MEM ////////////////////
reg [7:0] EX_MEM_alu, EX_MEM_B;
reg [2:0] EX_MEM_rd;
reg EX_MEM_reg_write, EX_MEM_mem_write, EX_MEM_mem_read, EX_MEM_mem_to_reg;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        EX_MEM_alu <= 0;
    end else begin
        EX_MEM_alu <= alu_out;
        EX_MEM_B <= forwardB_data;
        EX_MEM_rd <= ID_EX_rd;

        EX_MEM_reg_write <= ID_EX_reg_write;
        EX_MEM_mem_write <= ID_EX_mem_write;
        EX_MEM_mem_read  <= ID_EX_mem_read;
        EX_MEM_mem_to_reg <= ID_EX_mem_to_reg;
    end
end

//////////////////// MEM ////////////////////
wire [7:0] mem_data;

DataMemory dmem (
    .clk(clk),
    .mem_write(EX_MEM_mem_write),
    .mem_read(EX_MEM_mem_read),
    .address(EX_MEM_alu),
    .write_data(EX_MEM_B),
    .read_data(mem_data)
);

//////////////////// MEM/WB ////////////////////
reg [7:0] MEM_WB_mem_data, MEM_WB_alu;
reg [2:0] MEM_WB_rd;
reg MEM_WB_reg_write, MEM_WB_mem_to_reg;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        MEM_WB_mem_data <= 0;
    end else begin
        MEM_WB_mem_data <= mem_data;
        MEM_WB_alu <= EX_MEM_alu;
        MEM_WB_rd <= EX_MEM_rd;

        MEM_WB_reg_write <= EX_MEM_reg_write;
        MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;
    end
end

//////////////////// WB ////////////////////
assign write_back_data = MEM_WB_mem_to_reg ?
                         MEM_WB_mem_data :
                         MEM_WB_alu;

endmodule
