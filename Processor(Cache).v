module Processor (
    input clk,
    input reset,
    output [15:0] pc_out,
    output [15:0] instruction,
    output [7:0]  alu_result
);

//////////////////// Stall wires ////////////////////

wire stall;           // full freeze (cache miss or load-use)
wire load_use_stall;  // load-use only — needs bubble in ID/EX
wire cache_stall;     // cache miss only — from CacheMemory

//////////////////// IF ////////////////////

wire [15:0] instr_IF, pc_IF;

InstructionFetch if_stage (
    .clk        (clk),
    .reset      (reset),
    .next_pc    (pc_IF + 1),
    .instruction(instr_IF),
    .pc_out     (pc_IF)
);

assign pc_out      = pc_IF;
assign instruction = instr_IF;

//////////////////// IF/ID ////////////////////
// Freeze on any stall (load-use or cache miss)

reg [15:0] IF_ID_instr;

always @(posedge clk or posedge reset) begin
    if (reset)
        IF_ID_instr <= 0;
    else if (!stall)
        IF_ID_instr <= instr_IF;
end

//////////////////// ID ////////////////////

wire [3:0] opcode = IF_ID_instr[15:12];
wire [2:0] rs1    = IF_ID_instr[11:9];
wire [2:0] rs2    = IF_ID_instr[8:6];
wire [2:0] rd     = IF_ID_instr[5:3];

wire [7:0] read_data1, read_data2;
wire [7:0] write_back_data;

reg [2:0] alu_control;
reg       reg_write;
reg       mem_read_ctrl;
reg       mem_write_ctrl;

always @(*) begin
    reg_write      = 1'b0;
    mem_read_ctrl  = 1'b0;
    mem_write_ctrl = 1'b0;
    alu_control    = 3'b000;
    case (opcode)
        4'b0000: begin reg_write = 1'b1; alu_control = 3'b000; end  // ADD
        4'b0001: begin reg_write = 1'b1; alu_control = 3'b001; end  // SUB
        4'b0010: begin reg_write = 1'b1; alu_control = 3'b010; end  // AND
        4'b0011: begin reg_write = 1'b1; alu_control = 3'b011; end  // OR
        4'b1000: begin reg_write = 1'b1; mem_read_ctrl  = 1'b1; alu_control = 3'b000; end  // LOAD
        4'b1001: begin                   mem_write_ctrl = 1'b1; alu_control = 3'b000; end  // STORE
        default: alu_control = 3'b000;
    endcase
end

RegisterFile rf (
    .clk         (clk),
    .write_enable(MEM_WB_reg_write),
    .read_reg1   (rs1),
    .read_reg2   (rs2),
    .write_reg   (MEM_WB_rd),
    .write_data  (write_back_data),
    .read_data1  (read_data1),
    .read_data2  (read_data2)
);

//////////////////// ID/EX ////////////////////
// On load-use stall: insert bubble (zero out control signals)
// On cache stall:    freeze (hold current values)
// On no stall:       advance normally

reg [7:0] ID_EX_A, ID_EX_B;
reg [2:0] ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
reg       ID_EX_reg_write;
reg [2:0] ID_EX_alu_control;
reg       ID_EX_mem_read;
reg       ID_EX_mem_write;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        ID_EX_A           <= 0; ID_EX_B           <= 0;
        ID_EX_rs1         <= 0; ID_EX_rs2         <= 0;
        ID_EX_rd          <= 0; ID_EX_reg_write   <= 0;
        ID_EX_alu_control <= 0;
        ID_EX_mem_read    <= 0; ID_EX_mem_write   <= 0;
    end
    else if (load_use_stall) begin
        // Insert bubble: zero control signals, keep data (doesn't matter)
        ID_EX_reg_write   <= 0;
        ID_EX_mem_read    <= 0;
        ID_EX_mem_write   <= 0;
        ID_EX_rd          <= 0;
        ID_EX_alu_control <= 0;
    end
    else if (!cache_stall) begin
        // Normal advance (also covers: no stall at all)
        ID_EX_A           <= read_data1;
        ID_EX_B           <= read_data2;
        ID_EX_rs1         <= rs1;
        ID_EX_rs2         <= rs2;
        ID_EX_rd          <= rd;
        ID_EX_reg_write   <= reg_write;
        ID_EX_alu_control <= alu_control;
        ID_EX_mem_read    <= mem_read_ctrl;
        ID_EX_mem_write   <= mem_write_ctrl;
    end
    // else cache_stall && !load_use_stall: freeze (do nothing)
