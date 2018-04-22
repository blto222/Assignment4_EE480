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
