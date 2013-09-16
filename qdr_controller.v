module qdr_controller (  // a module declares all the things, then describes them after with "parameter" "input" "output" "inout" and these are used to talk to other modules
    /* QDR Infrastructure */
    clk0,
    clk180, /*these are different clocks with different delays in phase*/
    clk270, /* looks like 0, 180 (so clock0 NOT, and 270, a -90 phase diff */
    div_clk, //????? not sure what div_clk is ....
    reset, //release when clock and delay elements are stable
    idelay_rdy, // ??????????????not sure what this is
    /* Physical QDR Signals */
    qdr_d, // data port, 36 bits
    qdr_q, // read port, data output, 36 bits
    qdr_sa, // ???
    qdr_w_n, //write_not
    qdr_r_n, //read_not, QDR pins for write/read are active low... could this be inverting?
    qdr_dll_off_n, //???  noticed that DOFF set will make QDRII+ like QDRI, turn off PLL, related?
    qdr_bw_n, //???
    qdr_cq, // echo clock of k --- not used in roach2, no?  no pinout to feed back to fpga?
    qdr_cq_n, // echo clock of k NOT -- same as above
    qdr_k, // clocks from the FPGA
    qdr_k_n, // clocks from the FPGA
    qdr_qvld, // data read valid, takes 2.5 clock latency to get read data
    /* QDR PHY ready */
    phy_rdy, cal_fail, // these are the state machine stuff... search for these terms to find calibration
    /* State debug probes */
    bit_align_state_prb,
    bit_train_state_prb,
    bit_train_error_prb,
    phy_state_prb,
    /* QDR read interface */ //read AND write interface?  are these the user parameters in the sim yellow block?
    usr_rd_strb, //??? read strb
    usr_wr_strb, //???
    usr_addr, // address, shared pin for read/write

    usr_rd_data, //data line for read --> becomes q?
    usr_rd_dvld, //read valid, becomes qvld?

    usr_wr_data, //write data line, becomes ->d?
    usr_wr_be /* 'byte' enable */ //perhaps same as bw above
  ); //end of module
  parameter DATA_WIDTH   = 36; //yep
  parameter BW_WIDTH     = 4; //byte write? only 4... byte enable
  parameter ADDR_WIDTH   = 22; // only 19 for our chip... right?
  parameter BURST_LENGTH = 4; // yep
  parameter CLK_FREQ     = 200; // 200 is the internal QDR clock freq...

  input clk0, clk180, clk270, div_clk; //so these come in from perhaps the pins, this is the highest level
  input reset;
  input idelay_rdy; //again, from the FPGA side, this goes into some function that eventually produces one of the outputs here
// I expect inputs to be from the FPGA, and outputs to be ready to go into the QDR pins...
  output [DATA_WIDTH - 1:0] qdr_d; //out of this module will come qdr_d
  input  [DATA_WIDTH - 1:0] qdr_q; 
  output [ADDR_WIDTH - 1:0] qdr_sa; //static address... i see.
  output qdr_w_n;
  output qdr_r_n;
  output qdr_dll_off_n; //must be DOFF NOT
  output   [BW_WIDTH - 1:0] qdr_bw_n; // NOT used
  input  qdr_cq; //take this in, from the QDR chip
  input  qdr_cq_n; //take this in, from the QDR chip, but not get used perhaps?
  output qdr_k; //take clk0 clk180, clk270 in from FPGA, transform into k, NOT k, etc
  output qdr_k_n;
  input  qdr_qvld; //take in from QDR

  output phy_rdy; //output from this calculation to FPGA
  output cal_fail; //output from controller to FPGA

  input  usr_rd_strb;
  input  usr_wr_strb;
  input    [ADDR_WIDTH - 1:0] usr_addr;

  output [2*DATA_WIDTH - 1:0] usr_rd_data; //take something from QDR and put out to FPGA this 72 bit number
  output usr_rd_dvld;

  input  [2*DATA_WIDTH - 1:0] usr_wr_data; //take something from FPGA, the data to write, and its 72 bits
  input    [2*BW_WIDTH - 1:0] usr_wr_be; //write enable as 8 bits
  
  output [3:0] 	      bit_align_state_prb; //4 bit number, 0 to 15
  output [3:0] 	      bit_train_state_prb;
  output [3:0] 	      bit_train_error_prb;
  output [3:0] 	      phy_state_prb;

  wire qdr_rst; //1 bit by default, can hold value wire a,b,y assign y = a&b
  
  assign qdr_rst = (idelay_rdy == 1'b0 || reset == 1'b1) ? 1'b1 : 1'b0; //find out later
  
  reg [71:0] usr_wr_data_i; //doesnt use variable for 2*DATA_WIDTH -1
  
  always @(posedge clk0) begin
    if (qdr_rst == 1'b1) begin // if the reset (bool) is 1
      usr_wr_data_i <= {8'b0,64'h_abcd_ef12_3456_7890};//72 bit number, assignment? // non-blocking assignment, eval immediately and assign at end of time step 
    end else begin
      //usr_wr_data_i <= ~usr_wr_data_i;
      usr_wr_data_i <= {8'b0,64'h_abcd_ef12_3456_7890}; // 72 bit number, same operation as above? 00000000 0100 0101 0110 0111 1000 1001 1010 1011 1100 1101 1110 1111 0001 0010 0011 0100 0101 0110 0111 0000
    end
  end

// this piece of code does identical things regardless of qdr_rst... perhaps the comment was the original?  at positive clock0, check qdr_rst, if true set usr_wr_data_i to sequence, if false set usr_wr_data_i to binary opposite?!?!  is that what tilde means?
  
//now inside module, define a class? an instance of another module called qdrc_top?  
  
  qdrc_top #(
    .DATA_WIDTH   (DATA_WIDTH  ),
    .BW_WIDTH     (BW_WIDTH    ),
    .ADDR_WIDTH   (ADDR_WIDTH  ), //called here with 22 bits
    .BURST_LENGTH (BURST_LENGTH),
    .CLK_FREQ     (CLK_FREQ    )
  ) qdrc_top_inst (
    .clk0    (clk0),
    .clk180  (clk180),
    .clk270  (clk270),
    .div_clk (div_clk),
    .reset   (qdr_rst),

    .phy_rdy  (phy_rdy),
    .cal_fail (cal_fail),

    .bit_align_state_prb (bit_align_state_prb),
    .bit_train_state_prb (bit_train_state_prb),
    .bit_train_error_prb (bit_train_error_prb),
    .phy_state_prb       (phy_state_prb),

    .qdr_d         (qdr_d),
    .qdr_q         (qdr_q),
    .qdr_sa        (qdr_sa),
    .qdr_w_n       (qdr_w_n),
    .qdr_r_n       (qdr_r_n),
    .qdr_bw_n      (qdr_bw_n),
    .qdr_cq        (qdr_cq),
    .qdr_cq_n      (qdr_cq_n),
    .qdr_k         (qdr_k),
    .qdr_k_n       (qdr_k_n),
    .qdr_qvld      (qdr_qvld),
    .qdr_dll_off_n (qdr_dll_off_n),

    .usr_rd_strb (usr_rd_strb),
    .usr_wr_strb (usr_wr_strb),
    .usr_addr    (usr_addr),
    .usr_rd_data (usr_rd_data),
    .usr_rd_dvld (usr_rd_dvld),
    .usr_wr_data (usr_wr_data[2*DATA_WIDTH - 1:0]),
    .usr_wr_be   (usr_wr_be)
  );
  
endmodule