end

//////////////////// Forwarding ////////////////////

wire [1:0] forwardA, forwardB;

ForwardingUnit fwd (
    .EX_MEM_reg_write(EX_MEM_reg_write),
    .MEM_WB_reg_write(MEM_WB_reg_write),
    .EX_MEM_rd       (EX_MEM_rd),
    .MEM_WB_rd       (MEM_WB_rd),
    .ID_EX_rs1       (ID_EX_rs1),
    .ID_EX_rs2       (ID_EX_rs2),
    .forwardA        (forwardA),
    .forwardB        (forwardB)
);

wire [7:0] forwardA_data =
    (forwardA == 2'b10) ? EX_MEM_alu     :
    (forwardA == 2'b01) ? write_back_data :
                          ID_EX_A;

wire [7:0] forwardB_data =
    (forwardB == 2'b10) ? EX_MEM_alu     :
    (forwardB == 2'b01) ? write_back_data :
                          ID_EX_B;

//////////////////// EX ////////////////////

wire [7:0] alu_out;
wire zero, carry, negative, overflow;

ALU1 alu (
    .A       (forwardA_data),
    .B       (forwardB_data),
    .alu_op  (ID_EX_alu_control),
    .result  (alu_out),
    .zero    (zero),
    .carry   (carry),
    .negative(negative),
    .overflow(overflow)
);

assign alu_result = alu_out;

//////////////////// EX/MEM ////////////////////
// Freeze only on cache stall.
// On load-use stall this stage must still advance (the EX instruction is fine).

reg [7:0] EX_MEM_alu;
reg [7:0] EX_MEM_wdata;
reg [2:0] EX_MEM_rd;
reg       EX_MEM_reg_write;
reg       EX_MEM_mem_read;
reg       EX_MEM_mem_write;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        EX_MEM_alu       <= 0; EX_MEM_wdata     <= 0;
        EX_MEM_rd        <= 0; EX_MEM_reg_write <= 0;
        EX_MEM_mem_read  <= 0; EX_MEM_mem_write <= 0;
    end
    else if (!cache_stall) begin  // only freeze on cache miss, not load-use
        EX_MEM_alu       <= alu_out;
        EX_MEM_wdata     <= forwardB_data;
        EX_MEM_rd        <= ID_EX_rd;
        EX_MEM_reg_write <= ID_EX_reg_write;
        EX_MEM_mem_read  <= ID_EX_mem_read;
        EX_MEM_mem_write <= ID_EX_mem_write;
    end
end

//////////////////// MEM — CacheMemory ////////////////////

wire [7:0] mem_rdata;

CacheMemory #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(8)
) dcache (
    .clk        (clk),
    .reset      (reset),
    .mem_read   (EX_MEM_mem_read),
    .mem_write  (EX_MEM_mem_write),
    .address    (EX_MEM_alu),
    .write_data (EX_MEM_wdata),
    .read_data  (mem_rdata),
    .stall      (cache_stall)
);

//////////////////// HazardUnit ////////////////////

HazardUnit hazard (
    .ID_EX_mem_read (ID_EX_mem_read),
    .ID_EX_rd       (ID_EX_rd),
    .IF_ID_rs1      (rs1),
    .IF_ID_rs2      (rs2),
    .cache_stall    (cache_stall),
    .load_use_stall (load_use_stall),
    .stall          (stall)
);

//////////////////// MEM/WB ////////////////////
// Freeze on cache stall only

reg [7:0] MEM_WB_alu;
reg [7:0] MEM_WB_mem_data;
reg [2:0] MEM_WB_rd;
reg       MEM_WB_reg_write;
reg       MEM_WB_mem_to_reg;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        MEM_WB_alu        <= 0; MEM_WB_mem_data   <= 0;
        MEM_WB_rd         <= 0; MEM_WB_reg_write  <= 0;
        MEM_WB_mem_to_reg <= 0;
    end
    else if (!cache_stall) begin  // only freeze on cache miss
        MEM_WB_alu        <= EX_MEM_alu;
        MEM_WB_mem_data   <= mem_rdata;
        MEM_WB_rd         <= EX_MEM_rd;
        MEM_WB_reg_write  <= EX_MEM_reg_write;
        MEM_WB_mem_to_reg <= EX_MEM_mem_read;
    end
end

//////////////////// WB ////////////////////

assign write_back_data = MEM_WB_mem_to_reg ? MEM_WB_mem_data : MEM_WB_alu;

endmodule
