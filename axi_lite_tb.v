`timescale 1ns / 1ps

module axi_lite_master_tb;

  parameter AXI_ADDR_WIDTH = 32;
  parameter AXI_DATA_WIDTH = 32;

  reg init_transaction;
  reg M_AXI_ACLK;
  reg M_AXI_ARESETN;

  // AXI signals
  wire [AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR;
  wire [2:0] M_AXI_AWPROT;
  wire M_AXI_AWVALID;
  reg  M_AXI_AWREADY;

  wire [AXI_DATA_WIDTH-1:0] M_AXI_WDATA;
  wire [AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB;
  wire M_AXI_WVALID;
  reg  M_AXI_WREADY;

  reg [1:0] M_AXI_BRESP;
  reg M_AXI_BVALID;
  wire M_AXI_BREADY;

  wire [AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR;
  wire [2:0] M_AXI_ARPROT;
  wire M_AXI_ARVALID;
  reg  M_AXI_ARREADY;

  reg [AXI_DATA_WIDTH-1:0] M_AXI_RDATA;
  reg [1:0] M_AXI_RRESP;
  reg M_AXI_RVALID;
  wire M_AXI_RREADY;

  // DUT instantiation
  axi_lite_master dut (
    .init_transaction(init_transaction),
    .M_AXI_ACLK(M_AXI_ACLK),
    .M_AXI_ARESETN(M_AXI_ARESETN),

    .M_AXI_AWADDR(M_AXI_AWADDR),
    .M_AXI_AWPROT(M_AXI_AWPROT),
    .M_AXI_AWVALID(M_AXI_AWVALID),
    .M_AXI_AWREADY(M_AXI_AWREADY),

    .M_AXI_WDATA(M_AXI_WDATA),
    .M_AXI_WSTRB(M_AXI_WSTRB),
    .M_AXI_WVALID(M_AXI_WVALID),
    .M_AXI_WREADY(M_AXI_WREADY),

    .M_AXI_BRESP(M_AXI_BRESP),
    .M_AXI_BVALID(M_AXI_BVALID),
    .M_AXI_BREADY(M_AXI_BREADY),

    .M_AXI_ARADDR(M_AXI_ARADDR),
    .M_AXI_ARPROT(M_AXI_ARPROT),
    .M_AXI_ARVALID(M_AXI_ARVALID),
    .M_AXI_ARREADY(M_AXI_ARREADY),

    .M_AXI_RDATA(M_AXI_RDATA),
    .M_AXI_RRESP(M_AXI_RRESP),
    .M_AXI_RVALID(M_AXI_RVALID),
    .M_AXI_RREADY(M_AXI_RREADY)
  );

  // Clock generation
  initial begin
    M_AXI_ACLK = 0;
    forever #5 M_AXI_ACLK = ~M_AXI_ACLK; // 100 MHz
  end

  // Reset
  initial begin
    M_AXI_ARESETN = 0;
    #20;
    M_AXI_ARESETN = 1;
  end

  // Stimulus
  initial begin
    init_transaction = 0;
    #30;
    init_transaction = 1;
    #10;
    init_transaction = 0;
  end

  // Simple AXI slave behavior
  initial begin
    // Default values
    M_AXI_AWREADY = 0;
    M_AXI_WREADY  = 0;
    M_AXI_BVALID  = 0;
    M_AXI_BRESP   = 0;

    M_AXI_ARREADY = 0;
    M_AXI_RVALID  = 0;
    M_AXI_RRESP   = 0;
    M_AXI_RDATA   = 0;

    forever begin
      @(posedge M_AXI_ACLK);

      // Write address handshake
      if (M_AXI_AWVALID)
        M_AXI_AWREADY <= 1;
      else
        M_AXI_AWREADY <= 0;

      // Write data handshake
      if (M_AXI_WVALID)
        M_AXI_WREADY <= 1;
      else
        M_AXI_WREADY <= 0;

      // Write response
      if (M_AXI_WVALID && M_AXI_WREADY) begin
        M_AXI_BVALID <= 1;
        M_AXI_BRESP  <= 0; // OKAY
      end else if (M_AXI_BREADY) begin
        M_AXI_BVALID <= 0;
      end

      // Read address handshake
      if (M_AXI_ARVALID)
        M_AXI_ARREADY <= 1;
      else
        M_AXI_ARREADY <= 0;

      // Read data
      if (M_AXI_ARVALID && M_AXI_ARREADY) begin
        M_AXI_RVALID <= 1;
        M_AXI_RRESP  <= 0;

        // Return expected data based on address
        case (M_AXI_ARADDR)
          32'h30: M_AXI_RDATA <= 32'h03;
          32'hA4: M_AXI_RDATA <= 640;
          32'hA0: M_AXI_RDATA <= 480;
          default: M_AXI_RDATA <= 32'hDEADBEEF;
        endcase
      end else if (M_AXI_RREADY) begin
        M_AXI_RVALID <= 0;
      end
    end
  end

  // Simulation stop
  initial begin
    #500;
    $finish;
  end

endmodule