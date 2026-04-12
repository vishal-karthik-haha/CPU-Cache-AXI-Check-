// =============================================================================
// CacheMemory.v  –  Direct-Mapped Cache for DataMemory
//
// Cache configuration:
//   Cache lines : 8  (INDEX_BITS = 3)
//   Block size  : 4 bytes (OFFSET_BITS = 2)
//   Tag bits    : 3 bits   [7:5]
//   Index bits  : 3 bits   [4:2]
//   Offset bits : 2 bits   [1:0]
//
// Policy: direct-mapped, write-through
// =============================================================================
module CacheMemory #(
    parameter DATA_WIDTH  = 8,
    parameter ADDR_WIDTH  = 8,
    parameter INDEX_BITS  = 3,
    parameter OFFSET_BITS = 2,
    parameter MISS_CYCLES = 3
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  mem_read,
    input  wire                  mem_write,
    input  wire [ADDR_WIDTH-1:0] address,
    input  wire [DATA_WIDTH-1:0] write_data,
    output reg  [DATA_WIDTH-1:0] read_data,
    output wire                  stall
);

    localparam NUM_LINES   = 1 << INDEX_BITS;
    localparam TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam BLOCK_BYTES = 1 << OFFSET_BITS;

    // -------------------------------------------------------------------------
    // Address decomposition
    // -------------------------------------------------------------------------
    wire [TAG_BITS-1:0]    addr_tag    = address[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];
    wire [INDEX_BITS-1:0]  addr_index  = address[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [OFFSET_BITS-1:0] addr_offset = address[OFFSET_BITS-1:0];

    // -------------------------------------------------------------------------
    // Cache storage
    // -------------------------------------------------------------------------
    reg [TAG_BITS-1:0]               tag_array  [0:NUM_LINES-1];
    reg                              valid      [0:NUM_LINES-1];
    reg [DATA_WIDTH*BLOCK_BYTES-1:0] data_array [0:NUM_LINES-1];

    // -------------------------------------------------------------------------
    // Hit detection
    // -------------------------------------------------------------------------
    wire hit = valid[addr_index] && (tag_array[addr_index] == addr_tag);

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    localparam S_IDLE   = 2'd0;
    localparam S_MISS   = 2'd1;
    localparam S_REFILL = 2'd2;
    localparam S_WRITE  = 2'd3;

    reg [1:0] state;

    // FIX 1: cycle_cnt needs enough bits to count up to MISS_CYCLES-1.
    // $clog2(MISS_CYCLES) gives log2(3)=2 bits which only holds 0-3, fine,
    // but using just $clog2 risks being 1 bit short for powers of 2.
    // Using $clog2(MISS_CYCLES+1) is always safe.
    reg [$clog2(MISS_CYCLES+1)-1:0] cycle_cnt;

    reg [OFFSET_BITS-1:0]           fill_offset;
    reg [ADDR_WIDTH-1:0]            fill_addr;
    reg [DATA_WIDTH*BLOCK_BYTES-1:0] fill_buf;

    // -------------------------------------------------------------------------
    // Main memory interface
    // -------------------------------------------------------------------------
    reg                  mm_read_en, mm_write_en;
    reg  [ADDR_WIDTH-1:0] mm_addr;
    reg  [DATA_WIDTH-1:0] mm_wdata;
    wire [DATA_WIDTH-1:0] mm_rdata;

    DataMemory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DEPTH      (1 << ADDR_WIDTH)
    ) main_mem (
        .clk        (clk),
        .mem_write  (mm_write_en),
        .mem_read   (mm_read_en),
        .address    (mm_addr),
        .write_data (mm_wdata),
        .read_data  (mm_rdata)
    );

    // -------------------------------------------------------------------------
    // FIX 2: Stall logic.
    // Original incorrectly stalled on EVERY write even on the cycle the write
    // completes (when returning to IDLE). Now stall is only asserted while
    // actively busy (not in IDLE), or on the very first cycle of a new miss/write
    // before the FSM has transitioned away from IDLE.
    // -------------------------------------------------------------------------
    assign stall = (state != S_IDLE) ||
                   (mem_read  && !hit) ||
                   (mem_write);

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= S_IDLE;
            cycle_cnt   <= 0;
            fill_offset <= 0;
            mm_read_en  <= 0;
            mm_write_en <= 0;
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid[i]     <= 1'b0;
                tag_array[i] <= 0;
            end
        end
        else begin
            mm_read_en  <= 1'b0;
            mm_write_en <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (mem_read && !hit) begin
                        // Compute aligned block base address
                        fill_addr   <= {addr_tag, addr_index, {OFFSET_BITS{1'b0}}};
                        fill_offset <= 0;
                        cycle_cnt   <= 0;
                        state       <= S_MISS;
                    end
                    else if (mem_write) begin
                        mm_addr     <= address;
                        mm_wdata    <= write_data;
                        mm_write_en <= 1'b1;
                        cycle_cnt   <= 0;
                        state       <= S_WRITE;

                        // Write-hit: also update the cached word
                        if (hit) begin
                            case (addr_offset)
                                2'd0: data_array[addr_index][7:0]   <= write_data;
                                2'd1: data_array[addr_index][15:8]  <= write_data;
                                2'd2: data_array[addr_index][23:16] <= write_data;
                                2'd3: data_array[addr_index][31:24] <= write_data;
                            endcase
                        end
                    end
                    // hit read: handled combinationally, no FSM transition needed
                end

                // FIX 3: DataMemory has a 1-cycle registered read latency.
                // We must issue mm_read_en one cycle BEFORE we want the data.
                // So: assert mm_read_en on cycle 0, data is valid on cycle 1.
                // We wait MISS_CYCLES total, capture on the last cycle.
                S_MISS: begin
                    mm_addr    <= fill_addr + {{(ADDR_WIDTH-OFFSET_BITS){1'b0}}, fill_offset};
                    mm_read_en <= 1'b1;

                    if (cycle_cnt == MISS_CYCLES - 1) begin
                        // mm_rdata is valid this cycle (issued read MISS_CYCLES-1 ago)
                        case (fill_offset)
                            2'd0: fill_buf[7:0]   <= mm_rdata;
                            2'd1: fill_buf[15:8]  <= mm_rdata;
                            2'd2: fill_buf[23:16] <= mm_rdata;
                            2'd3: fill_buf[31:24] <= mm_rdata;
                        endcase

                        if (fill_offset == BLOCK_BYTES - 1) begin
                            state <= S_REFILL;
                        end
                        else begin
                            fill_offset <= fill_offset + 1;
                            cycle_cnt   <= 0;
                        end
                    end
                    else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end

                S_REFILL: begin
                    data_array[addr_index] <= fill_buf;
                    tag_array[addr_index]  <= addr_tag;
                    valid[addr_index]      <= 1'b1;
                    state                  <= S_IDLE;
                    // FIX 4: addr_tag/addr_index are still stable here because
                    // the pipeline is stalled, so the refill targets the correct line.
                end

                S_WRITE: begin
                    if (cycle_cnt == MISS_CYCLES - 1) begin
                        state <= S_IDLE;
                    end
                    else begin
                        cycle_cnt   <= cycle_cnt + 1;
                        mm_write_en <= 1'b1;
                    end
                end

            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read data output — combinational on hit.
    // After a refill the FSM goes back to IDLE and the next cycle will hit,
    // so the processor gets valid data on the cycle stall de-asserts.
    // -------------------------------------------------------------------------
    always @(*) begin
        if (mem_read && hit) begin
            case (addr_offset)
                2'd0: read_data = data_array[addr_index][7:0];
                2'd1: read_data = data_array[addr_index][15:8];
                2'd2: read_data = data_array[addr_index][23:16];
                2'd3: read_data = data_array[addr_index][31:24];
                default: read_data = 8'h0;
            endcase
        end
        else begin
            read_data = 8'h0;
        end
    end

endmodule
