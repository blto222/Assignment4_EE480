`define WORD        [15:0]
`define Opcode      [15:12]
`define Dest        [11:8]
`define Sreg        [7:4]
`define Treg        [3:0]
`define addr        [7:0]
`define REGSIZE     [15:0]
`define MEMSIZE     [65535:0]
`define RNAME       [3:0]
`define OP          [5:0]
`define CALLST      [63:0]
`define ENSTK       [31:0]

`define Nproc     2

//Non-extended OPcodes
`define OPadd      6'b000100
`define OPslt      6'b000101
`define OPsra      6'b000110
`define OPmul      6'b000111
`define OPand      6'b001000
`define OPor       6'b001001
`define OPxor      6'b001010
`define OPsll      6'b001011

`define OPli8      6'b001100
`define OPlu8      6'b001101

//No-register instructions
`define OPtrap     6'b010000
`define OPret      6'b010001
`define OPpushen   6'b010010
`define OPpopen    6'b010100
`define OPallen    6'b011000

//2-register instructions
`define OPlnot     6'b100000
`define OPneg      6'b100001
`define OPleft     6'b100011
`define OPright    6'b100100
`define OPgor      6'b100101
`define OPload     6'b101000
`define OPstore    6'b101001

//Jump instructions
`define OPcall     6'b110000
`define OPjump     6'b110001
`define OPjumpf    6'b110011

