module qdrc_infrastructure(
    /* general signals */
    clk0,
    clk180,
    clk270,
    reset0,
    reset180,
    reset270,
    /* external signals */
    qdr_d,
    qdr_q,
    qdr_sa,
    qdr_w_n,
    qdr_r_n,
    qdr_dll_off_n,
    qdr_bw_n,
    qdr_cq,
    qdr_cq_n,
    qdr_k,
    qdr_k_n,
    qdr_qvld,
    /* phy->external signals */
    qdr_d_rise,
    qdr_d_fall,
    qdr_q_rise,
    qdr_q_fall,
    qdr_bw_n_rise,
    qdr_bw_n_fall,
    qdr_sa_buf,
    qdr_w_n_buf,
    qdr_r_n_buf,
    qdr_dll_off_n_buf,
    qdr_cq_buf,
    qdr_cq_n_buf,
    qdr_qvld_buf,
    /* phy training signals */
    dly_clk,
    dly_inc_dec_n,
    dly_en,
    dly_rst       
  );
  parameter DATA_WIDTH     = 36;
  parameter BW_WIDTH       = 4;
  parameter ADDR_WIDTH     = 21; //again overrides ADDR_WIDTH to 21... why always multiply defined?  why does each level need default values?
  parameter CLK_FREQ       = 200;

  input clk0,   clk180,   clk270;
  input reset0, reset180, reset270;

  output [DATA_WIDTH - 1:0] qdr_d;
  output   [BW_WIDTH - 1:0] qdr_bw_n;
  input  [DATA_WIDTH - 1:0] qdr_q;
  output [ADDR_WIDTH - 1:0] qdr_sa;
  output qdr_w_n;
  output qdr_r_n;
  output qdr_dll_off_n;
  output qdr_k, qdr_k_n;
  input  qdr_cq, qdr_cq_n;
  input  qdr_qvld;
  
  input  [DATA_WIDTH - 1:0] qdr_d_rise;
  input  [DATA_WIDTH - 1:0] qdr_d_fall;
  output [DATA_WIDTH - 1:0] qdr_q_rise; //read 72 bits stored at rising edge
  output [DATA_WIDTH - 1:0] qdr_q_fall; //
  input    [BW_WIDTH - 1:0] qdr_bw_n_rise;
  input    [BW_WIDTH - 1:0] qdr_bw_n_fall;
  input  [ADDR_WIDTH - 1:0] qdr_sa_buf; 
  input  qdr_w_n_buf, qdr_r_n_buf;
  input  qdr_dll_off_n_buf;
  output qdr_cq_buf, qdr_cq_n_buf;
  output qdr_qvld_buf;

  input  dly_clk;
  input  [DATA_WIDTH - 1:0] dly_inc_dec_n;
  input  [DATA_WIDTH - 1:0] dly_en;
  input  [DATA_WIDTH - 1:0] dly_rst;       

  /******************* QDR_K and QDR_K_N ********************
   * The clock is generated by an ODDR. This is done
   * to so the latency introduced by the ODDR on the data
   * line is introduced into the clock generation.
   * The clock uses clk0 while all other signals use clk270.
   */

  ODDR #( //reading about this on xilinx, same edge means data is presented on d1 and d2, but both are sampled on the rising edge of clock0... one gets internally delayed in a register, and then the data comes out on every edge of Q
