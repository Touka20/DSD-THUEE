`timescale 1ns/1ps
module pe_array_tree #(
    parameter typical_width = 64, //number of addends of the trees
	parameter MAC_NUM    =   10,  // number of MAC units
	parameter BW_ACT     =   8,  // bit length of activation
    parameter BW_WET     =   8,  // bit length of weight
    parameter BW_ACCU    =   32    // bit length of accu result
)(
    input        clk,
    input        reset_n,
    // // control signal
    input        PE_mac_enable,      // high active //macʹ���ź�
    input        PE_clear_acc,//
    // data signal 
    input   signed     [BW_ACT-1:0]    PE_act_in [MAC_NUM-1:0][typical_width-1:0] ,         // input activation
    input   signed     [BW_WET-1:0]    PE_wet_in [typical_width-1:0],         // input weight
    input              [7:0]           PE_res_shift_num,
    output  reg signed [BW_ACT-1:0]    PE_result_out [MAC_NUM-1:0]     // output result   
);

    reg signed [BW_ACT-1:0]    PE_act_in_reg [MAC_NUM-1:0][typical_width-1:0] ;      // input buffer
    reg signed [BW_WET-1:0]    PE_wet_in_reg [typical_width-1:0];      // weight buffer
    reg signed [BW_ACCU-1:0]   PE_result_out_reg [MAC_NUM-1:0];  

    genvar i,k;
    generate
        for(i=0;i<MAC_NUM;i=i+1)begin:ACCU_para
        adder_tree#(.typical_width(typical_width),
        .BW_ACCU(BW_ACCU),.BW_ACT(BW_ACT),.BW_WET(BW_WET)
        ) woc(.clk(clk),.reset(reset_n),.enable(PE_mac_enable),.PE_clear_acc(PE_clear_acc),
        .act(PE_act_in_reg[i][typical_width-1:0]),.wet(PE_wet_in_reg),
       .res(PE_result_out_reg[i]));
        wire signed [BW_ACCU-1:0]PE_result_shift_temp;
                assign PE_result_shift_temp = PE_result_out_reg[i] >>> PE_res_shift_num;//
                always @(posedge clk or negedge reset_n) begin
                        if(~reset_n) begin
                            PE_result_out[i] <= '0;
                        end
                        else if(PE_result_shift_temp>127) begin
                            PE_result_out[i] <= 127;
                        end
                        else if(PE_result_shift_temp<-128) begin
                            PE_result_out[i] <= -128;
                        end
                        else begin
                            PE_result_out[i] <= PE_result_shift_temp[BW_ACT-1:0];  //��ȡ��λ
                        end
                end

                for(k=0;k<typical_width;k=k+1)begin:weight_para                
                     always @(posedge clk or negedge reset_n) begin//weight data signal
                        if(~reset_n) begin // 
                            PE_wet_in_reg[k]<='0;
                            PE_act_in_reg[i][k] <= '0;
                        end
                        else begin
                            PE_wet_in_reg[k] <= PE_wet_in[k];
                            PE_act_in_reg[i][k] <= PE_act_in[i][k]; 
                        end
                     end
                end                      
        end      
    endgenerate
    
endmodule