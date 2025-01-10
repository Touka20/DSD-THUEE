`timescale 1ns/1ps
`define CLK_PERIOD  10 //100MHz T=10ns

module tb_systolic_array; //test bench

	parameter width    =   4;  // number of multiply-accumulation units
	parameter len  =  5;
	parameter BW_ACT     =   8;  // bit length of activation
    parameter BW_WET     =   8;  // bit length of weight
    parameter BW_ACCU    =   32;    // bit length of accu result  

    parameter IA_H = 100;
    parameter IA_W = 150;
    parameter Weight_H = 150;
    parameter Weight_W = 16; 
    parameter OA_H = 100;
    parameter OA_W = 16;
    
    reg for_learn;
    reg clk;
    reg reset_n;
    reg PE_mac_enable;
    reg PE_clear_acc;

    reg signed [BW_ACT-1:0]    PE_act_in [len-1:0];         // input activation
    reg signed [BW_WET-1:0]    PE_wet_in[len-1:0][width-1:0];         // input weight
    reg  [7:0]           PE_res_shift_num;
    wire signed [BW_ACCU-1:0]    PE_result_out [width-1:0];    // output result   
    
    reg signed [BW_ACT-1:0]Input_activation_main_memory[IA_H-1:0][IA_W-1:0]; // main memory (DRAM)
    reg signed [BW_ACT-1:0]Weight_main_memory[Weight_H-1:0][Weight_W-1:0];
    reg signed [BW_ACT-1:0]Output_activation_main_memory[OA_H-1:0][OA_W-1:0];
    reg signed [BW_ACCU-1:0]out_buffer[OA_H-1:0][OA_W-1:0];
    reg signed [BW_ACT-1:0]reference_output[OA_H-1:0][OA_W-1:0];
    wire signed [BW_ACCU-1:0]out_temp[OA_H-1:0][OA_W-1:0];
    reg [7:0]count;
    reg write_en;
    
    reg [6:0] m;
    reg  write;
    systolic_accu #(
        .len(len),
        .width(width),
        .BW_ACT(BW_ACT),
        .BW_WET(BW_WET),
        .BW_ACCU(BW_ACCU)
    )u_pe_array(
        .clk(clk),
        .reset(reset_n),
        .PE_mac_enable(PE_mac_enable),
        .PE_clear_acc(PE_clear_acc),
        .act_in(PE_act_in),
        .wet(PE_wet_in),
        .PE_res_shift_num(PE_res_shift_num),
        .out(PE_result_out)
    );
    
    genvar ii,jj;
    generate
        for(ii=0;ii<OA_H;ii=ii+1)begin
            for(jj=0;jj<OA_W;jj=jj+1)begin
                assign out_temp[ii][jj]=out_buffer[ii][jj]>>>PE_res_shift_num;
            end
        end
    endgenerate
    
    initial begin
        clk = 0;
        reset_n = 1;
        PE_res_shift_num = 8;
        PE_clear_acc = 0;
        write=0;
        count=0;
        for(integer n=0;n<len;n=n+1) begin
            PE_act_in[n] <= '0;
            for(integer k=0;k<width;k=k+1)begin
                PE_wet_in[n][k]<='0;
            end
        end
        for(integer i=0;i<OA_H;i=i+1)
            for(integer j=0;j<OA_W;j=j+1)
                out_buffer[i][j]<='0;
  
        forever begin
            #(`CLK_PERIOD/2) clk = ~clk; 
        end
    end
    integer wrong_num=0; 
    
    always@(posedge clk)begin
        if(write)begin
            if(count<len+1)count<=count+1;
            else begin count<=0;
            write_en<=1;
            end
        end
    end
    
    always@(*)begin
    if(write_en)begin
            write<=0;
            for(integer s=0;s<IA_H+width-1;s=s+1) begin
                    @(posedge clk)begin
                        for(integer p=0;p<width;p=p+1)begin
                            if(s>=p&&p+IA_H-1>=s)
                                $display("s: %d",s);
                                $display("p: %d",p);
                                $display("write_number:%d",PE_result_out[p]);
                                out_buffer[s-p][m*width+p]<=out_buffer[s-p][m*width+p]+PE_result_out[p];                       
                        end
                    end

            end
            write_en<=0;
            PE_clear_acc<=1;
            @(posedge clk);
            PE_clear_acc<=0;
            
    end
    end
    
    initial begin
        @(negedge clk); 
        reset_n = 0; 
        
        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//input_act_bin.txt", Input_activation_main_memory);
        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//weight_bin.txt", Weight_main_memory);
        $readmemb("C://Users//yyzqg//OneDrive//doc//Lectures//HML//lab2//reference_output_bin.txt", reference_output);
        
        // loop nest
        @(negedge clk);
        reset_n = 1;
        PE_mac_enable = 1;
        for(m=0;m<OA_W/width;m=m+1) begin
                for(integer i=0;i<IA_W/len;i=i+1) begin
                    @(negedge clk) begin                      
                            PE_clear_acc <= 0; 
                    end
                    @(posedge clk);
                    write<=1;                     
                        for(integer j=0;j<IA_H+len-1;j=j+1)begin                            
                            @(posedge clk)begin
                                
                                for(integer n=0;n<len;n=n+1)begin
                                        if(j-IA_H+1<=n&&n<=j)PE_act_in[n]<=Input_activation_main_memory[j-n][i*len+n];
                                        else PE_act_in[n]<='0;                          
                                    for(integer k=0;k<width;k=k+1)begin
                                        PE_wet_in[n][k] <= Weight_main_memory[i*len+n][m*width+k];                                     
                                    end
                                end
                             end
                         end  
                         @(posedge clk);    
                         PE_act_in[len-1]<=0;  
                         for(integer q=0;q<width+1;q=q+1)begin
                            @(posedge clk);
                         end
                                            
                end
        end
        
        
        for(integer a=0;a<OA_H;a=a+1)begin
            @(posedge clk)begin
            for (integer b=0;b<OA_W;b=b+1)begin  
                if(out_temp[a][b]<-128)
                    Output_activation_main_memory[a][b]<=-128;
                else if(out_temp[a][b]>127)
                    Output_activation_main_memory[a][b]<=127;
                else          
                    Output_activation_main_memory[a][b]<=out_temp[a][b][BW_ACT-1:0];
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
        $finish(0);
    end

endmodule