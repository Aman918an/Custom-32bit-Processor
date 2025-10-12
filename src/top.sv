// using harvard arch in this processor
`timescale 1ns / 1ps
`include "define.vh"

module top(
input clk, sys_rst,
input [15:0] din,
output reg [15:0] dout
);

// register file
reg [31:0] IR;
reg [15:0] GPR [31:0];
reg [15:0] SGPR;
reg [31:0] mul_res;

reg sign=0, zero=0, carry=0, overflow=0;

reg [31:0] inst_mem [15:0];     /// program memory
reg [31:0] data_mem [15:0];     /// data memory

reg jmp_flag =0;
reg stop =0;

// alu logic 
task decode_inst();
begin

case(`oper_type)
`movsgpr:begin
         GPR[`rdst]=SGPR;
end

`mov:begin
if(`imm_mode)
    GPR[`rdst]=`isrc;
else
    GPR[`rdst]=GPR[`rsrc1];
end
    
`add:begin
if(`imm_mode)
    GPR[`rdst]=GPR[`rsrc1]+`isrc;
else
    GPR[`rdst]=GPR[`rsrc1]+GPR[`rsrc2];
end

`sub:begin
if(`imm_mode)
    GPR[`rdst]=GPR[`rsrc1]-`isrc;
else
    GPR[`rdst]=GPR[`rsrc1]-GPR[`rsrc2];
end
`mul:begin
if(`imm_mode)
    mul_res=GPR[`rsrc1]*`isrc;
else
    mul_res=GPR[`rsrc1]*GPR[`rsrc2];
    
GPR[`rdst]=mul_res[15:0];
SGPR=mul_res[31:16];
end

// Logical operations
`ror:begin
    if(`imm_mode)
        GPR[`rdst]=GPR[`rsrc1] | `isrc;
    else
        GPR[`rdst]=GPR[`rsrc1] | GPR[`rsrc2];
end

`rand:begin
    if(`imm_mode)
        GPR[`rdst]=GPR[`rsrc1] & `isrc;
    else
        GPR[`rdst]=GPR[`rsrc1] & GPR[`rsrc2];
end

`rxor:begin
    if(`imm_mode)
        GPR[`rdst]=GPR[`rsrc1] ^ `isrc;
    else
        GPR[`rdst]=GPR[`rsrc1] ^ GPR[`rsrc2];
end

`rxnor:begin
    if(`imm_mode)
        GPR[`rdst]=GPR[`rsrc1] ~^ `isrc;
    else
        GPR[`rdst]=GPR[`rsrc1] ~^ GPR[`rsrc2];
end

`rnand:begin
    if(`imm_mode)
        GPR[`rdst]= ~(GPR[`rsrc1] & `isrc);
    else
        GPR[`rdst]= ~(GPR[`rsrc1] & GPR[`rsrc2]);
end

`rnor:begin
    if(`imm_mode)
        GPR[`rdst]= ~(GPR[`rsrc1] | `isrc);
    else
        GPR[`rdst]= ~(GPR[`rsrc1] | GPR[`rsrc2]);
end

`rnot:begin
    if(`imm_mode)
        GPR[`rdst]= ~(`isrc);
    else
        GPR[`rdst]= ~(GPR[`rsrc1]);
end


/////////////////////
`storedin:begin
    data_mem[`isrc]=din;
end

