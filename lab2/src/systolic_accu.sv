`timescale 1ns / 1ps

module systolic_accu#(
parameter len = 10,
parameter width = 10,
parameter BW_ACT =8,
parameter BW_WET = 8,
parameter BW_ACCU =32
)(
input clk,
input reset,
input signed [BW_WET-1:0]wet[len-1:0][width-1:0],
input signed [BW_ACT-1:0]act_in[len-1:0],
    input        PE_mac_enable,      // high active //macʹ���ź�
    input        PE_clear_acc,//
    input              [7:0]           PE_res_shift_num,
output reg signed[BW_ACCU-1:0]out[width-1:0]
    );
reg signed [BW_ACT-1:0]IA_reg[len-1:0][width-1:0];//�Ĵ������ֵ
reg signed [BW_ACCU-1:0]OA_reg[len-1:0][width-1:0];

genvar i,j;
generate
for(j=0;j<width;j=j+1)begin:line//������
    assign out[j]=OA_reg[len-1][j];
    for(i=0;i<len;i=i+1)begin:line2
        always@(posedge clk or negedge reset)begin
            if(~reset)begin
                OA_reg[i][j]<='0;
                IA_reg[i][j]<='0;
            end
            else if(PE_clear_acc) begin
                OA_reg[i][j]<='0;
                IA_reg[i][j]<='0;            
            end             
            else begin
            if(i==0)
                OA_reg[i][j]<=IA_reg[i][j]*wet[i][j];
            else
                OA_reg[i][j]<=OA_reg[i-1][j]+IA_reg[i][j]*wet[i][j];
            if(j==0)
                IA_reg[i][j]<=act_in[i];
            else
                IA_reg[i][j]<=IA_reg[i][j-1];
            end          
        end
    end
end
endgenerate

endmodule
