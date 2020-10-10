`default_nettype none
module servant
(
 input wire  wb_clk,
 input wire  wb_rst,
 output wire q);

   parameter memfile = "zephyr_hello.hex";
   parameter memsize = 8192;
   parameter reset_strategy = "MINI";
   parameter sim = 0;
   parameter with_csr = 1;

   wire 	timer_irq;

   wire [31:0] 	wb_ibus_adr;
   wire 	wb_ibus_cyc;
   wire [31:0] 	wb_ibus_rdt;
   wire 	wb_ibus_ack;

   wire [31:0] 	wb_dbus_adr;
   wire [31:0] 	wb_dbus_dat;
   wire [3:0] 	wb_dbus_sel;
   wire 	wb_dbus_we;
   wire 	wb_dbus_cyc;
   wire [31:0] 	wb_dbus_rdt;
   wire 	wb_dbus_ack;

   wire [31:0] 	wb_dmem_adr;
   wire [31:0] 	wb_dmem_dat;
   wire [3:0] 	wb_dmem_sel;
   wire 	wb_dmem_we;
   wire 	wb_dmem_cyc;
   wire [31:0] 	wb_dmem_rdt;
   wire 	wb_dmem_ack;

   wire [31:0] 	wb_mem_adr;
   wire [31:0] 	wb_mem_dat;
   wire [3:0] 	wb_mem_sel;
   wire 	wb_mem_we;
   wire 	wb_mem_cyc;
   wire [31:0] 	wb_mem_rdt;
   wire 	wb_mem_ack;

   wire 	wb_gpio_dat;
   wire 	wb_gpio_we;
   wire 	wb_gpio_cyc;
   wire 	wb_gpio_rdt;

   wire [31:0] 	wb_timer_dat;
   wire 	wb_timer_we;
   wire 	wb_timer_cyc;
   wire [31:0] 	wb_timer_rdt;

   wire [6+with_csr:0] waddr;
   wire [rf_width-1:0] wdata;
   wire 	       wen;
   wire [6+with_csr:0] raddr;
   wire [rf_width-1:0] rdata;


   wire [aw-1:0] rf_waddr = ~{{aw-2-5-with_csr{1'b0}},waddr};
   wire [aw-1:0] rf_raddr = ~{{aw-2-5-with_csr{1'b0}},raddr};

   serving_arbiter arbiter
     (.i_wb_cpu_dbus_adr (wb_dmem_adr),
      .i_wb_cpu_dbus_dat (wb_dmem_dat),
      .i_wb_cpu_dbus_sel (wb_dmem_sel),
      .i_wb_cpu_dbus_we  (wb_dmem_we ),
      .i_wb_cpu_dbus_stb (wb_dmem_cyc),
      .o_wb_cpu_dbus_rdt (wb_dmem_rdt),
      .o_wb_cpu_dbus_ack (wb_dmem_ack),

      .i_wb_cpu_ibus_adr (wb_ibus_adr),
      .i_wb_cpu_ibus_stb (wb_ibus_cyc),
      .o_wb_cpu_ibus_rdt (wb_ibus_rdt),
      .o_wb_cpu_ibus_ack (wb_ibus_ack),

      .o_wb_mem_adr (wb_mem_adr),
      .o_wb_mem_dat (wb_mem_dat),
      .o_wb_mem_sel (wb_mem_sel),
      .o_wb_mem_we  (wb_mem_we ),
      .o_wb_mem_stb (wb_mem_cyc),
      .i_wb_mem_rdt (wb_mem_rdt),
      .i_wb_mem_ack (wb_mem_ack));

   servant_mux #(sim) servant_mux
     (
      .i_clk (wb_clk),
      .i_rst (wb_rst & (reset_strategy != "NONE")),
      .i_wb_cpu_adr (wb_dbus_adr),
      .i_wb_cpu_dat (wb_dbus_dat),
      .i_wb_cpu_sel (wb_dbus_sel),
      .i_wb_cpu_we  (wb_dbus_we),
      .i_wb_cpu_cyc (wb_dbus_cyc),
      .o_wb_cpu_rdt (wb_dbus_rdt),
      .o_wb_cpu_ack (wb_dbus_ack),

      .o_wb_mem_adr (wb_dmem_adr),
      .o_wb_mem_dat (wb_dmem_dat),
      .o_wb_mem_sel (wb_dmem_sel),
      .o_wb_mem_we  (wb_dmem_we),
      .o_wb_mem_cyc (wb_dmem_cyc),
      .i_wb_mem_rdt (wb_dmem_rdt),
      .i_wb_mem_ack (wb_dmem_ack),

      .o_wb_gpio_dat (wb_gpio_dat),
      .o_wb_gpio_we  (wb_gpio_we),
      .o_wb_gpio_cyc (wb_gpio_cyc),
      .i_wb_gpio_rdt (wb_gpio_rdt),

      .o_wb_timer_dat (wb_timer_dat),
      .o_wb_timer_we  (wb_timer_we),
      .o_wb_timer_cyc (wb_timer_cyc),
      .i_wb_timer_rdt (wb_timer_rdt));

   generate
      if (with_csr) begin
	 servant_timer
	   #(.WIDTH (32))
	 timer
	   (.i_clk    (wb_clk),
	    .o_irq    (timer_irq),
	    .i_wb_cyc (wb_timer_cyc),
	    .i_wb_we  (wb_timer_we) ,
	    .i_wb_dat (wb_timer_dat),
	    .o_wb_dat (wb_timer_rdt));
      end else begin
	 assign wb_timer_rdt = 32'd0;
	 assign timer_irq = 1'b0;
      end
   endgenerate

   servant_gpio gpio
     (.i_wb_clk (wb_clk),
      .i_wb_dat (wb_gpio_dat),
      .i_wb_we  (wb_gpio_we),
      .i_wb_cyc (wb_gpio_cyc),
      .o_wb_rdt (wb_gpio_rdt),
      .o_gpio   (q));

   localparam regs = 32+with_csr*4;

   localparam rf_width = 8;

   localparam aw = $clog2(memsize);

   serving_ram
     #(.memfile (memfile),
       .depth   (memsize))
   ram
     (// Wishbone interface
      .i_clk (wb_clk),
      .i_waddr  (rf_waddr),
      .i_wdata  (wdata),
      .i_wen    (wen),
      .i_raddr  (rf_raddr),
      .o_rdata  (rdata),
      .i_wb_adr (wb_mem_adr[$clog2(memsize)-1:2]),
      .i_wb_stb (wb_mem_cyc),
      .i_wb_we  (wb_mem_we) ,
      .i_wb_sel (wb_mem_sel),
      .i_wb_dat (wb_mem_dat),
      .o_wb_rdt (wb_mem_rdt),
      .o_wb_ack (wb_mem_ack));

   localparam RF_L2W = $clog2(rf_width);

   wire 		   rf_wreq;
   wire 		   rf_rreq;
   wire [$clog2(regs)-1:0] wreg0;
   wire [$clog2(regs)-1:0] wreg1;
   wire 		   wen0;
   wire 		   wen1;
   wire 		   wdata0;
   wire 		   wdata1;
   wire [$clog2(regs)-1:0] rreg0;
   wire [$clog2(regs)-1:0] rreg1;
   wire 		   rf_ready;
   wire 		   rdata0;
   wire 		   rdata1;


   serv_rf_ram_if
     #(.width    (rf_width),
       .reset_strategy (reset_strategy),
       .csr_regs (with_csr*4))
   rf_ram_if
     (.i_clk    (wb_clk),
      .i_rst    (wb_rst),
      .i_wreq   (rf_wreq),
      .i_rreq   (rf_rreq),
      .o_ready  (rf_ready),
      .i_wreg0  (wreg0),
      .i_wreg1  (wreg1),
      .i_wen0   (wen0),
      .i_wen1   (wen1),
      .i_wdata0 (wdata0),
      .i_wdata1 (wdata1),
      .i_rreg0  (rreg0),
      .i_rreg1  (rreg1),
      .o_rdata0 (rdata0),
      .o_rdata1 (rdata1),
      .o_waddr  (waddr),
      .o_wdata  (wdata),
      .o_wen    (wen),
      .o_raddr  (raddr),
      .i_rdata  (rdata));

   serv_top
     #(.RESET_PC (32'h0000_0000),
       .RESET_STRATEGY (reset_strategy),
       .WITH_CSR (with_csr))
   cpu
     (
      .clk      (wb_clk),
      .i_rst    (wb_rst),
      .i_timer_irq  (timer_irq),
      //RF IF
      .o_rf_rreq   (rf_rreq),
      .o_rf_wreq   (rf_wreq),
      .i_rf_ready  (rf_ready),
      .o_wreg0     (wreg0),
      .o_wreg1     (wreg1),
      .o_wen0      (wen0),
      .o_wen1      (wen1),
      .o_wdata0    (wdata0),
      .o_wdata1    (wdata1),
      .o_rreg0     (rreg0),
      .o_rreg1     (rreg1),
      .i_rdata0    (rdata0),
      .i_rdata1    (rdata1),

      .o_ibus_adr   (wb_ibus_adr),
      .o_ibus_cyc   (wb_ibus_cyc),
      .i_ibus_rdt   (wb_ibus_rdt),
      .i_ibus_ack   (wb_ibus_ack),

      .o_dbus_adr   (wb_dbus_adr),
      .o_dbus_dat   (wb_dbus_dat),
      .o_dbus_sel   (wb_dbus_sel),
      .o_dbus_we    (wb_dbus_we),
      .o_dbus_cyc   (wb_dbus_cyc),
      .i_dbus_rdt   (wb_dbus_rdt),
      .i_dbus_ack   (wb_dbus_ack));

endmodule
