module apb_slave_design(pclk_i, prst_i, penable_i, pwrite_i, paddr_i, pwdata_i, prdata_o, pready_o, psel_i, pslverr_o);

//APB2 Signal
input wire pclk_i,prst_i;
input wire penable_i,psel_i;
input wire [31:0] paddr_i;
input wire [31:0] pwdata_i;
input wire pwrite_i;
output reg [31:0] prdata_o;
output reg pready_o;
output reg pslverr_o;
reg [31:0] paddr_temp; 
reg pwrite_temp;
reg [31:0] pwdata_temp;
reg violation_err_flag=1'b0;
reg addr_decode_err_flag=1'b0;
reg x_sig_err_flag=1'b0;

//Memory
reg [127:0] memory[127:0];

//FSM
reg [1:0] next_state, current_state;
parameter IDLE=2'b00;
parameter SETUP=2'b01;
parameter ACCESS=2'b10;

always@(posedge pclk_i) begin
  if(prst_i) begin
    next_state <= IDLE;
  end
  else begin
    current_state <= next_state;
  end
end

//APB Operating State
always@(*) begin
  if(prst_i) begin
    pready_o <= 0;
    pslverr_o <= 0;
    prdata_o <= 32'b0;
    for(integer i=0; i<128; i=i+1) begin
      memory[i] <= 128'b0;
    end
  end
  else begin
    pready_o <= 1; //Performance purpose
    case(current_state)
      IDLE: begin
        if(psel_i==1 && penable_i==0) begin
          next_state <= SETUP;
        end
        else begin
          next_state <= IDLE;
          //1 clock should required SETUP to ACCESS
          if(psel_i==1 && penable_i==1) begin
            violation_err_flag <= 1;
          end
        end
      end
      SETUP: begin
        //psel is high -> addr, write, wdata should present.
        paddr_temp <= paddr_i;
        pwrite_temp <= pwrite_i;
        pwdata_temp <= pwdata_i;
        //APB signals can't be 'hx
        if(paddr_i==32'bx || pwrite_i==32'bx || pwdata_i==32'bx) begin
          x_sig_err_flag <= 1;
        end
        if(psel_i==1 && penable_i==1) begin
          next_state <= ACCESS;
        end
      end
      ACCESS: begin
        if(psel_i==0) begin
          next_state <= IDLE;
        end
        if(pready_o==0) begin
          next_state <= ACCESS;
        end
        if(pready_o==1) begin
          next_state <= SETUP;
        end
      end
    endcase
  end
end

always@(*) begin
  if(pwrite_temp) begin
    // Address Decoding error
    if(paddr_temp > 32'h1000_FFFF) begin
      addr_decode_err_flag <= 1;
    end
    else begin
      memory[paddr_temp] <= pwdata_temp;
    end
  end
  else begin
    // Address Decoding error
    if(paddr_temp > 32'h1000_FFFF) begin
      addr_decode_err_flag <= 1;
    end
    else begin
      prdata_o <= memory[paddr_temp];
    end
  end
end

always@(*) begin
  if(addr_decode_err_flag==1) begin
    @(posedge pclk_i)
    addr_decode_err_flag <= 1'b0;
  end
  if(x_sig_err_flag==1) begin
    @(posedge pclk_i)
    x_sig_err_flag <= 1'b0;
  end
  if(addr_decode_err_flag==1) begin
    @(posedge pclk_i)
    violation_err_flag <= 1'b0;
  end
end

always@(*) begin
  pslverr_o <= x_sig_err_flag || addr_decode_err_flag || violation_err_flag;
end

endmodule: apb_slave_design
