module RegisterFile #(
    parameter DATA_WIDTH = 8,
    parameter REG_COUNT  = 8,
    parameter ADDR_WIDTH = 3
)(
    input clk,
    input write_enable,
    
    input [ADDR_WIDTH-1:0] read_reg1,
    input [ADDR_WIDTH-1:0] read_reg2,
    input [ADDR_WIDTH-1:0] write_reg,
    
    input [DATA_WIDTH-1:0] write_data,
    
    output [DATA_WIDTH-1:0] read_data1,
    output [DATA_WIDTH-1:0] read_data2
);

    reg [DATA_WIDTH-1:0] registers [0:REG_COUNT-1];

    integer i;

    // Initialization
    initial begin
        for (i = 0; i < REG_COUNT; i = i + 1)
            registers[i] = 0;

        registers[1] = 8'd5;
        registers[2] = 8'd3;
    end

    // Read (combinational)
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    // Write (synchronous)
    always @(posedge clk) begin
        registers[0] <= 0; // enforce x0 = 0

        if (write_enable && write_reg != 0) begin
            registers[write_reg] <= write_data;
        end
    end

endmodule
