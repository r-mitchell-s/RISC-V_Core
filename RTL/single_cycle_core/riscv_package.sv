package riscv_pkg;
  
  // instruction-type opcode macros
  typedef enum logic [6:0] {
    R_TYPE = 7'h33,							// register-type only operate on registers
    I_TYPE0 = 7'h3,							// immediate-type ALU instructions
    I_TYPE1 = 7'h13,						// immediate-type data movement instructions
    I_TYPE2 = 7'h67,						// immediate-type control flow instructions
    S_TYPE = 7'h23,							// store-type use immediate for memory offset
    B_TYPE = 7'h63,							// branch-type instructions built off of register comparisons
    U_TYPE0 = 7'h37,						// upper-immediate-type dedicated to LUI
    U_TYPE1 = 7'h17,						// upper-immediate-type dedicated to AUIPC
    J_TYPE = 7'h6F							// jump-type insrtuctions that use 20-bit mem offset (JAL)
  } opcode_t;
  
  // ALU operation selection macros
  typedef enum logic [3:0] {
    OP_ADD = 0,
    OP_SUB = 1,
    OP_SLL = 2,
    OP_SRL = 3,
    OP_SRA = 4,
    OP_OR = 5,
    OP_AND = 6,
    OP_XOR = 7,
    OP_SLTU = 8,
    OP_SLT = 9
  } alu_code_t;
  
  // data memory interface macros for sw/lw
  typedef enum logic [1:0] {
    BYTE,
    HALF_WORD,
    RESERVED,
    WORD
  } mem_access_size_t;
  
  // control signals packaged together
  typedef struct packed {
    logic data_req;
    logic data_wr;
    logic zero_extnd;
    logic rf_wr_en;
    logic pc_sel;
    logic op1_sel;
    logic op2_sel;
    logic [1:0] data_byte;
    logic [1:0] rf_wr_data_sel;
    logic [3:0] alu_funct_sel;
  } control_t;
  
  // R-type control signals in format {funct7[5] , funct3}
  typedef enum logic [3:0] {
    ADD = 4'b0000,
    SLL = 4'b0001,
    SLT = 4'b0010,
    SLTU = 4'b0011,
    XOR = 4'b0100,
    SRL = 4'b0101,
    OR = 4'b0110,
    AND = 4'b0111,
    SUB = 4'b1000,
    SRA = 4'b1101
  } r_type_t;
  
  // I-type control signals in format {opcode[4], funct3}
  typedef enum logic [3:0] {
  	LB = 4'b0000,
    LH = 4'b0001,
    LW = 4'b0010,
    LBU = 4'b0100,
    LHU = 4'b0101,
    ADDI = 4'b1000,
    SLLI = 4'b1001,
    SLTI = 4'b1010,
    SLTIU = 4'b1011,
    XORI = 4'b1100,
    SRXI = 4'b1101,
    ORI = 4'b1110,
    ANDI = 4'b1111
  } i_type_t;
  
  // S-type control signals in format {funct3}
  typedef enum logic [2:0] {
  	SB = 3'b000,
    SH = 3'b001,
    SW = 3'b010
  } s_type_t;
  
  // B-type control signals in format {funct3}
  typedef enum logic [2:0] {
    BEQ = 3'b000,
    BNE = 3'b001,
    BLT = 3'b100,
    BGE = 3'b101,
    BLTU = 3'b110,
    BGEU = 3'b111
  } b_type_t;
  
  // U-type control signals in format {funct7}
  typedef enum logic [6:0] {
    LUI = 7'b0110111,
    AUIPC = 7'b0010111
  } u_type_t;
  
  // J-type control signals (JAL) in format {}
  typedef enum logic [5:0] {
  	JAL = 6'b000011
  } j_type_t;
  
  // MUX codes for selecting what to write back to RF
  typedef enum logic [1:0] {
    ALU = 2'b00,
    MEM = 2'b01,
    IMM = 2'b10,
    PC = 2'b11
  } writeback_sel_t;
  
endpackage