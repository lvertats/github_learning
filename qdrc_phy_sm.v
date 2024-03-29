module qdrc_phy_sm(
    clk,
    reset,
    /* qdr_dll_off_n signal */
    qdr_dll_off_n,
    /* PHY status signals */
    phy_rdy,
    cal_fail,
    /* Bit and burst alignment signals */
    bit_align_start,
    bit_align_done,
    bit_align_fail,
    burst_align_start,
    burst_align_done,
    burst_align_fail,
    /* Debug probes */ 
    phy_state_prb
  );
  input  clk, reset;
  output qdr_dll_off_n;
  output phy_rdy, cal_fail;

  output bit_align_start;
  input  bit_align_done,   bit_align_fail;
  output burst_align_start;
  input  burst_align_done, burst_align_fail;

  output [3:0] phy_state_prb;

  reg [3:0] phy_state;
  assign phy_state_prb = phy_state;

  localparam STATE_DLLOFF      = 4'd0; //d0 is 0, 4 bits will store up to d15
  localparam STATE_BIT_ALIGN   = 4'd1;
  localparam STATE_BURST_ALIGN = 4'd2;
  localparam STATE_DONE        = 4'd3;

  reg [18:0] wait_counter;
  /* qdr_dll_off needs to be held high for 2048 cycle after reset is
   * released
   */

  reg bit_align_start, burst_align_start;
  reg cal_fail;

  reg qdr_dll_off_n_reg;
  assign qdr_dll_off_n = qdr_dll_off_n_reg;
  assign phy_rdy       = phy_state == STATE_DONE; // not sure what this means... but it is the only place that phy_rdy is set

  always @(posedge clk) begin
    /* Single Cycle Strobes */
    bit_align_start   <= 1'b0;
    burst_align_start <= 1'b0;

    if (reset) begin
      cal_fail     <= 1'b0;
      wait_counter <= 14'b0; //set to 14?!?! why not 18???  set lowest 14 bits to 0?  leave the rest as they are?
      phy_state    <= STATE_DLLOFF;
      qdr_dll_off_n_reg <= 1'b0; //start with dlls disabled
    end else begin
      case (phy_state)
        STATE_DLLOFF: begin
          if (wait_counter[18] == 1'b1) begin // why look at the 18th spot when only 14 bits long?
            phy_state    <= STATE_BIT_ALIGN;
            bit_align_start <= 1'b1;
          end else begin
            wait_counter <= wait_counter + 1;
          end
          if (wait_counter[17]) //what is the diff between this and the previous if statement other than 17 and 18?  is == needed?
            qdr_dll_off_n_reg <= 1'b1; //enabled
        end
        STATE_BIT_ALIGN: begin
          if (bit_align_done) begin
            if (bit_align_fail) begin
              cal_fail  <= 1'b1;
              phy_state <= STATE_DONE;
            end else begin
              phy_state <= STATE_BURST_ALIGN;
              burst_align_start <= 1'b1;
            end
          end
        end
        STATE_BURST_ALIGN: begin
          if (burst_align_done) begin
            if (burst_align_fail) begin
              cal_fail <= 1'b1;
            end
            phy_state <= STATE_DONE;
          end
        end
        STATE_DONE: begin
        end
      endcase
    end
  end

endmodule
