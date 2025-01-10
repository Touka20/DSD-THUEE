`timescale 1ns / 1ps
module adder_tree#(
    parameter typical_width = 64, //number of addends of the trees
	parameter BW_ACT     =   8,  // bit length of activation
    parameter BW_WET     =   8,  // bit length of weight
    parameter BW_ACCU    =   32    // bit length of accu result
    )(
input clk,
input signed[BW_ACT-1:0] act[typical_width-1:0],
input signed[BW_WET-1:0] wet[typical_width-1:0],
input reset,
input enable,
input  PE_clear_acc,
output reg signed[BW_ACCU-1:0]res
    );
reg PE_clear_acc_reg;
wire signed[BW_ACCU-1:0] midres[2*typical_width-2:0];

genvar i;
generate
    for(i=0;i<typical_width;i=i+1)begin:first_layer
        assign midres[i+typical_width-1]=act[i]*wet[i];
    end
endgenerate
    
genvar k;
generate
    for (k=0;k<typical_width-1;k=k+1)begin:other_layers
        assign midres[k]=midres[(k<<1)+1]+midres[(k<<1)+2];
    end
endgenerate

always @(posedge clk or negedge reset) begin//control signal
    if(~reset) begin 
        PE_clear_acc_reg <= '0;
    end
    else begin
        PE_clear_acc_reg <= PE_clear_acc;
    end
end

always@(posedge clk or negedge reset)begin
    if(~reset)begin
        res<='0;
    end
    else if(PE_clear_acc_reg)
        res <= '0;
    else if(enable)begin
        res<= res + midres[0];
    end

                        

end
endmodule
//generate