`define OPnoop     6'b000000        //No-op instruction.

module decode (opout, regdst, opin, ir);
  output reg `OP opout;
  output reg `RNAME regdst;
  input wire `OP opin;
  input `WORD ir;
  
  always @(opin, ir)begin
    case (ir `Opcode)
      4'b0100: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPadd; regdst <= ir `Dest; end
      4'b0101: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPslt; regdst <= ir `Dest; end
      4'b0110: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPsra; regdst <= ir `Dest; end
      4'b0111: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPmul; regdst <= ir `Dest; end
      4'b1000: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPand; regdst <= ir `Dest; end
      4'b1001: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPor;  regdst <= ir `Dest; end
      4'b1010: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPxor; regdst <= ir `Dest; end
      4'b1011: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPsll; regdst <= ir `Dest; end
      4'b1100: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPli8; regdst <= ir `Dest; end
      4'b1101: begin opout <= (opin == `OPjumpf) ? `OPnoop : `OPlu8; regdst <= ir `Dest; end
      
      4'b0000: begin
        case (ir `Treg)
          4'b0000: opout <= `OPtrap;
          4'b0001: opout <= `OPret;
          4'b0010: opout <= `OPpushen;
          4'b0100: opout <= `OPpopen;
          4'b1000: opout <= `OPallen;
        endcase
        regdst <= 0;
      end
        
      4'b0001: begin
        case (ir `Treg)
          4'b0000: begin opout <= `OPcall; regdst <= 0; end
          4'b0001: begin opout <= `OPjump; regdst <= 0; end
          4'b0011: begin opout <= `OPjumpf; regdst <= ir `Dest; end
        endcase
      end
      
      4'b0010: begin
        case (ir `Treg)
          4'b0000: opout <= `OPlnot;
          4'b0001: opout <= `OPneg;
          4'b0010: opout <= `OPleft;
          4'b0011: opout <= `OPright;
          4'b0100: opout <= `OPgor;
          4'b1000: opout <= `OPload;
          4'b1001: opout <= `OPstore;
        endcase
        regdst <= ir `Dest;
      end
      default: opout <= `OPnoop;
    endcase
  end
endmodule

module alu(result, op, in1, in2, in3, en, addr);
  output reg `WORD result;
  input wire `OP op;
  input wire `WORD in1, in2, in3;
  input wire en;
  input wire `addr addr;
  
  always @(op, in1, in2, in3, en, addr) begin
    if (en == 0) result <= in3;
	else begin
    case (op)
      `OPadd: begin result <= in1 + in2; end
      `OPslt: begin result <= $signed(in1) < $signed(in2); end
      `OPsra: begin result <= $signed(in1) >>> (in2 & 15); end
      `OPmul: begin result <= in1 * in2; end
      `OPand: begin result <= in1 & in2; end
      `OPor:  begin result <= in1 | in2; end
      `OPxor: begin result <= in1 ^ in2; end
      `OPsll: begin result <= in1 << (in2 & 15); end
      `OPli8: begin result <= addr; result[15:8] <= {8{addr [7]}}; end
      `OPlu8: begin result <= (in1 & 16'h00ff) | (addr << 8); end    
      `OPneg: begin result <= -in1; end
      `OPlnot: begin result <= ~in1; end
      `OPleft: begin result <= in1; end
      `OPright: begin result <= in1; end
      default: begin result = in3; end
    endcase
	end
  end
endmodule

module processor(halt, reset, clk);
  output wire halt;
  input reset, clk;
  
  reg [`Nproc*16-1:0] regfile `REGSIZE;
  reg `WORD mainmem `MEMSIZE;
  reg `WORD datamem `MEMSIZE;
  reg `WORD ir, srcval1, srcval2, dstval, newpc;
  wire `OP op;
  wire `RNAME regdst;
  wire `WORD res;
  reg `OP s0op, s1op, s2op, s1op2;
  reg `RNAME s0src1, s0src2, s0dst, s0regdst, s1regdst, s2regdst;
  reg `WORD pc;
  reg `WORD s1srcval1, s1dstval;
  reg `WORD s0ir, s1ir;
  reg `addr s1addr;
  reg `CALLST retaddr;
  reg [5:0] forwarded;
  reg dstvalforward;
  wire [`Nproc-1 : 0] atleast1enabled;
  reg [`Nproc*16-1:0] writedata;
  reg [15:0] gor [`Nproc-1:0];
  reg clk2;
  
  /*TEMPORARY*/
  reg [`Nproc*16-1:0] datain;
  wire [`Nproc*16-1:0] dataout;
  reg `WORD source1, source2;
  /*TEMPORARY*/
  
  always @(reset) begin
    pc = 0;
    s0op = `OPnoop;
    s1op = `OPnoop;
    s2op = `OPnoop;
    s0regdst = 4'b0000;
    s1regdst = 4'b0000;
    s2regdst = 4'b0000;
    $readmemh0(regfile, 0, 15);
    $readmemh1(mainmem, 0, 65535); 
  end
  
  always @(*)
    clk2 = clk;
  
  decode mydecode(op, regdst, s1op, ir);
  
  genvar i,j;
  generate
    //For loop attempts to complicatedly decide what goes into source1 and source 2. Tries to look for left and right funcitons with value forwarding.
    for (i=0; i < `Nproc; i=i+1) begin : Processor
	
      //Processing Element Instantiation utilizing source1 and source2
      PE PE(clk2, reset, {clk, s1ir `addr, regdst, op, forwarded}, 
            ((s0op == `OPleft) ? ((forwarded[2]==1) ? writedata[((((i+`Nproc-1)%`Nproc +1)*16)-1):(16*(((i+`Nproc-1)%`Nproc)))] : regfile[s0src1][((((i+`Nproc-1)%`Nproc +1)*16)-1):(16*(((i+`Nproc-1)%`Nproc)))]) : 
             (s0op == `OPright) ? ((forwarded[2]==1) ? writedata[((((i+1)%`Nproc +1)*16)-1):(16*((i+1)%`Nproc))] : regfile[s0src1][((((i+1)%`Nproc +1)*16)-1):(16*((i+1)%`Nproc))]) :
             (forwarded[2]==1) ? writedata[(((i+1)*16)-1):(16*i)] : regfile[s0src1][(((i+1)*16)-1):(16*i)]), 
            (forwarded[3]==1) ? writedata[(((i+1)*16)-1):(16*i)] : regfile[s0src2][(((i+1)*16)-1):(16*i)], 
            (s2regdst && (s0src2 == s2regdst)) ?  writedata[(((i+1)*16)-1):(16*i)] : regfile[s0regdst][(((i+1)*16)-1):(16*i)], atleast1enabled[i], dataout[(((i+1)*16)-1):(16*i)], halt);
	  
    end
  endgenerate
  
  always @(*) ir = mainmem[pc];
  
  always @(*) newpc = (((s0op == `OPcall) || (s0op == `OPjump)) ? ir :
                       (s1op ==`OPjumpf && atleast1enabled == 0) ? s0ir : 
                       (s1op == `OPjumpf) ? pc :
                       ((op == `OPret) && s1op != `OPjumpf) ? retaddr[15:0] :
                       (pc + 1));
  
  always @(*) forwarded[0] = (s1regdst && (s0src1 == s1regdst)) ? 1 : 0;
    
  always @(*) forwarded[1] = (s1regdst && (s0src2 == s1regdst)) ? 1 : 0;
  
  always @(*) forwarded[2] = (s2regdst && (s0src1 == s2regdst)) ? 1 : 0;
  
  always @(*) forwarded[3] = (s2regdst && (s0src2 == s2regdst)) ? 1 : 0;
  
  always @(*) forwarded[4] = (s1regdst && (s0regdst == s1regdst)) ? 1 : 0;
  
  always @(*) forwarded[5] = (s2regdst && (s0regdst == s2regdst)) ? 1 : 0;
  
  //Instruction Fetch
  always @(posedge clk) begin
    if (!halt && s0op != `OPtrap) begin
      //Potentially stuff about enable blocks
      s0op <= (s0op[5:4] == 2'b11 || s1op == `OPjumpf) ? `OPnoop : op;
      s0regdst <= regdst;  
      s0src1 <= (op == `OPlu8) ? ir `Dest : ir `Sreg;
      s0src2 <= ir `Treg;
      s0dst <= ir `Dest;
      s0ir <= ir;
      pc <= newpc;
    end
  end
  
  always @(posedge clk)
    if (!halt) begin
      if ((s0op == `OPcall) && s2op != `OPjumpf) begin retaddr <= {retaddr[47:0], pc + 16'h0001}; s0op <= `OPnoop; end
      if ((op == `OPret) && s1op != `OPjumpf) begin retaddr <= {retaddr[63:48], retaddr[63:16]}; s0op <= `OPnoop; end
      s1regdst <= s0regdst;
      s1op <= s0op;
      s1ir <= s0ir;
    end
  
  //ALU phase (s2regdest)
always @(posedge clk) if (!halt) begin
  s2regdst <= s1regdst;
  s2op <= s1op;
  writedata <= dataout;
end
  
  // Register Write
always @(posedge clk) if (!halt) begin
  if (s2regdst > 2) regfile[s2regdst] <= /*(s1op == `OPload) ? datamem[s1srcval1]*/dataout;    //need to figure out how to do the load and store.
end
endmodule





module PE(clk, reset, control, source1, source2, datain, en, dataout, halt);
  input wire clk, reset;
  input wire [24:0] control;     //control[0:5] will be value forwarding for input registers 1 and 2. The rest should be the 
                                // destination register, opcode, and anything else other than actual register data that needs
                                // to be passed in. 
                                //control[11:6] will be the opcode from CU. 
                                //control[15:12] will be register destination (might not need it).
                                //control[23:16] is the 8-bit immediate value being passed in.
                                //control[24] is a copy of the clk bit. I wanted to make sure it was working cuz it doesnt' seem to show up.
  input wire `WORD source1;  //Register value of Sreg passed in from CU
  input wire `WORD source2;  //Register value of Treg passed in from CU
  input wire `WORD datain;
  output reg en;
  output reg `WORD dataout;
  output reg halt;
  
  reg `WORD procmem `MEMSIZE;
  
  wire `WORD res;
  reg `WORD srcval1, srcval2, s2val, dstval0;
  reg `ENSTK enable;
  reg `OP s0op, s1op, s1op2;
  reg `RNAME regdst;
  reg `WORD s1srcval1, s1srcval2, s1dstval;
  reg [1:0] enablestate;
  
  always @(reset) begin
    halt = 0;
    s0op = `OPnoop;
    s1op = `OPnoop;
    enable = 32'hffffffff;
    $readmemh2(procmem, 0, 65535); 
    //Possibly memreading for registers? Might do that in the CU though.
  end
  
  alu myalu(res, s1op, s1srcval1, s1srcval2, s1dstval, enablestate[1], control[23:16]);
  
  // compute srcval1, with value forwarding...
  always @(*) srcval1 = ((control[0] == 1) ? res :
                         ((control[2] == 1) ? s2val :
                            source1));
  
  // compute srcval, with value forwarding...
  always @(*) srcval2 = ((control[1] == 1) ? res :
                         ((control[3] == 1) ? s2val :
                         source2));

  always @(*) en = enable[0];
  
  always @(*) dstval0 = ((control[4] == 1) ? res : 
                         ((control[5] == 1) ? s2val :
						 datain));
  
  //What might have been done in the instruction fetch stage.
  always @(posedge clk) begin
    if (!halt && s0op != `OPtrap) begin
//      if ((s1op == `OPpushen) && !(s1op == `OPjumpf)) begin enable <= ((enable << 1) | (enable & 1)); end
//      if ((s1op == `OPpopen) && !(s1op == `OPjumpf)) begin enable <= enable >> 1; end
 //     if ((s1op == `OPallen) && !(s1op == `OPjumpf)) begin enable <= enable | 1; end
      s0op <= (s0op[5:4] == 2'b11 || s1op == `OPjumpf) ? `OPnoop : control[11:6];
	  enablestate[0] = en;
    end
  end
  
  // what would be done in the register read phase.
  always @(posedge clk)
    if (!halt) begin
      s1op <= s0op;
      s1srcval1 <= srcval1;
      s1srcval2 <= srcval2;
      s1dstval <= dstval0;
      if (s1op == `OPtrap) halt <= 1;
      enablestate[1] = enablestate[0];
    end
	
  always @(*) begin
//    enable[0] = (s1op == `OPjumpf && s1dstval == 0) ? 0 : ((s1op == `OPallen)) ? 1 : enable[0];
    enable = (s1op == `OPjumpf && s1dstval == 0) ? {enable[31:1], 1'b0} : (s0op == `OPallen) ? {enable[31:1], 1'b1} : (s0op == `OPpushen) ? {enable[30:0], enable[0]} : (s0op == `OPpopen) ? {enable[31], enable[31:1]} : enable;
  end
  
  always @(posedge clk) if (!halt) begin
    s2val <= (s1op == `OPload) ? procmem[s1srcval1] : res;
    //s2regdst <= s1regdst;   //Potentially taken care of by CU
    if (s1op == `OPstore) procmem[s1srcval1] <= s1dstval;
    if (s1op == `OPtrap) halt <= 1;
    dataout <= (s1op == `OPload) ? procmem[s1srcval1] : res;
  end

  
endmodule




 
module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
integer i = 0;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted && (i < 200)) begin
    #10 clk = 1;
    #10 clk = 0;
    i=i+1;
  end
  $finish;
end
endmodule
