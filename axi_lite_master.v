`timescale 1ns / 1ps

module axi_lite_master
  #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
    )
   (
    input init_transaction,

    input M_AXI_ACLK,
    input M_AXI_ARESETN,

    // aw
    output [AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
    output [2 : 0] M_AXI_AWPROT,
    output M_AXI_AWVALID,
    input M_AXI_AWREADY,

    // w
    output [AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
    output [AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
    output M_AXI_WVALID,
    input M_AXI_WREADY,

    // b resp
    input [1 : 0] M_AXI_BRESP,
    input M_AXI_BVALID,
    output M_AXI_BREADY,

    // ar
    output [AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
    output [2 : 0] M_AXI_ARPROT,
    output M_AXI_ARVALID,
    input M_AXI_ARREADY,

    // r
    input [AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
    input [1 : 0] M_AXI_RRESP,
    input M_AXI_RVALID,
    output M_AXI_RREADY
    );

   localparam HSIZE = 640;
   localparam VSIZE = 480;

   // Internal signals
   reg [AXI_ADDR_WIDTH-1:0] axi_awaddr;
   reg axi_awvalid;

   reg [AXI_DATA_WIDTH-1:0] axi_wdata;
   reg [AXI_DATA_WIDTH/8-1:0] axi_wstrb;
   reg axi_wvalid;

   reg axi_bready;
   reg axi_berror;

   reg [AXI_ADDR_WIDTH-1:0] axi_araddr;
   reg axi_arvalid;

   reg axi_rready;
   reg axi_rerror;

   assign M_AXI_AWADDR  = axi_awaddr;
   assign M_AXI_AWVALID = axi_awvalid;
   assign M_AXI_AWPROT  = 3'b000;

   assign M_AXI_WDATA = axi_wdata;
   assign M_AXI_WSTRB = axi_wstrb;
   assign M_AXI_WVALID = axi_wvalid;

   assign M_AXI_BREADY = axi_bready;

   assign M_AXI_ARADDR  = axi_araddr;
   assign M_AXI_ARVALID = axi_arvalid;
   assign M_AXI_ARPROT  = 3'b000;

   assign M_AXI_RREADY = axi_rready;

   wire write_done = axi_bready & M_AXI_BVALID;
   wire read_done  = axi_rready & M_AXI_RVALID;

   reg init_transaction_i;

   always @(posedge M_AXI_ACLK)
     init_transaction_i <= init_transaction;

   wire start = (init_transaction & ~init_transaction_i);

   // FSM states
   localparam IDLE = 3'd0,
             WR_REG_VDMACR = 3'd1,
             WR_REG_MM2S_HSIZE = 3'd2,
             WR_REG_MM2S_VSIZE = 3'd3,
             RD_REG_VDMACR = 3'd4,
             RD_REG_MM2S_HSIZE = 3'd5,
             RD_REG_MM2S_VSIZE = 3'd6;

   reg [2:0] current_state, next_state;

   reg start_write;
   reg start_read;

   always @(*) begin
      start_write = 0;
      start_read  = 0;
      next_state  = current_state;

      case (current_state)
        IDLE:
          if (start) begin
            next_state  = WR_REG_VDMACR;
            start_write = 1;
          end

        WR_REG_VDMACR:
          if (write_done) begin
            next_state  = WR_REG_MM2S_HSIZE;
            start_write = 1;
          end

        WR_REG_MM2S_HSIZE:
          if (write_done) begin
            next_state  = WR_REG_MM2S_VSIZE;
            start_write = 1;
          end

        WR_REG_MM2S_VSIZE:
          if (write_done) begin
            next_state = RD_REG_VDMACR;
            start_read = 1;
          end

        RD_REG_VDMACR:
          if (read_done) begin
            next_state = RD_REG_MM2S_HSIZE;
            start_read = 1;
          end

        RD_REG_MM2S_HSIZE:
          if (read_done) begin
            next_state = RD_REG_MM2S_VSIZE;
            start_read = 1;
          end

        RD_REG_MM2S_VSIZE:
          if (read_done)
            next_state = IDLE;
      endcase
   end

   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN)
        current_state <= IDLE;
      else
        current_state <= next_state;
   end

   // Address generation
   always @(*) begin
      case (current_state)
        WR_REG_VDMACR:       axi_awaddr = 32'h30;
        WR_REG_MM2S_HSIZE:   axi_awaddr = 32'hA4;
        WR_REG_MM2S_VSIZE:   axi_awaddr = 32'hA0;
        default:             axi_awaddr = 0;
      endcase
   end

   always @(*) begin
      case (current_state)
        WR_REG_VDMACR:       axi_wdata = 32'h03;
        WR_REG_MM2S_HSIZE:   axi_wdata = HSIZE;
        WR_REG_MM2S_VSIZE:   axi_wdata = VSIZE;
        default:             axi_wdata = 0;
      endcase
   end

   always @(*) begin
      case (current_state)
        RD_REG_VDMACR:       axi_araddr = 32'h30;
        RD_REG_MM2S_HSIZE:   axi_araddr = 32'hA4;
        RD_REG_MM2S_VSIZE:   axi_araddr = 32'hA0;
        default:             axi_araddr = 0;
      endcase
   end

   reg [AXI_DATA_WIDTH-1:0] rdata_expected;

   always @(*) begin
      case (current_state)
        RD_REG_VDMACR:       rdata_expected = 32'h03;
        RD_REG_MM2S_HSIZE:   rdata_expected = HSIZE;
        RD_REG_MM2S_VSIZE:   rdata_expected = VSIZE;
        default:             rdata_expected = 0;
      endcase
   end

   // Write address channel
   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN)
        axi_awvalid <= 0;
      else begin
        if (start_write)
          axi_awvalid <= 1;
        else if (M_AXI_AWREADY && axi_awvalid)
          axi_awvalid <= 0;
      end
   end

   // Write data channel
   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN) begin
        axi_wvalid <= 0;
        axi_wstrb  <= 0;
      end else begin
        if (start_write) begin
          axi_wvalid <= 1;
          axi_wstrb  <= 4'b1111;
        end else if (M_AXI_WREADY && axi_wvalid) begin
          axi_wvalid <= 0;
          axi_wstrb  <= 0;
        end
      end
   end

   // Write response
   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN) begin
        axi_bready <= 0;
        axi_berror <= 0;
      end else begin
        axi_bready <= 1;
        if (M_AXI_BVALID && axi_bready)
          axi_berror <= (M_AXI_BRESP > 0);
      end
   end

   // Read address
   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN)
        axi_arvalid <= 0;
      else begin
        if (start_read)
          axi_arvalid <= 1;
        else if (M_AXI_ARREADY && axi_arvalid)
          axi_arvalid <= 0;
      end
   end

   // Read data
   always @(posedge M_AXI_ACLK) begin
      if (!M_AXI_ARESETN) begin
        axi_rready <= 0;
        axi_rerror <= 0;
      end else begin
        axi_rready <= 1;
        if (M_AXI_RVALID && axi_rready) begin
          if (M_AXI_RRESP > 0 || M_AXI_RDATA != rdata_expected)
            axi_rerror <= 1;
          else
            axi_rerror <= 0;
        end
      end
   end

endmodule