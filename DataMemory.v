module DataMemory #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH      = 256
)(
    input                   clk,
    input                   mem_write,
    input                   mem_read,
    input  [ADDR_WIDTH-1:0] address,
    input  [DATA_WIDTH-1:0] write_data,
    output [DATA_WIDTH-1:0] read_data
);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] read_reg;

    integer i;

    // Initialization
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 0;
    end

    // Write (synchronous)
    always @(posedge clk) begin
        if (mem_write)
            memory[address] <= write_data;
    end

    // Read (synchronous → pipeline correct)
    always @(posedge clk) begin
        if (mem_read)
            read_reg <= memory[address];
    end

    assign read_data = read_reg;

endmodule