//however, d1 and d2 are simply set to 1 and 0, respectively, so on each edge of q, we get transitions 1 0 1 0 1 0, creating clock signal k from clk0
// is there any delay here? will both this and the data lines be guaranteed the same delay?
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_k (
    .Q  (qdr_k),
    .C  (clk0),
    .CE (1'b1),
    .D1 (1'b1), //Rising Edge
    .D2 (1'b0), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

//should get same performance if "OPPOSITE_EDGE" is used
  /* same as qdr_k -> just inverted */
  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_k_n (
    .Q  (qdr_k_n),
    .C  (clk0),
    .CE (1'b1),
    .D1 (1'b0), //Rising Edge
    .D2 (1'b1), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

  /******************* SDR Control Signals ********************
   *
   */

  reg [ADDR_WIDTH - 1:0] qdr_sa_reg;
  reg qdr_w_n_reg;
  reg qdr_r_n_reg;

  /* This signals are all sliced so use the register in the slice */

  always @(posedge clk0) begin //get ready to set values in registers, set on next pos edge?  start on one pos edge, set on next pos edge?
    qdr_sa_reg        <= qdr_sa_buf;
    qdr_w_n_reg       <= qdr_w_n_buf;
    qdr_r_n_reg       <= qdr_r_n_buf;
  end

  reg [ADDR_WIDTH - 1:0] qdr_sa_reg0; // reg0 version identical?
  reg qdr_w_n_reg0;
  reg qdr_r_n_reg0;

  always @(posedge clk180) begin 
  /* Add delay to ease timing */
    qdr_sa_reg0        <= qdr_sa_reg;
    qdr_w_n_reg0       <= qdr_w_n_reg;
    qdr_r_n_reg0       <= qdr_r_n_reg;
  end

  reg [ADDR_WIDTH - 1:0] qdr_sa_iob; //io buffer?
  reg qdr_w_n_iob;
  reg qdr_r_n_iob;
  reg qdr_dll_off_n_iob;
  //synthesis attribute IOB of qdr_sa_iob        is "TRUE"
  //synthesis attribute IOB of qdr_w_n_iob       is "TRUE"
  //synthesis attribute IOB of qdr_r_n_iob       is "TRUE"
  //synthesis attribute IOB of qdr_dll_off_n_iob is "TRUE"


  always @(posedge clk180) begin // add delay... meaning clk180 delayed from clk0 so use that instead?
  /* Add delay to ease timing */
    qdr_sa_iob        <= qdr_sa_reg0;
    qdr_w_n_iob       <= qdr_w_n_reg0;
    qdr_r_n_iob       <= qdr_r_n_reg0;
  end
  reg qdr_dll_off_n_reg;
  always @(posedge clk0) begin
    qdr_dll_off_n_reg <= qdr_dll_off_n_buf;
    qdr_dll_off_n_iob <= qdr_dll_off_n_reg;
  end

  OBUF #( //OBUF sends data up to top level and to a pin directly.
    .IOSTANDARD ("HSTL_I") // high speed transceiver logic (HSTL)
  ) OBUF_addr[ADDR_WIDTH - 1:0]  
  (
    .I (qdr_sa_iob),
    .O (qdr_sa)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_w_n(
    .I (qdr_w_n_iob),
    .O (qdr_w_n)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_r_n(
    .I (qdr_r_n_iob),
    .O (qdr_r_n)
  );

  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) OBUF_dll_off_n(
    .I (qdr_dll_off_n_iob),
    .O (qdr_dll_off_n)
  );


  /******************* DDR Data Outputs ********************
   *
   */

  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg0;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg0;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg0;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg0;

  always @(posedge clk0) begin
  /* Delay the write data by one cycle (qdr protocol,
   * requires datat to lag control*/
    qdr_d_rise_reg0     <= qdr_d_rise;
    qdr_d_fall_reg0     <= qdr_d_fall;
    qdr_bw_n_rise_reg0  <= qdr_bw_n_rise;
    qdr_bw_n_fall_reg0  <= qdr_bw_n_fall;
  end

  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg1;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg1;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg1;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg1;

  always @(posedge clk0) begin
  /* Delay to match the extra cycle on control lines 
   * due to extra iob delay route*/
    qdr_d_rise_reg1     <= qdr_d_rise_reg0;
    qdr_d_fall_reg1     <= qdr_d_fall_reg0;
    qdr_bw_n_rise_reg1  <= qdr_bw_n_rise_reg0;
    qdr_bw_n_fall_reg1  <= qdr_bw_n_fall_reg0;
  end


  reg [DATA_WIDTH - 1:0] qdr_d_rise_reg;
  reg [DATA_WIDTH - 1:0] qdr_d_fall_reg;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_rise_reg;
  reg   [BW_WIDTH - 1:0] qdr_bw_n_fall_reg;

  always @(posedge clk270) begin
  /* Sample DDR signals onto clk270 domain.
   * The 270 clock is used to let the data lead the clock by
   * 90 degrees behind the clock. The signals are registered
   * to ease timing requirements.
   */
    qdr_d_rise_reg     <= qdr_d_rise_reg1;
    qdr_d_fall_reg     <= qdr_d_fall_reg1;
    qdr_bw_n_rise_reg  <= qdr_bw_n_rise_reg1;
    qdr_bw_n_fall_reg  <= qdr_bw_n_fall_reg1;
  end
  
  wire [DATA_WIDTH - 1:0] qdr_d_obuf;
  OBUF #(
    .IOSTANDARD ("HSTL_I")
  ) obuf_qdrd [DATA_WIDTH - 1:0] (
    .O (qdr_d),
    .I (qdr_d_obuf)
  );

  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_d [DATA_WIDTH - 1:0] (
    .Q  (qdr_d_obuf),
    .C  (clk270),
    .CE (1'b1),
    .D1 (qdr_d_rise_reg), //Rising Edge
    .D2 (qdr_d_fall_reg), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );

/*
  ODDR #(
    .DDR_CLK_EDGE ("SAME_EDGE"),
    .INIT         (1'b1),
    .SRTYPE       ("SYNC")
  ) ODDR_qdr_bw_n [BW_WIDTH - 1:0] (
    .Q  (qdr_bw_n),
    .C  (clk270),
    .CE (1'b1),
    .D1 (qdr_bw_n_rise_reg), //Rising Edge
    .D2 (qdr_bw_n_fall_reg), //Falling Edge
    .R  (1'b0),
    .S  (1'b0)
  );
*/

//assign qdr_bw_n = {BW_WIDTH{1'b0}};


  /******************* DDR Data Inputs ********************
   * IODELAY for training
   */
 
  wire [DATA_WIDTH - 1:0] qdr_q_ibuf;
  wire [DATA_WIDTH - 1:0] qdr_q_iodelay;

  IBUF #(
    .IOSTANDARD ("HSTL_I_DCI")
  ) ibuf_qdrq [DATA_WIDTH - 1:0](
    .I (qdr_q),
    .O (qdr_q_ibuf)
  );

  IODELAY #(
    .DELAY_SRC        ("I"),
    .IDELAY_TYPE      ("VARIABLE"),
    .REFCLK_FREQUENCY (200.0)
  ) IODELAY_qdrq [DATA_WIDTH - 1:0] (
    .C       (dly_clk),
    .CE      (dly_en),
    .DATAIN  (1'b0),
    .IDATAIN (qdr_q_ibuf),
    .INC     (dly_inc_dec_n),
    .ODATAIN (),
    .RST     (dly_rst),
    .T       (1'b0),
    .DATAOUT (qdr_q_iodelay)
  );

  wire [DATA_WIDTH - 1:0] qdr_q_rise_int;
  wire [DATA_WIDTH - 1:0] qdr_q_fall_int;

  wire qdr_cq_bufg;

  IDDR #(
    .DDR_CLK_EDGE ("SAME_EDGE_PIPELINED"),
    .INIT_Q1 (1'b0),
    .INIT_Q2 (1'b0),
    .SRTYPE ("SYNC")
  ) IDDR_qdrq [DATA_WIDTH - 1:0] (
    .C  (clk0),
    .CE (1'b1),
    .D  (qdr_q_iodelay),
    .R  (1'b0),
    .S  (1'b0),
    .Q1 (qdr_q_rise_int),
    .Q2 (qdr_q_fall_int)
  );

  assign qdr_q_rise = qdr_q_rise_int;
  assign qdr_q_fall = qdr_q_fall_int;

  /******************* SDR Inputs ********************
   * IODELAY for training
   */

/*
  IBUF ibuf_qdr_qvld(
    .I (qdr_qvld),
    .O (qdr_qvld_buf)
  );

  IBUF ibuf_qdr_cq[1:0](
    .I ({qdr_cq,     qdr_cq_n}),
    .O ({qdr_cq_buf, qdr_cq_n_buf})
  );

  BUFR foo_bufg(
    .I(qdr_cq_buf), 
    .O(qdr_cq_bufg),
    .CE(1'b0),
    .CLR(1'b0)
    
  );
*/
// moo attribute HU_SET of qdr_w_n_reg  is SET_qdr_w_n
// moo attribute HU_SET of qdr_w_n_reg0 is SET_qdr_w_n
// moo attribute RLOC   of qdr_w_n_reg  is X0Y0
// moo attribute RLOC   of qdr_w_n_reg0 is X1Y0
// moo attribute HU_SET of qdr_r_n_reg  is SET_qdr_r_n
// moo attribute HU_SET of qdr_r_n_reg0 is SET_qdr_r_n
// moo attribute RLOC   of qdr_r_n_reg  is X0Y0
// moo attribute RLOC   of qdr_r_n_reg0 is X1Y0
// moo attribute HU_SET of qdr_sa_reg[0]  is SET_qdr_sa0
// moo attribute HU_SET of qdr_sa_reg0[0] is SET_qdr_sa0
// moo attribute RLOC   of qdr_sa_reg[0]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[0] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[1]  is SET_qdr_sa1
// moo attribute HU_SET of qdr_sa_reg0[1] is SET_qdr_sa1
// moo attribute RLOC   of qdr_sa_reg[1]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[1] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[2]  is SET_qdr_sa2
// moo attribute HU_SET of qdr_sa_reg0[2] is SET_qdr_sa2
// moo attribute RLOC   of qdr_sa_reg[2]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[2] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[3]  is SET_qdr_sa3
// moo attribute HU_SET of qdr_sa_reg0[3] is SET_qdr_sa3
// moo attribute RLOC   of qdr_sa_reg[3]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[3] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[4]  is SET_qdr_sa4
// moo attribute HU_SET of qdr_sa_reg0[4] is SET_qdr_sa4
// moo attribute RLOC   of qdr_sa_reg[4]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[4] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[5]  is SET_qdr_sa5
// moo attribute HU_SET of qdr_sa_reg0[5] is SET_qdr_sa5
// moo attribute RLOC   of qdr_sa_reg[5]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[5] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[6]  is SET_qdr_sa6
// moo attribute HU_SET of qdr_sa_reg0[6] is SET_qdr_sa6
// moo attribute RLOC   of qdr_sa_reg[6]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[6] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[7]  is SET_qdr_sa7
// moo attribute HU_SET of qdr_sa_reg0[7] is SET_qdr_sa7
// moo attribute RLOC   of qdr_sa_reg[7]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[7] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[8]  is SET_qdr_sa8
// moo attribute HU_SET of qdr_sa_reg0[8] is SET_qdr_sa8
// moo attribute RLOC   of qdr_sa_reg[8]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[8] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[9]  is SET_qdr_sa9
// moo attribute HU_SET of qdr_sa_reg0[9] is SET_qdr_sa9
// moo attribute RLOC   of qdr_sa_reg[9]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[9] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[10]  is SET_qdr_sa10
// moo attribute HU_SET of qdr_sa_reg0[10] is SET_qdr_sa10
// moo attribute RLOC   of qdr_sa_reg[10]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[10] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[11]  is SET_qdr_sa11
// moo attribute HU_SET of qdr_sa_reg0[11] is SET_qdr_sa11
// moo attribute RLOC   of qdr_sa_reg[11]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[11] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[12]  is SET_qdr_sa12
// moo attribute HU_SET of qdr_sa_reg0[12] is SET_qdr_sa12
// moo attribute RLOC   of qdr_sa_reg[12]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[12] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[13]  is SET_qdr_sa13
// moo attribute HU_SET of qdr_sa_reg0[13] is SET_qdr_sa13
// moo attribute RLOC   of qdr_sa_reg[13]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[13] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[14]  is SET_qdr_sa14
// moo attribute HU_SET of qdr_sa_reg0[14] is SET_qdr_sa14
// moo attribute RLOC   of qdr_sa_reg[14]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[14] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[15]  is SET_qdr_sa15
// moo attribute HU_SET of qdr_sa_reg0[15] is SET_qdr_sa15
// moo attribute RLOC   of qdr_sa_reg[15]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[15] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[16]  is SET_qdr_sa16
// moo attribute HU_SET of qdr_sa_reg0[16] is SET_qdr_sa16
// moo attribute RLOC   of qdr_sa_reg[16]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[16] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[17]  is SET_qdr_sa17
// moo attribute HU_SET of qdr_sa_reg0[17] is SET_qdr_sa17
// moo attribute RLOC   of qdr_sa_reg[17]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[17] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[18]  is SET_qdr_sa18
// moo attribute HU_SET of qdr_sa_reg0[18] is SET_qdr_sa18
// moo attribute RLOC   of qdr_sa_reg[18]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[18] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[19]  is SET_qdr_sa19
// moo attribute HU_SET of qdr_sa_reg0[19] is SET_qdr_sa19
// moo attribute RLOC   of qdr_sa_reg[19]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[19] is X1Y0
// moo attribute HU_SET of qdr_sa_reg[20]  is SET_qdr_sa20
// moo attribute HU_SET of qdr_sa_reg0[20] is SET_qdr_sa20
// moo attribute RLOC   of qdr_sa_reg[20]  is X0Y0
// moo attribute RLOC   of qdr_sa_reg0[20] is X1Y0


endmodule
