`timescale 1ns/1ps
`define CLK_PERIOD  10 //100MHz T=10ns

module tb_pe_array_tree; // test bench

	parameter MAC_NUM    =   10;  // number of multiply-accumulation units
	parameter BW_ACT     =   8;  // bit length of activation
    parameter BW_WET     =   8;  // bit length of weight
    parameter BW_ACCU    =   32;    // bit length of accu result  

    parameter IA_H = 100;
    parameter IA_W = 150;
    parameter Weight_H = 150;
    parameter Weight_W = 16; 
    parameter OA_H = 100;
    parameter OA_W = 16;
    parameter typical_width=8;

    reg clk;
    reg reset_n;
    reg PE_mac_enable;
    reg PE_clear_acc;

    reg signed [BW_ACT-1:0]    PE_act_in [MAC_NUM-1:0][typical_width-1:0];         // input activation
    reg signed [BW_WET-1:0]    PE_wet_in[typical_width-1:0];         // input weight
    reg  [7:0]           PE_res_shift_num;
    wire signed [BW_ACT-1:0]    PE_result_out [MAC_NUM-1:0];    // output result   

    reg signed [BW_ACT-1:0]Input_activation_main_memory[IA_H-1:0][IA_W-1:0]; // main memory (DRAM)
    reg signed [BW_ACT-1:0]Weight_main_memory[Weight_H-1:0][Weight_W-1:0];
    reg signed [BW_ACT-1:0]Output_activation_main_memory[OA_H-1:0][OA_W-1:0];
    reg signed [BW_ACT-1:0]reference_output[OA_H-1:0][OA_W-1:0];//What of it?

    pe_array_tree #(
        .typical_width(typical_width),
        .MAC_NUM(MAC_NUM),
        .BW_ACT(BW_ACT),
        .BW_WET(BW_WET),
        .BW_ACCU(BW_ACCU)
    )u_pe_array(
        .clk(clk),
        .reset_n(reset_n),
        .PE_mac_enable(PE_mac_enable),
        .PE_clear_acc(PE_clear_acc),
        .PE_act_in(PE_act_in),
        .PE_wet_in(PE_wet_in),
        .PE_res_shift_num(PE_res_shift_num),
        .PE_result_out(PE_result_out)
    );

    initial begin
        clk = 0;
        reset_n = 1;
        PE_res_shift_num = 8;
        PE_clear_acc = 0;
        for (integer k=0;k<typical_width;k=k+1)begin
            PE_wet_in[k] <= '0;
            for(integer n=0;n<MAC_NUM;n=n+1) begin
                PE_act_in[n][k] <= '0;//���ﲻ��generate��
            end
        end
        
        forever begin
            #(`CLK_PERIOD/2) clk = ~clk; //ģ��ʱ�Ӳ���
        end
    end
    integer wrong_num=0; // 
    initial begin
        @(negedge clk); 
        reset_n = 0; //

        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//input_act_bin.txt", Input_activation_main_memory);
        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//weight_bin.txt", Weight_main_memory);
        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//reference_output_bin.txt", reference_output);
        
        // loop nest
        @(negedge clk);
        reset_n = 1;
        
        PE_mac_enable = 1;
        for(integer m=0;m<OA_W;m=m+1) begin
            for(integer j=0;j<IA_H/MAC_NUM;j=j+1) begin
                for(integer i=0;i<IA_W/typical_width+1;i=i+1) begin
                    @(negedge clk) begin
                        if(i==0) begin
                            PE_clear_acc <= 0; 
                        end
                       
                        for(integer q=0;q<typical_width;q=q+1)begin
                        if(i*typical_width+q>Weight_H-1)
                            PE_wet_in[q]<='0;
                        else
                            PE_wet_in[q]<=Weight_main_memory[i*typical_width+q][m];
                        for(integer n=0;n<MAC_NUM;n=n+1) begin
                            if(i*typical_width+q>Weight_H-1)
                                PE_act_in[n][q] <= '0;
                            else
                                PE_act_in[n][q] <= Input_activation_main_memory[j*MAC_NUM+n][i*typical_width+q];
                            end     
                        end
                    end
                end
                @(negedge clk) begin
                    PE_clear_acc <= 1;
                end
                
                @(negedge clk) 
                @(negedge clk) begin
                    for(integer n=0;n<MAC_NUM;n=n+1) begin
                        Output_activation_main_memory[j*MAC_NUM+n][m] <= PE_result_out[n];
                    end
                end
            end
        end
        @(posedge clk);
        for(integer k=0;k<OA_H;k=k+1) begin
            for(integer p=0;p<OA_W;p=p+1) begin
                if(Output_activation_main_memory[k][p]!==reference_output[k][p]) begin
                    $display("wrong at (%d %d), output %d, reference %d", k, p, Output_activation_main_memory[k][p], reference_output[k][p]);
                    wrong_num = wrong_num + 1;
                end
            end
        end
        $display("wrong num: %d",wrong_num);
        @(negedge clk)
        $finish(0);//����������Զ� (important for getting the running time)
    end

endmodule