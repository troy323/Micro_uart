 
`define WORD_LEN 8
`define XTAL_CLK 50000000 
`define BAUD 9600         
`define CW 9        
module uart_top(input clk,rst_n,xmit_h,input [7:0]xmit_data_h,output uart_xmit_h,xmit_doneH,xmit_active,rec_readyH,rec_busy,err,output[7:0]rec_datah);
wire uart_clk;
u_baud baud(clk,rst_n,uart_clk);
u_xmit trans(uart_clk,rst_n,xmit_h,xmit_data_h,uart_xmit_h,xmit_doneH, xmit_active);
u_recv recver(uart_xmit_h,uart_clk,rst_n,rec_readyH,rec_datah,rec_busy,err);
endmodule
 
module u_baud(input clk,rst_n,output reg uart_clk);
  reg [`CW-1:0]cnt;
  localparam clk_div=`XTAL_CLK/(`BAUD*32);
  always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) begin 
      cnt<=0;
      uart_clk<=0;
    end 
    else begin 
      if(cnt==clk_div-1)begin 
        uart_clk<=~uart_clk;
        cnt<=0;
      end 
      else cnt<=cnt+1;
    end
  end
endmodule
 
 
module u_xmit(input uart_clk,rst_n,xmit_h,input [`WORD_LEN-1:0] xmit_data_h,output reg uart_xmit_h,xmit_doneH, xmit_active);
 
  localparam idle= 0,start=1,data=2,stop=3;
  reg [1:0] state;
  // Internal registers
  reg [3:0] ticks;
  reg [2:0] bit_cnt;
  reg [`WORD_LEN-1:0] shift;
 
  always @(posedge uart_clk or negedge rst_n) begin 
    if (!rst_n) begin 
      state<=idle;
      ticks<= 0;
      bit_cnt<= 0;
      shift<= 0;
      uart_xmit_h<= 1'b1; 
      xmit_doneH<= 1'b0;
      xmit_active<= 1'b0;
    end else begin 
      case (state)
        idle: begin 
          xmit_doneH<=1;
          if (xmit_h) begin 
            state<=start;
            ticks<= 0;
            xmit_doneH<=0;
          end 
        end    
        start: begin 
          if (ticks == 15) begin 
            state<=data;
            ticks<= 0;
            bit_cnt<= 0;
            xmit_doneH<=0;
          end else begin 
            ticks<= ticks + 1;
          end 
        end 
        data: begin 
          if (ticks == 15) begin 
            ticks <= 0;
            if (bit_cnt == `WORD_LEN - 1) begin
              state <=stop;
              bit_cnt<=0;
              xmit_doneH<=0;
            end else begin 
              shift<=shift>> 1;
              bit_cnt<= bit_cnt + 1;
              state<=data;
            end
          end else begin 
            ticks<= ticks + 1;
          end 
        end 
        stop:begin 
          if (ticks == 15) begin 
            state<=idle;
            xmit_doneH<=1;
          end else begin 
            ticks<= ticks + 1;
          end 
        end 
      endcase
    end
  end
 
   always@(*) begin 
    case(state) 
     idle:begin 
     shift=xmit_data_h;
      uart_xmit_h=1;
      xmit_active=0;
     end 
     start:begin 
      uart_xmit_h=0;
      xmit_active=1;
     end
     data:begin
      uart_xmit_h=shift[0];
      xmit_active=1; 
     end 
     stop:begin 
      uart_xmit_h=1;
      xmit_active=1;
     end
    endcase 
    end
  endmodule
/// err signal for invalid transaction     

module u_recv(input uart_rec,clk,rst,output reg rec_readyH,output reg [7:0]rec_datah,output reg rec_busy,err);
localparam idle=0,start=1,data=2,stop=3;
reg [1:0]state;
reg [3:0] ticks;
reg [2:0] bit_cnt;
reg sync,sync2;
reg [7:0]shifter;
// flop synchronizer 
always@(posedge clk or negedge rst)begin 
  if(!rst) begin 
   sync<=1;
   sync2<=1;
  end 
  else begin  
   sync<=uart_rec;
   sync2<=sync;
  end 
end 
// state machine 
  always@(posedge clk or negedge rst)begin 
    if(!rst) begin
     ticks<=0;
     bit_cnt<=0;
     rec_busy<=0;
     rec_readyH<=0;
     rec_datah<=0;
     shifter<=0;
     state<=idle;
     err<=0;
    end
    else begin 
     case(state) 
      idle:begin 
       rec_readyH<=1;
       rec_busy<=0;
       if(sync2==0) begin 
        state<=start;
        ticks<=0;
        rec_readyH<=0;
        rec_busy<=1;
       end 
       else state<=idle;
      end 
      start:begin 
       if(ticks==4)begin 
        if(sync2==0) begin 
          state<=data;
          ticks<=0;
          rec_readyH<=0;
          rec_busy<=1;
        end 
        else state<=idle ;
       end
       else ticks<=ticks+1;
      end 
      data:begin 
       if(ticks==15)begin 
        shifter<={sync2,shifter[7:1]};
        ticks<=0;
        if(bit_cnt==`WORD_LEN - 1)begin 
         state<=stop;
         bit_cnt<=0;
         rec_readyH<=0;
         rec_busy<=1;
        end 
        else begin 
         bit_cnt<=bit_cnt+1;
        end  
       end
       else ticks<=ticks+1;
      end 
      stop:begin 
       if(ticks==15) begin 
        state<=idle;
        rec_readyH<=1;
        rec_readyH<=1;
        if(sync2==1) begin 
        rec_datah<=shifter;
        end 
        else if(sync2==0) begin 
         err<=1;
        end 
       end
       else ticks<=ticks+1;
      end 
      endcase 
    end
   end 
//  always@(*) begin
//   case(state) 
//    idle:begin 
//     rec_busy=0;
//     rec_readyH=1;
//    end 
//    start:begin 
//     rec_busy=1;
//     rec_readyH=0;
//    end 
//    data:begin 
//     rec_busy=1;
//     rec_readyH=0;
//    end 
//    stop:begin 
//     if(ticks==15 && sync2==1)begin 
//      rec_readyH=1;
//     end
//     else if(ticks==15 && sync2==0) begin 
//      err=1;
//     end 
//     end 
//    endcase end 
   endmodule 


