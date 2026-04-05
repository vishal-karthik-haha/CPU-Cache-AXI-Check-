`timescale 1ns / 1ps

module ALU_Decoder (
    input  [1:0] alu_op,
    input  [2:0] funct3,
    input        funct7_5,
    output reg [2:0] alu_control
);

    localparam ADD = 3'b000;
    localparam SUB = 3'b001;
    localparam AND = 3'b010;
    localparam OR  = 3'b011;

    always @(*) begin
        case (alu_op)

            2'b00: alu_control = ADD; // load/store
            2'b01: alu_control = SUB; // branch

            2'b10: begin
                case (funct3)
                    3'b000: alu_control = (funct7_5) ? SUB : ADD;
                    3'b111: alu_control = AND;
                    3'b110: alu_control = OR;
                    default: alu_control = ADD;
                endcase
            end

            default: alu_control = ADD;
        endcase
    end

endmodule
