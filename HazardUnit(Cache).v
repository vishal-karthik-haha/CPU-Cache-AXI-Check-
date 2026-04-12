module HazardUnit (
    input        ID_EX_mem_read,
    input  [2:0] ID_EX_rd,
    input  [2:0] IF_ID_rs1,
    input  [2:0] IF_ID_rs2,
    input        cache_stall,

    // Two separate outputs so Processor.v can act differently on each
    output       load_use_stall,   // freeze IF/ID, insert bubble into ID/EX
    output       stall             // freeze entire pipeline (cache miss)
);

    assign load_use_stall = (ID_EX_mem_read &&
                            ((ID_EX_rd == IF_ID_rs1) ||
                             (ID_EX_rd == IF_ID_rs2)));

    // Full pipeline freeze: cache miss takes priority; also freeze on load-use
    assign stall = cache_stall || load_use_stall;

endmodule
