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
      0100: opout <= `OPadd;
      0101: opout <= `OPslt;
      0110: opout <= `OPsra;
      0111: opout <= `OPmul;
      1000: opout <= `OPand;
      1001: opout <= `OPor;
      1010: opout <= `OPxor;
      1011: opout <= `OPsll;
      1100: opout <= `OPli8;
      1101: opout <= `OPlu8;
      
      0000: begin
        case (ir `Treg)
          0000: opout <= `OPtrap;
          0001: opout <= `OPret;
          0010: opout <= `OPpushen;
          0100: opout <= `OPpopen;
          1000: opout <= `OPallen;
        endcase
      end
        
      0001: begin
        case (ir `Treg)
          0000: opout <= `OPcall;
          0001: opout <= `OPjump
          0011: opout <= `OPjumpf;
        endcase
      end
      
      0010:
        case (ir `Treg)
          0000: opout <= `OPlnot;
          0001: opout <= `OPneg;
          0010: opout <= `OPleft;
          0011: opout <= `OPright;
          0100: opout <= `OPgor;
          1000: opout <= `OPload;
          1001: opout <= `OPstore;
        endcase
      end
      default: opout <= `OPnoop;
    endcase
  end
endmodule

module alu(result, op, in1, in2, addr);
  output reg `WORD result;
  input wire `OP op;
  input wire `WORD in1, in2;
  input wire `addr addr;
  
  always @(op, in1, in2, addr) begin
    case (op)
      `OPadd: begin result <= in1 + in2; end
      `OPslt: begin result <= $signed(in1) < $signed(in2); end
      `OPsra: begin result <= $signed(in1) >>> (in2 & 15); end            //NEED TO FIX. NEEDS SIGN EXTEND. old: in1 >>> (in2 & 15)
      `OPmul: begin result <= in1 * in2; end
      `OPand: begin result <= in1 & in2; end
      `OPor:  begin result <= in1 | in2; end
      `OPxor: begin result <= in1 ^ in2; end
      `OPsll: begin result <= in1 << (in2 & 15); end
      `OPli8: begin result <= addr; result[15:8] <= {8{addr [7]}}; end
      `OPlu8: begin result <= (in1 & 16'h00ff) | (addr << 8); end    
      `OPsz: begin
        case (addr[3:0])
          `OPneg: begin result <= -in1; end
          `OPlnot: begin result <= ~in1; end
          `OPload: ;
          `OPstore: ;
          default: begin result <= in1; end            //As of now, right, left, and gor do this, so this covers all of them.
        endcase
      end
      default: begin result = in1; end
    endcase
  end
endmodule

module processor(halt, reset, clk);
  output reg halt;
  input reset, clk;
  
  reg `WORD regfile `REGSIZE;
  reg `WORD mainmem `MEMSIZE;
  reg `WORD datamem `MEMSIZE;
  reg `WORD ir, srcval1, srcval2, dstval, newpc;
  reg rrsquash;
  wire `OP op;
  wire `RNAME regdst;
  wire `WORD res;
  reg `OP s0op, s1op, s2op, s1op2;
  reg `RNAME s0src1, s0src2, s0dst, s0regdst, s1regdst, s2regdst;
  reg `WORD pc;
  reg `WORD s1srcval1, s1srcval2, s1dstval;
  reg `WORD s2val;
  reg `WORD s0ir, s1ir;
  reg `addr s1addr;
  reg `CALLST retaddr;
  reg `ENSTK enable;
  
  always @(reset) begin
    halt = 0;
    pc = 0;
    s0op = `OPnoop;
    s1op = `OPnoop;
    s2op = `OPnoop;
    s0regdst = 4'b0000;
    s1regdst = 4'b0000;
    s2regdst = 4'b0000;
    enable = 32'h00000001;
    $readmemh0(regfile, 0, 15);
    $readmemh1(mainmem, 0, 65535); 
  end
  
  decode mydecode(op, regdst, s0op, ir);
                  //NEED TO IMPLEMENT THE PROCESSORS.
  
  always @(*) ir = mainmem[pc];
  
  always @(*) newpc = (((s0op == `OPcall || s0op== `OPjump)/* && (s1dstval == 0)*/) ? ir :
                       (rrsquash) ? s0ir : 
                       (s1op == `OPjumpf) ? pc :
                       ((ir `Opcode == `OPnoreg) && (ir `Treg == `OPret)) ? retaddr[15:0] :
                       (pc + 1));
  
  
  
  
  
  
endmodule