`storereg:begin
    data_mem[`isrc]= GPR[`rsrc1];
end

`senddout:begin
    dout=data_mem[`isrc];
end

`sendreg:begin
    GPR[`rdst]=data_mem[`isrc];
end

/*`readin:begin
    GPR[`rdst]=din;
end

`writein:begin
    dout=GPR[`rsrc1];
end
*/

// Control logic
// jump and branch
`jump:begin
    jmp_flag=1'b1;
end

`jcarry:begin
    if(carry==1)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`jsign:begin
    if(sign==1)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`joverflow:begin
    if(overflow==1)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`jnocarry:begin
    if(carry==0)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`jnosign:begin
    if(sign==0)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`jnooverflow:begin
    if(overflow==0)
        jmp_flag=1'b1;
    else
        jmp_flag=1'b0;
end

`halt:begin
    stop=1'b1;
end


endcase
end
endtask

// logic for condition flags

reg [16:0] temp_sum;

task decode_condflag();
begin
// for sign flag
if(`oper_type==`mul)
    sign=SGPR[15];
else
    sign= GPR[`rdst][15];

// for carry flag

if(`oper_type==`add)
begin
    if(`imm_mode)
        begin
        temp_sum= GPR[`rsrc1]+ `isrc;
        carry= temp_sum[16];
        end
    else 
        begin
        temp_sum=GPR[`rsrc1]+GPR[`rsrc2];
        carry= temp_sum[16];
        end
end
else
    carry=1'b0;




// zero flag

//if(`oper_type==`mul)
    //zero= ~((|SGPR[15:0]) | (|GPR[`rdst]));
/*else
    zero= ~(|GPR[`rdst]);
  */  
  zero = (~(|GPR[`rdst])|~(|SGPR[15:0]));
  
  
  
// overflow flag
if(`oper_type== `add)
begin
    if(`imm_mode)
        overflow= ((~GPR[`rsrc1][15] & ~IR[15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & IR[15] & ~GPR[`rdst][15]));
    else
        overflow= ((~GPR[`rsrc1][15] & ~GPR[`rsrc2][15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & GPR[`rsrc2][15] & ~GPR[`rdst][15]));
end
else if(`oper_type== `sub)
begin
    if(`imm_mode)
        overflow= ((~GPR[`rsrc1][15] & IR[15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & ~IR[15] & GPR[`rdst][15]));
    else
        overflow= ((~GPR[`rsrc1][15] & GPR[`rsrc2][15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & ~GPR[`rsrc2][15] & GPR[`rdst][15]));
end
else
    overflow=1'b0;

end
endtask

/// reading programs
initial begin
$readmemb("D:/Verilog/custom_processor/custom_processor.srcs/sources_1/new/data.mem",inst_mem);
$display("inst_mem[0]=%b inst_mem[1]=%b inst_mem[2]=%b", inst_mem[0], inst_mem[1], inst_mem[2]);
end

//instruction reading one by one
reg [2:0] count=0;
integer PC=0;
always@(posedge clk)
begin
    if(sys_rst)
    begin
        count<=0;
        PC<=0;
    end
    else
    begin
        if(count<4)
            count<=count+1;
        else
        begin
            count<=0;
            PC<=PC+1;
        end
    end
end

//// reading instruction
/*always@(*)
begin
if(sys_rst==1'b1)
IR=0;
else
begin
    IR=inst_mem[PC];
    decode_inst();
    decode_condflag();
end
end
*/


///////////////////////////////////
//jump and branching
parameter idle=0, fetch_inst=1,dec_exe_inst=2, next_inst=3, sense_halt=4, delay_next_inst=5;
// idle checks the rst state
//fetch_inst load the instruction from memory
//dec_exe_inst execute inst + update cond flags
// next_inst next inst to be fetched

reg [2:0] state = idle, next_state= idle;

always@(posedge clk) // sequential 
begin
if(sys_rst)
    state<= idle;
else
    state<= next_state;
end


always@(*)
begin
case (state)
    idle: begin
        IR=32'h0;
        PC=0;
        next_state= fetch_inst;
        end
     
     fetch_inst:begin
        IR<=inst_mem[PC];
        next_state=dec_exe_inst;
        end
     dec_exe_inst:begin
        decode_inst();
        decode_condflag();
        next_state=delay_next_inst;
        end
     delay_next_inst:begin
        if(count<4)
            next_state=delay_next_inst;
        else
            next_state=next_inst;
        end
     next_inst:begin
        next_state=sense_halt;
        if(jmp_flag==1'b1)
            PC=`isrc;
        else
            PC=PC+1;
        end
     sense_halt:begin
        if(stop==1'b0)
            next_state=fetch_inst;
        else if (sys_rst==1'b1)
            next_state=idle;
        else
            next_state=sense_halt;
        end
default:next_state=idle;
        
endcase
end
     
     


always@(posedge clk)
begin
case(state)
    idle:begin
        count<=0;
        end
    fetch_inst:begin
        count<=0;
        end
    dec_exe_inst:begin
        count<=0;
        end
    delay_next_inst:begin
        count<=count+1;
        end
    next_inst:begin
        count<=0;
        end
    sense_halt:begin
        count<=0;
        end
default: count<=0;
endcase
end






endmodule
