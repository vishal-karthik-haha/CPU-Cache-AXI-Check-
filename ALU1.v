`timescale 1ns / 1ps

module ALU1 #(
    parameter DATA_WIDTH = 8
)(
    input  [DATA_WIDTH-1:0] A,
    input  [DATA_WIDTH-1:0] B,
    input  [2:0] alu_op,

    output reg [DATA_WIDTH-1:0] result,
    output reg zero,
    output reg carry,
    output reg negative,
    output reg overflow
);

    localparam ADD = 3'b000;
    localparam SUB = 3'b001;
    localparam AND_OP = 3'b010;
    localparam OR_OP  = 3'b011;

    reg [DATA_WIDTH:0] temp;

    always @(*) begin
        result   = 0;
        temp     = 0;
        carry    = 0;
        overflow = 0;

        case(alu_op)

            ADD: begin
                temp = A + B;
                result = temp[DATA_WIDTH-1:0];
                carry = temp[DATA_WIDTH];
                overflow = (A[DATA_WIDTH-1] == B[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != A[DATA_WIDTH-1]);
            end

            SUB: begin
                temp = A - B;
                result = temp[DATA_WIDTH-1:0];
                carry = temp[DATA_WIDTH];
                overflow = (A[DATA_WIDTH-1] != B[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != A[DATA_WIDTH-1]);
            end

            AND_OP: result = A & B;
            OR_OP:  result = A | B;

            default: result = 0;
        endcase

        zero     = (result == 0);
        negative = result[DATA_WIDTH-1];
    end

endmodule
