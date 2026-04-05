module HazardUnit (
    input        ID_EX_mem_read,
    input  [2:0] ID_EX_rd,
    input  [2:0] IF_ID_rs1,
    input  [2:0] IF_ID_rs2,
    output       stall
);

assign stall = (ID_EX_mem_read &&
               ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)));

endmodule
