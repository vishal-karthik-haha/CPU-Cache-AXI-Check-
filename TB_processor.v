`timescale 1ns / 1ps

module Processor_tb;

    reg clk;
    reg reset;

    wire [15:0] pc_out;
    wire [15:0] instruction;
    wire [7:0]  alu_result;

    // DUT
    Processor uut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc_out),
        .instruction(instruction),
        .alu_result(alu_result)
    );

    ////////////////// CLOCK //////////////////
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    ////////////////// RESET //////////////////
    initial begin
        reset = 1;
        #12;
        reset = 0;
    end

    ////////////////// WAVEFORM //////////////////
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, Processor_tb);
    end

    ////////////////// SCOREBOARD //////////////////

    integer cycle = 0;

    // Expected ALU outputs (based on your program)
    reg [7:0] expected [0:3];

    initial begin
        expected[0] = 8;  // ADD: 5 + 3
        expected[1] = 5;  // SUB: 8 - 3
        expected[2] = 0;  // AND
        expected[3] = 5;  // OR
    end

    ////////////////// MONITOR //////////////////
    always @(posedge clk) begin
        cycle = cycle + 1;

        $display("Cycle=%0d | PC=%0d | Instr=%b | ALU=%0d",
                  cycle, pc_out, instruction, alu_result);

        // -------------------------
        // BASIC SANITY CHECKS
        // -------------------------

        if (pc_out > 20) begin
            $display("ERROR: PC runaway");
            $stop;
        end

        // -------------------------
        // ALU CHECK (after pipeline fill)
        // -------------------------
        if (cycle > 5 && cycle < 15) begin
            case (pc_out)

                1: if (alu_result !== expected[0])
                        $display("❌ ERROR ADD wrong");

                2: if (alu_result !== expected[1])
                        $display("❌ ERROR SUB wrong (forwarding issue)");

                3: if (alu_result !== expected[2])
                        $display("❌ ERROR AND wrong");

                4: if (alu_result !== expected[3])
                        $display("❌ ERROR OR wrong");

            endcase
        end

        // -------------------------
        // STALL DETECTION (optional)
        // -------------------------
        if (cycle > 5) begin
            if (uut.stall)
                $display("⚠ Stall detected at cycle %0d", cycle);
        end

        // -------------------------
        // FORWARDING CHECK
        // -------------------------
        if (cycle > 5) begin
            if (uut.forwardA != 0 || uut.forwardB != 0)
                $display("✔ Forwarding active: A=%b B=%b",
                          uut.forwardA, uut.forwardB);
        end

    end

    ////////////////// FINISH //////////////////
    initial begin
        #200;
        $display("Simulation completed.");
        $finish;
    end

endmodule
