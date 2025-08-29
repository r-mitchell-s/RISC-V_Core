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
  
  import riscv_pkg::*;
  
  // - - - - - EXECUTE (ALU) - - - - - //
  // 
  // 
  
  module alu (
    input   logic [31:0] opr_a_i,							// operand A
    input   logic [31:0] opr_b_i,							// operand B
    input   logic [3:0]  op_sel_i,						// operation select line
    output  logic [31:0] alu_res_o						// ALU output
  );
    
    // define ALU behavior according to the selected operation
    always_comb begin
      case (op_sel_i) 
        ADD: begin
          alu_res_o = opr_a_i + opr_b_i;
        end
        SUB: begin
          alu_res_o = opr_a_i - opr_b_i;
        end
        SLL: begin
          alu_res_o = opr_a_i << opr_b_i[4:0];
        end
        SRL: begin
          alu_res_o = opr_a_i >> opr_b_i[4:0];
        end
        SRA: begin
          alu_res_o = $signed(opr_a_i) >>> opr_b_i[4:0];
        end
        OR: begin
          alu_res_o = opr_a_i | opr_b_i;
        end
        AND: begin
          alu_res_o = opr_a_i & opr_b_i;
        end
        XOR: begin
          alu_res_o = opr_a_i ^ opr_b_i;
        end
        SLTU: begin
          alu_res_o = {31'h0, opr_a_i < opr_b_i};
        end
        SLT: begin
          alu_res_o = {31'h0, $signed(opr_a_i) < $signed(opr_b_i)};
        end
        default: begin
          alu_res_o = 32'h00;
        end
      endcase
    end
  endmodule
  
  // - - - - - BRANCH CONTROL UNIT - - - - - // 
  //
  //
  
  module branch_ctrl (
    
    input  logic [31:0] opr_a_i,						// source operand 1
    input  logic [31:0] opr_b_i,						// source operand 2
    input  logic        is_b_type_ctl_i,				// enables module if current instruction is branch
    input  logic [2:0]  instr_func3_ctl_i,			// indictes branch instruction type
    output logic        branch_taken_o				// take branch? 
  );
  
      // register to store branch status
      logic branch_taken;
  
    // decide result of branch based on the
    always_comb begin
      if (is_b_type_ctl_i) begin
              case (instr_func3_ctl_i)
                  BEQ: branch_taken = opr_a_i == opr_b_i;
                  BNE: branch_taken = opr_a_i != opr_b_i;
                  BLT: branch_taken = $signed(opr_a_i) < $signed(opr_b_i);
                  BGE: branch_taken = $signed(opr_a_i) >= $signed(opr_b_i);
                  BLTU: branch_taken = opr_a_i < opr_b_i;
                  BGEU: branch_taken = opr_a_i >= opr_b_i;
                  default: branch_taken = 1'b0;
              endcase
          end else begin
              branch_taken = 1'b0;
          end
    end
  
    // final output assignment
    assign branch_taken_o = branch_taken;
        
  endmodule
  
  // - - - - - CONTROL UNIT - - - - - //
  // The control unit 
  //
  
  module ctrl_unit (
  
    input   logic         is_r_type_i,
    input   logic         is_i_type_i,
    input   logic         is_s_type_i,
    input   logic         is_b_type_i,
    input   logic         is_u_type_i,
    input   logic         is_j_type_i,
  
    input   logic [2:0]   instr_funct3_i,
    input   logic         instr_funct7_bit5_i,
    input   logic [6:0]   instr_opcode_i,
  
    output  logic         pc_sel_o,
    output  logic         op1sel_o,
    output  logic         op2sel_o,
    output  logic [3:0]   alu_func_o,
    output  logic [1:0]   rf_wr_data_o,
    output  logic         data_req_o,
    output  logic [1:0]   data_byte_o,
    output  logic         data_wr_o,
    output  logic         zero_extnd_o,
    output  logic         rf_wr_en_o
  );
   
    // create internal signals to store the driving signals for R-type and I-type control generation
    logic [3:0] r_type_alu_sel;
    logic [3:0] i_type_alu_sel;
    assign r_type_alu_sel = {instr_funct7_bit5_i, instr_funct3_i};
    assign i_type_alu_sel = {instr_opcode_i[4], instr_funct3_i};
    
    // type-dependent control signal structs
    control_t r_type_ctrls;
    control_t i_type_ctrls;
    control_t s_type_ctrls;
    control_t b_type_ctrls;
    control_t u_type_ctrls;
    control_t j_type_ctrls;
    
    // final output control signal
    control_t output_ctrls;
    
    // multiplexor tree for acquiring correct control splits based on decode stage
    always_comb begin
        output_ctrls = is_r_type_i ? r_type_ctrls : 
                               is_i_type_i ? i_type_ctrls : 
                               is_s_type_i ? s_type_ctrls :
                               is_b_type_i ? b_type_ctrls : 
                               is_u_type_i ? u_type_ctrls : 
                               is_j_type_i ? j_type_ctrls : '0;
    end
    
    // - - - - - R-TYPE CONTROL SIGNAL GENERATION - - - - - //
    always_comb begin
      r_type_ctrls = '0;                                    // zero out the ctrl struct to overwrite with new data
      r_type_ctrls.op1_sel = 1'b0;                          // select rs1 from register file
      r_type_ctrls.op2_sel = 1'b0;                          // select rs2 from register file
      r_type_ctrls.rf_wr_en = 1'b1;                         // enable register file writeback
      r_type_ctrls.rf_wr_data_sel = 2'b00;                  // select the ALU output for writeback
      r_type_ctrls.pc_sel = 1'b0;                           // next PC value will be PC + 4
      r_type_ctrls.data_req = 1'b0;                         // we are not trying to make a memory access
      
      // ALU operation selection
      case (r_type_alu_sel)
        ADD: r_type_ctrls.alu_funct_sel = OP_ADD;
        AND: r_type_ctrls.alu_funct_sel = OP_AND;
        OR: r_type_ctrls.alu_funct_sel = OP_OR;
        SLL: r_type_ctrls.alu_funct_sel = OP_SLL;
        SLT: r_type_ctrls.alu_funct_sel = OP_SLT;
        SLTU: r_type_ctrls.alu_funct_sel = OP_SLT;
        SRA: r_type_ctrls.alu_funct_sel = OP_SRA;
        SRL: r_type_ctrls.alu_funct_sel = OP_SRL;
        SUB: r_type_ctrls.alu_funct_sel = OP_SUB;
        XOR: r_type_ctrls.alu_funct_sel = OP_XOR;
        default: r_type_ctrls.alu_funct_sel = 0;
      endcase
    end
    
    // - - - - - I-TYPE CONTROL SIGNAL GENERATION - - - - - //
    always_comb begin
      i_type_ctrls = '0;                                    // zero out the ctrl struct to overwrite with new data
      i_type_ctrls.op1_sel = 1'b0;                          // select rs1 from register file
      i_type_ctrls.op2_sel = 1'b1;                          // select immediate for second operand
      i_type_ctrls.rf_wr_en = 1'b1;                         // enable register file writeback
      i_type_ctrls.rf_wr_data_sel = 2'b00;                  // select the ALU output for writeback
      i_type_ctrls.pc_sel = 1'b0;                           // next PC value will be PC + 4
      i_type_ctrls.data_req = 1'b0;                         // we are not trying to make a memory access
      
      case (i_type_alu_sel) 
        
        // I-type 0: ALU operations on immediate and source register
        ADDI: i_type_ctrls.alu_funct_sel = OP_ADD;
        SLTI: i_type_ctrls.alu_funct_sel = OP_SLT;
        SLTIU: i_type_ctrls.alu_funct_sel = OP_SLT;
        XORI: i_type_ctrls.alu_funct_sel = OP_XOR;
        ORI: i_type_ctrls.alu_funct_sel = OP_OR;
        ANDI: i_type_ctrls.alu_funct_sel = OP_AND;
        SLLI: i_type_ctrls.alu_funct_sel = OP_SLL;
        SRXI: i_type_ctrls.alu_funct_sel = instr_funct7_bit5_i ? OP_SRA : OP_SRL;
  
        // I-type 1: load operations
        LB: begin
          i_type_ctrls.alu_funct_sel = OP_ADD;
          i_type_ctrls.data_req = 1'b1;
          i_type_ctrls.data_byte = BYTE;
          i_type_ctrls.rf_wr_data_sel = MEM;
        end
        
        LH: begin
          i_type_ctrls.alu_funct_sel = OP_ADD;
          i_type_ctrls.data_req = 1'b1;
          i_type_ctrls.data_byte = HALF_WORD;
          i_type_ctrls.rf_wr_data_sel = MEM; 
        end
        
        LW: begin
          i_type_ctrls.alu_funct_sel = OP_ADD;
          i_type_ctrls.data_req = 1'b1;
          i_type_ctrls.data_byte = WORD;
          i_type_ctrls.rf_wr_data_sel = MEM;
        end
        
        LBU: begin
          i_type_ctrls.alu_funct_sel = OP_ADD;
          i_type_ctrls.data_req = 1'b1;
          i_type_ctrls.data_byte = BYTE;
          i_type_ctrls.rf_wr_data_sel = MEM;
            i_type_ctrls.zero_extnd = 1'b1;
        end
        
        LHU: begin
          i_type_ctrls.alu_funct_sel = OP_ADD;
          i_type_ctrls.data_req = 1'b1;
          i_type_ctrls.data_byte = HALF_WORD;
          i_type_ctrls.rf_wr_data_sel = MEM;
            i_type_ctrls.zero_extnd = 1'b1;
        end
  
        default: i_type_ctrls = '0;
      endcase
  
      // I-type 2: I-type jump operation (JALR handling)
      if (instr_opcode_i == I_TYPE2) begin
        i_type_ctrls = '0;
        i_type_ctrls.alu_funct_sel = OP_ADD;                // 
        i_type_ctrls.rf_wr_data_sel = PC;                   //
        i_type_ctrls.pc_sel = 1'b1;                         //
      end
    end
      
    // - - - - - S-TYPE CONTROL SIGNAL GENERATION - - - - - // 
    always_comb begin
      s_type_ctrls = '0;                                    // zero out the control struct
      s_type_ctrls.alu_funct_sel = OP_ADD;                  // add the offset to the address to calculate storage address
      s_type_ctrls.op1_sel = 1'b0;                          // select rs1 from the register file (address)
      s_type_ctrls.op2_sel = 1'b1;                          // select the immediate (offset)
      s_type_ctrls.pc_sel = 1'b0;                           // program counter updates to PC + 4
      s_type_ctrls.rf_wr_en = 1'b0;                         // stores don't write to the register file
      s_type_ctrls.data_req = 1'b1;                         // stores are a form of memory access request
      s_type_ctrls.data_wr = 1'b1;                          // stores demand we write data to memory
      
      // determine the size of the word being stored
      case (instr_funct3_i)
        SB: s_type_ctrls.data_byte = BYTE;
        SH: s_type_ctrls.data_byte = HALF_WORD;
        SW: s_type_ctrls.data_byte = WORD;
        default: s_type_ctrls = '0;
      endcase 
    end 
      
    // - - - - - B-TYPE CONTROL SIGNAL GENERATION - - - - - // 
    always_comb begin
      b_type_ctrls = '0;
      b_type_ctrls.alu_funct_sel = OP_ADD;                  //
      b_type_ctrls.op1_sel = 1'b1;                          //
      b_type_ctrls.op2_sel = 1'b1;                          //
      b_type_ctrls.rf_wr_en = 1'b0;                         //
      b_type_ctrls.data_req = 1'b0;                         //
    end 
      
    // - - - - - U-TYPE CONTROL SIGNAL GENERATION - - - - - // 
    always_comb begin
      u_type_ctrls = '0;
      u_type_ctrls.rf_wr_en = 1'b1;                         //
  
      // instruction based operand selection
      case (instr_opcode_i)
        
        LUI: begin
          u_type_ctrls.rf_wr_data_sel = IMM;  							//
        end
        
        AUIPC: begin
          u_type_ctrls.op1_sel = 1'b1;                      //
          u_type_ctrls.op2_sel = 1'b1;  										//
        end
        
        default: u_type_ctrls = '0;
      endcase
    end 
      
    // - - - - - J-TYPE CONTROL SIGNAL GENERATION - - - - - // 
    always_comb begin
      j_type_ctrls = '0;
      j_type_ctrls.alu_funct_sel = OP_ADD;                  //
      j_type_ctrls.op1_sel = 1'b1;                          //
      j_type_ctrls.op2_sel = 1'b1;                          //
      j_type_ctrls.data_req = 1'b0;                         //
      j_type_ctrls.pc_sel = 1'b1;                           //
      j_type_ctrls.rf_wr_en = 1'b1;                         //
      j_type_ctrls.rf_wr_data_sel = PC;                     //
    end
        
    // final output assignments - direct the type-appropriate controls to module output
    assign pc_sel_o = output_ctrls.pc_sel;
    assign op1sel_o = output_ctrls.op1_sel;
    assign op2sel_o = output_ctrls.op2_sel;
    assign alu_func_o = output_ctrls.alu_funct_sel;
    assign rf_wr_en_o = output_ctrls.rf_wr_en;
    assign rf_wr_data_o = output_ctrls.rf_wr_data_sel;
    assign data_req_o = output_ctrls.data_req;
    assign data_wr_o = output_ctrls.data_wr;
    assign data_byte_o = output_ctrls.data_byte;
    assign zero_extnd_o = output_ctrls.zero_extnd;
    
  endmodule
  
  // --------------------------------------------------------
  // Data Memory
  // --------------------------------------------------------
  
  module data_mem_interface (
    input   logic           clk,
    input   logic           reset_n,
  
    // Data request from current instruction
    input   logic           data_req_i,
    input   logic [31:0]    data_addr_i,
    input   logic [1:0]     data_byte_en_i,
    input   logic           data_wr_i,
    input   logic [31:0]    data_wr_data_i,
  
    input   logic           data_zero_extnd_i,
  
    // Read/Write request to memory
    output  logic           data_mem_req_o,
    output  logic  [31:0]   data_mem_addr_o,
    output  logic  [1:0]    data_mem_byte_en_o,
    output  logic           data_mem_wr_o,
    output  logic  [31:0]	  data_mem_wr_data_o,
    
    // Read data from memory
    input   logic [31:0]    mem_rd_data_i,
  
    // Data output
    output  logic [31:0]    data_mem_rd_data_o
  );
  
    // internal signal declarations for sign and zero extension
    logic [31:0] data_mem_rd_sign_extnd;
    logic [31:0] data_mem_rd_zero_extnd;
    
    // multiplexing to generate correct extensions based on byte enable signal
    always_comb begin
      case (data_byte_en_i) 
        BYTE: begin
          data_mem_rd_zero_extnd = {{24{1'b0}}, mem_rd_data_i[7:0]};
          data_mem_rd_sign_extnd = {{24{mem_rd_data_i[7]}}, mem_rd_data_i[7:0]};
        end HALF_WORD: begin
          data_mem_rd_zero_extnd = {{16{1'b0}}, mem_rd_data_i[15:0]};
          data_mem_rd_sign_extnd = {{16{mem_rd_data_i[15]}}, mem_rd_data_i[15:0]};
        end WORD: begin
          data_mem_rd_zero_extnd = mem_rd_data_i;
            data_mem_rd_sign_extnd = mem_rd_data_i;
        end default: begin
          data_mem_rd_zero_extnd = 0;
            data_mem_rd_sign_extnd = 0;
        end
      endcase
    end
          
    // output assignments that directly interface to the memory unit
    assign data_mem_req_o = data_req_i;
    assign data_mem_addr_o = data_addr_i;
    assign data_mem_byte_en_o = data_byte_en_i;
    assign data_mem_wr_o = data_wr_i;
    assign data_mem_wr_data_o = data_wr_data_i;
  
    // based on the sign-extension input, load the proper destination reg output
    assign data_mem_rd_data_o = data_zero_extnd_i ? data_mem_rd_zero_extnd : data_mem_rd_sign_extnd;
  
  endmodule
  
  module data_mem #(
      parameter DMEM_WORDS = 1024
  )(
    input   logic          clk,
    input   logic          reset_n,
    input   logic          data_mem_req_i,
    input   logic [31:0]   data_mem_addr_i,
    input   logic [1:0]    data_mem_byte_en_i,
    input   logic          data_mem_wr_i,
    input   logic [31:0]   data_mem_wr_data_i,
    input   logic          data_mem_zero_extnd_i,
    output  logic [31:0]   data_mem_rd_data_o
  );
  
      // macros defined in riscv_pkg for byte_en
      typedef enum logic [1:0] {
          BYTE,
          HALF_WORD,
          RESERVED,
          WORD
      } mem_access_size_t;
  
      // data memory array
      logic [DMEM_WORDS - 1 : 0] [31:0] data_mem_array;
  
      // registered read data
      logic [31:0] read_data;
      logic [7:0] extracted_byte;
  
      // decode the address into the byte offset and word address
      logic [$clog2(DMEM_WORDS) - 1:0] word_address; 
      logic [1:0] byte_offset;
  
      // continuous assignment for the address decoding
      assign word_address = data_mem_addr_i[31:2];
      assign byte_offset = data_mem_addr_i[1:0];
  
      // sequential logic for read/write behavior
      always_ff @(posedge clk or negedge reset_n) begin
          if (!reset_n) begin
              data_mem_array <= '0;
          
          // memory access condition
          end else if (data_mem_req_i) begin
              
              // write case
              if (data_mem_wr_i) begin
  
                  // write size and address determination
                  case (data_mem_byte_en_i)
  
                      // byte write case handling
                      BYTE: begin
                          case (byte_offset)
                              2'b00:   data_mem_array[word_address][7:0]   <= data_mem_wr_data_i[7:0];
                              2'b01:   data_mem_array[word_address][15:8]  <= data_mem_wr_data_i[7:0];
                              2'b10:   data_mem_array[word_address][23:16] <= data_mem_wr_data_i[7:0];
                              2'b11:   data_mem_array[word_address][31:24] <= data_mem_wr_data_i[7:0];
                          endcase
                      end
  
                      // half-word write case handling
                      HALF_WORD: begin
                          case (byte_offset[1])
                              1'b0:    data_mem_array[word_address][15:0]  <= data_mem_wr_data_i[15:0];
                              1'b1:    data_mem_array[word_address][31:16] <= data_mem_wr_data_i[15:0];
                          endcase
                      end
  
                      // word write - simple case
                      WORD: begin
                          data_mem_array[word_address] <= data_mem_wr_data_i;
                      end
                  endcase
              end
                  
              // read case handling (memory request but no write enabled)
              read_data <= data_mem_array[word_address];
          end
      end
  
      // combinatorial logic for extracting correct bytes from read data
      always_comb begin
        if (!data_mem_req_i) begin
          data_mem_rd_data_o = 32'b0;
        end else begin
            case (data_mem_byte_en_i)
  
                // byte access handling - depends on zero extension input
                BYTE: begin
                    if (data_mem_zero_extnd_i) begin
                        data_mem_rd_data_o = {24'b0, extracted_byte};
                    end else begin
                        data_mem_rd_data_o = {{24{extracted_byte[7]}}, extracted_byte};
                    end
                end
  
                // half word access handling - depends on zero extension input
                HALF_WORD: begin
                    if (data_mem_zero_extnd_i) begin
                        data_mem_rd_data_o = byte_offset[1] ? {16'b0, read_data[31:16]} : {16'b0, read_data[15:0]};
                    end else begin
                        data_mem_rd_data_o = byte_offset[1] ? {{16{read_data[31]}}, read_data[31:16]} : {{16{read_data[15]}}, read_data[15:0]};
                    end
                end
  
                // for full word, don't differentiate between zero and sign extended data
                WORD: data_mem_rd_data_o = read_data;
  
                // default to 0 output assignment
                default: data_mem_rd_data_o = '0;
            endcase
        end
      end
  
      // single byte selection block
      always_comb begin
          case (byte_offset)
              2'b00: extracted_byte = read_data[7:0];
              2'b01: extracted_byte = read_data[15:8];
              2'b10: extracted_byte = read_data[23:16];
              2'b11: extracted_byte = read_data[31:24];
              default: extracted_byte = '0; 
          endcase
      end
  endmodule
  
  // - - - - - DECODE - - - - - //
  // 
  // 
  
  module decode (
    input   logic [31:0]  instr_i,
    output  logic [4:0]   rs1_o,
    output  logic [4:0]   rs2_o,
    output  logic [4:0]   rd_o,
    output  logic [6:0]   op_o,
    output  logic [2:0]   funct3_o,
    output  logic [6:0]   funct7_o,
    output  logic         r_type_instr_o,
    output  logic         i_type_instr_o,
    output  logic         s_type_instr_o,
    output  logic         b_type_instr_o,
    output  logic         u_type_instr_o,
    output  logic         j_type_instr_o,
    output  logic [31:0]  instr_imm_o
  );
    
    // signal declaration for type-dependent immediates and flags
    logic [31:0] instr_imm;
    logic r_type;
    logic i_type;
    logic s_type;
    logic b_type;
    logic u_type;
    logic j_type;
    
    // output flag logic
    always_comb begin
      r_type = 1'b0;
      i_type = 1'b0;
      s_type = 1'b0;
      b_type = 1'b0;
      u_type = 1'b0;
      j_type = 1'b0;
        instr_imm = 32'b0;
      
      // assert the indicator bit and extract immediate accordingly
      case (instr_i[6:0])
        R_TYPE: begin
          r_type = 1'b1;	
            instr_imm = 32'b0;
        end
        I_TYPE0, I_TYPE1, I_TYPE2: begin
          i_type = 1'b1;
            instr_imm = {{20{instr_i[31]}}, instr_i[31:20]};
        end
        S_TYPE: begin
          s_type = 1'b1;
            instr_imm = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        end
        B_TYPE: begin
          b_type = 1'b1;
          instr_imm = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
        end
        U_TYPE0, U_TYPE1: begin
          u_type = 1'b1;
            instr_imm = {{instr_i[31:12]}, 12'b0};
        end
        J_TYPE: begin
          j_type = 1'b1;
            instr_imm = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
        end
        default: 
          instr_imm = 32'b0;
      endcase
    end
  
    // instruction field assignments
    assign op_o = 			instr_i[6:0];
    assign rd_o = 			instr_i[11:7];
    assign funct3_o =		 	instr_i[14:12];
    assign rs1_o = 			instr_i[19:15];
    assign rs2_o = 			instr_i[24:20];
    assign funct7_o = 		instr_i[31:25];
      
    // type flag assignments
    assign r_type_instr_o = 	r_type;
    assign i_type_instr_o = 	i_type;
    assign s_type_instr_o = 	s_type;
    assign b_type_instr_o = 	b_type;
    assign u_type_instr_o = 	u_type;
    assign j_type_instr_o = 	j_type;
    
    // immediate assignments
    assign instr_imm_o = 		instr_imm;
  endmodule
  
  // - - - - - FETCH - - - - - //
  // 
  // 
  
  module fetch (
    input    logic          clk,
    input    logic          reset_n,
  
    output   logic          instr_mem_req_o,          // signal to request the next instruction
    input    logic [31:0]   instr_mem_pc_i,           // current pc value (points to next insntruction to execute)
    output   logic [31:0]   instr_mem_addr_o,         // desired address of next instruction to execute
    input    logic [31:0]   mem_rd_data_i,            // instruction stored in imem at next pc value
    output   logic [31:0]   instr_mem_instr_o         // the instruction we are sending to decode
  );
  
    // registred instruction request
    logic instr_mem_req_q;
    
    // sequential logic block to register request
    always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
        instr_mem_req_q <= 1'b0;
      end else begin
        instr_mem_req_q <= 1'b1;
      end
    end
    
    // combinatorial fetching logic
    assign instr_mem_req_o = instr_mem_req_q;
    assign instr_mem_instr_o = mem_rd_data_i;
    assign instr_mem_addr_o = instr_mem_pc_i;
  
  endmodule
  
  module instr_mem #(
      parameter IMEM_WORDS = 1024
  )(
      input logic         clk,
      input logic         reset_n,
      input logic         instr_mem_req_i,
      input [31:0]        instr_mem_addr_i,
      output [31:0]       instr_mem_data_o
  );
  
      // the memory array itself (4kB)
      logic [IMEM_WORDS - 1 : 0] [31:0] instr_mem_array;
  
      // return instructions on the same cycle that they are requested
      assign instr_mem_data_o = instr_mem_req_i ? instr_mem_array[instr_mem_addr_i[31:2]] : '0;
  
  endmodule
  
  // - - - - - REGISTER FILE - - - - - //
  // 
  // 
  
  module regfile (
    input   logic          clk,															// synchronizing clock
    input   logic          reset_n,													// negative-edge triggered reset
  
    input   logic [4:0]    rs1_addr_i,											// source 1 register address
    input   logic [4:0]    rs2_addr_i,											// source 2 register address
    input   logic [4:0]    rd_addr_i,												// destination register address
  
    input   logic          wr_en_i,													// write enable signal
    input   logic [31:0]   wr_data_i,												// data to be written into the regfile
  
    output  logic [31:0]   rs1_data_o,											// register 1 read data
    output  logic [31:0]   rs2_data_o												// register 2 read data
  );
  
      // the actual 2D array of flip-flops
    logic [31:0] regfile [31:0];
    
    // sequential block for handling writes and resets
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
        for (int i = 0; i < 31; i++) begin
          regfile[i] <= 0;
        end
      end else if (wr_en_i && (rd_addr_i != 0)) begin
          regfile[rd_addr_i] <= wr_data_i;
      end
    end
        
      // comibinatorial assignment for same-cycle reads
    always_comb begin
      rs1_data_o = regfile[rs1_addr_i];
      rs2_data_o = regfile[rs2_addr_i];
    end
  
  endmodule
  
  // - - - - - RISC-V SINGLE CYCLE CORE: TOP - - - - - //
  //
  // Top level integration of all of the submodules in the single cycle core,
  // which includes the following:
  // 
  // regfile.sv - 
  // fetch.sv - 
  // dcode.sv -
  // alu.sv - 
  // 
  
  module rv32i_core #(
    parameter RESET_PC = 32'h0
  )(
    input   logic          clk,
    input   logic          reset_n,
  
    // instruction memory interface
    output  logic          instr_mem_req_o,
    output  logic [31:0]   instr_mem_addr_o,
    input   logic [31:0]   instr_mem_rd_data_i,
  
    // data memory interface
    output  logic          data_mem_req_o,
    output  logic [31:0]   data_mem_addr_o,
    output  logic [1:0]    data_mem_byte_en_o,
    output  logic          data_mem_zero_extnd_o,
    output  logic          data_mem_wr_o,
    output  logic [31:0]   data_mem_wr_data_o,
    input   logic [31:0]   data_mem_rd_data_i
  
  );
  
    // - - - - - - - - - - - - - - - - - - - - - - - - //
    // - - - - - INTERNAL SIGNAL DECLARATION - - - - - //
    // - - - - - - - - - - - - - - - - - - - - - - - - //
  
    // needed for reset handling
    logic reset_observed;                               // registers initial reset
  
    // first needed in PC logic
    logic [31:0] pc;                                    // the program counter that addresses the IMEM
    logic [31:0] pc_next;                               // the next pc value (either branch target or pc + 4)
    logic [31:0] next_instr_pc;                         // address of then ext instruction in the program (pc + 4)
  
    // first needed at fetch
    logic [31:0] instr_curr;                            // instruction in IMEM at the address indexed by PC 
  
    // first needed at decode
    logic [4:0] rs1_addr;                               // address of rs1
    logic [4:0] rs2_addr;                               // address of rs2
    logic [4:0] rd_addr;                                // address of rd
    logic [6:0] op_code;                                // instruction op code
    logic [2:0] funct3;                                 // funct3 field of instruction
    logic [6:0] funct7;                                 // funct7 field of instruction
    logic [31:0] instr_imm;                             // instructions imediate field
    logic r_type;                                       // one-hot R-type indicator
    logic i_type;                                       // one-hot I-type indicator
    logic s_type;                                       // one-hot S-type indicator
    logic b_type;                                       // one-hot B-type indicator
    logic u_type;                                       // one-hot U-type indicator
    logic j_type;                                       // one-hot J-type indicator
  
    // first needed at execute
    logic [31:0] alu_src_1;                             // hooked to the output of operand 1 multiplexor
    logic [31:0] alu_src_2;                             // hooked to the output of operand 2 multiplexor
    logic [31:0] alu_result;                            // used as input to regfile writeback data sel multiplexor
  
    // used in register file
    logic rf_wr_en;                                     // indicates whether the RF is being written to
    logic [31:0] rf_wr_data;                            // data to be written to the RF
    logic [31:0] rs1_data;                              // contents of rs1
    logic [31:0] rs2_data;                              // contents of rs2
  
    // first needed in control unit
    logic pc_sel;                                       // multiplexing for next PC value determination
    logic op1_sel;                                      // decides whether op1 is rs1 or current PC 
    logic op2_sel;                                      // decides whether op2 is rs2 or immediate
    logic [3:0] alu_op_sel;                             // ALU opertion select signal
    logic ctrl_to_dmem_req;
  
    // first needed in branch control unit
    logic branch_taken;
    logic ctrl_to_dmem_wr;
    logic [1:0] data_byte;
    logic [1:0] rf_wb_data_sel;
  
    // first needed in memory interface
    logic [31:0] dmem_data;
  
    // - - - - - - - - - - - - - - - - - //
    // - - - - CPU CORE INSTANCE - - - - //
    // - - - - - - - - - - - - - - - - - //
  
    // - - - - - INITIALIZATION RESET HANDLING - - - - - //
    always_ff @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
        reset_observed <= 1'b0;
      end else begin
        reset_observed <= 1'b1;
      end
    end
  
    // - - - - - PROGRAM COUNTER - - - - - //
    always_ff @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
        pc <= RESET_PC;
      end else if (reset_observed) begin
        pc <= pc_next;
      end 
    end
  
    // logic to determine next pc based on branch control outputs
    assign next_instr_pc = pc + 32'h4;
    assign pc_next = (branch_taken | pc_sel) ? alu_result : next_instr_pc;
  
      // - - - - - REGISTER FILE - - - - - //
    regfile u_regfile (
      .clk                      (clk),
      .reset_n                  (reset_n),
      .rs1_addr_i               (rs1_addr),
      .rs2_addr_i               (rs2_addr),
      .rd_addr_i                (rd_addr),
      .wr_en_i                  (rf_wr_en),
      .wr_data_i                (rf_wr_data),
      .rs1_data_o               (rs1_data),
      .rs2_data_o               (rs2_data)
    );
  
    // multiplexing logic for regfile data write selection (.wr_data_i)
    always_comb begin
      case(rf_wb_data_sel) 
        ALU: rf_wr_data = alu_result;
        MEM: rf_wr_data = dmem_data;
        IMM: rf_wr_data = instr_imm;
        PC:  rf_wr_data = next_instr_pc;
        default: rf_wr_data = '0;
      endcase
    end
  
    // - - - - - FETCH - - - - - //
    fetch u_fetch (
      .clk                      (clk),
      .reset_n                  (reset_n),
      .instr_mem_pc_i           (pc),
      .instr_mem_req_o          (instr_mem_req_o),
      .instr_mem_addr_o         (instr_mem_addr_o),
      .mem_rd_data_i            (instr_mem_rd_data_i),
      .instr_mem_instr_o        (instr_curr)
    );
  
      // - - - - - DECODE - - - - - // 
    decode u_decode (
      .instr_i                  (instr_curr),
      .rs1_o                    (rs1_addr),
      .rs2_o                    (rs2_addr),
      .rd_o                     (rd_addr),
      .op_o                     (op_code),
      .funct3_o                 (funct3),
      .funct7_o                 (funct7),
      .r_type_instr_o           (r_type),
      .i_type_instr_o           (i_type),
      .s_type_instr_o           (s_type),
      .b_type_instr_o           (b_type),
      .u_type_instr_o           (u_type),
      .j_type_instr_o           (j_type),
      .instr_imm_o              (instr_imm)
    );
  
    //  - - - - - EXECUTE (ALU) - - - - - //
    alu u_alu (
      .opr_a_i                  (alu_src_1),
      .opr_b_i                  (alu_src_2),
      .op_sel_i                 (alu_op_sel),
      .alu_res_o                (alu_result)
    );
  
    // execution stage multiplexing logic
    assign alu_src_1 = op1_sel ? pc : rs1_data;
    assign alu_src_2 = op2_sel ? instr_imm : rs2_data;
    
    // - - - - - CONTROL UNIT - - - - - //
    ctrl_unit u_ctrl_unit (
      .instr_funct3_i           (funct3),
      .instr_funct7_bit5_i      (funct7[5]),
      .instr_opcode_i           (op_code),
      .is_r_type_i              (r_type),
      .is_i_type_i              (i_type),
      .is_s_type_i              (s_type),
      .is_b_type_i              (b_type),
      .is_u_type_i              (u_type),
      .is_j_type_i              (j_type),
      .pc_sel_o                 (pc_sel),
      .op1sel_o                 (op1_sel),
      .op2sel_o                 (op2_sel),
      .data_req_o               (ctrl_to_dmem_req),
      .data_wr_o                (ctrl_to_dmem_wr),
      .data_byte_o              (data_byte),
      .zero_extnd_o             (data_mem_zero_extnd_o),
      .rf_wr_en_o               (rf_wr_en),
      .rf_wr_data_o             (rf_wb_data_sel),
      .alu_func_o               (alu_op_sel)
    );
  
    //  - - - - - BRANCH CONTROL UNIT - - - - - //
    branch_ctrl u_branch_ctrl (
      .opr_a_i                  (rs1_data),
      .opr_b_i                  (rs2_data),
      .is_b_type_ctl_i          (b_type),
      .instr_func3_ctl_i        (funct3),
      .branch_taken_o           (branch_taken)
    );
  
    //  - - - - - DATA MEMORY INTERFACE - - - - - //
    data_mem_interface u_data_mem_interface (
      .clk                      (clk),
      .reset_n                  (reset_n),
      .data_req_i               (ctrl_to_dmem_req),
      .data_addr_i              (alu_result),
      .data_byte_en_i           (data_byte),
      .data_wr_i                (ctrl_to_dmem_wr),
      .data_wr_data_i           (rs2_data),
      .data_zero_extnd_i        (data_mem_zero_extnd_o),
      .data_mem_req_o           (data_mem_req_o),
      .data_mem_addr_o          (data_mem_addr_o),
      .data_mem_byte_en_o       (data_mem_byte_en_o),
      .data_mem_wr_o            (data_mem_wr_o),
      .data_mem_wr_data_o       (data_mem_wr_data_o),
      .mem_rd_data_i            (data_mem_rd_data_i),
      .data_mem_rd_data_o       (dmem_data)
    );
  
  endmodule
  
  module top (
      input logic         clk,
      input logic         reset_n
  );
  
      // - - - - - - - - - - - - - - - - - - - - - - - - //
      // - - - - - INTERNAL SIGNAL DECLARATION - - - - - //
      // - - - - - - - - - - - - - - - - - - - - - - - - //
  
      // instruction memory <-> rv32i core
      logic instr_mem_req;
      logic [31:0] instr_mem_addr;
      logic [31:0] instr_mem_data;
  
      // data memory <-> rv32i core
      logic data_mem_req;
      logic data_mem_wr;
      logic data_mem_zero_extnd;
      logic [1:0] data_mem_byte_en;
      logic [31:0] data_mem_wr_data;
      logic [31:0] data_mem_addr;
      logic [31:0] data_mem_rd_data;
  
      // - - - - - - - - - - - - - - - - - - - - - - - - //
      // - - - - - - - TOP LEVEL INTEGRATION - - - - - - //
      // - - - - - - - - - - - - - - - - - - - - - - - - //
  
      // - - - - - RISC-V CORE INSTANCE - - - - - //
      rv32i_core RV32I (
          .clk                        (clk), 
          .reset_n                    (reset_n),
          .instr_mem_req_o            (instr_mem_req),
          .instr_mem_addr_o           (instr_mem_addr),
          .instr_mem_rd_data_i        (instr_mem_data),
          .data_mem_req_o             (data_mem_req),
          .data_mem_addr_o            (data_mem_addr),
          .data_mem_wr_o              (data_mem_wr),
          .data_mem_wr_data_o         (data_mem_wr_data),
          .data_mem_byte_en_o         (data_mem_byte_en),
          .data_mem_zero_extnd_o      (data_mem_zero_extnd),
          .data_mem_rd_data_i         (data_mem_rd_data)
      );
  
      // - - - - - INSTRUCTION MEMORY INSTANCE - - - - - //
      instr_mem IMEM (
          .clk                        (clk),
          .reset_n                    (reset_n),
          .instr_mem_req_i            (instr_mem_req),
          .instr_mem_addr_i           (instr_mem_addr),
          .instr_mem_data_o           (instr_mem_data)
      );
  
      // - - - - - INSTRUCTION MEMORY INSTANCE - - - - - //
      data_mem DMEM (
          .clk                        (clk),
          .reset_n                    (reset_n),
          .data_mem_req_i             (data_mem_req),
          .data_mem_addr_i            (data_mem_addr),
          .data_mem_wr_i              (data_mem_wr),
          .data_mem_wr_data_i         (data_mem_wr_data),
          .data_mem_byte_en_i         (data_mem_byte_en),
          .data_mem_zero_extnd_i      (data_mem_zero_extnd),
          .data_mem_rd_data_o         (data_mem_rd_data)
      );
  
  endmodule