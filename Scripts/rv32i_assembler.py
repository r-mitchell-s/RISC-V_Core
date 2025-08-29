import re
import sys

##############################################################################
# The main program... which is an assembler... for RV32I... 
##############################################################################
def main():

    # input and output file
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # initialize empty list to dump machine code into output file
    machine_code = []

    # clean the asm file for parsing
    clean_instructions = cleaner(input_file)
    
    # parse each line in the asm file, construct the hex instruction, and print it out
    for instruction in clean_instructions:
        parsed_instruction = parse_instruction(instruction)
        encoded_instruction = encode_instruction(parsed_instruction)
        machine_code.append(encoded_instruction)
        print(encoded_instruction)

    # write all of the machine code to the output file
    with open(output_file, 'w') as outfile:
        for instr in machine_code:
            outfile.write(instr + '\n')

##############################################################################
#  Cleans the input .asm file of comments and whitespace
##############################################################################
def cleaner(input_file):

    # read the lines from the asm file
    with open(input_file, 'r') as file:

        # extract the lines into a list
        lines = file.readlines()

    # for storing the cleaned up program
    clean_lines = []

    # erase comments to acquire oure RV32I asm
    for line in lines:

        # get rid of whitespace
        clean_line = line.strip()

        # get rid of empty lines and comment lines
        if not clean_line or clean_line.startswith('#'):
            continue

        # remove comments from the end of the line
        if '#' in clean_line:
            clean_line = clean_line[:clean_line.index('#')].strip()

        # add to the program
        if clean_line:
            clean_lines.append(clean_line)

    # return the cleaned program (no comments and no blank lines)
    return clean_lines


##############################################################################
# Parser to identify the instruction fieldsbased on its op-type
##############################################################################
def parse_instruction(instruction):

    # establish the instruction table
    (r_type, i_type, l_type, s_type, b_type, u_type, j_type) = setup_instruction_tables()

    # remove commas from the instruction
    instr = instruction.replace(',', '').split()

    # acquire the op-type
    opcode = instr[0].lower()

    # r-type parsing
    if opcode in r_type:
        parsed_instr = {
            'type'   : 'R',
            'opcode' : instr[0],
            'rd'     : instr[1],
            'rs1'    : instr[2],
            'rs2'    : instr[3]
        }
        return parsed_instr

    # i-type parsing
    elif opcode in i_type:
        parsed_instr = {
            'type'   : 'I',
            'opcode' : instr[0],
            'rd'     : instr[1],
            'rs1'    : instr[2],
            'imm'    : instr[3]
        }

        return parsed_instr

    # s-type parsing
    elif opcode in s_type:

        # isolate the immediate offset and base register for store adddress
        offset_reg = instr[2]
        match = re.match(r'(-?\d+)\((\w+)\)', offset_reg)

        # grab base and offset
        offset = match.group(1)
        base_reg = match.group(2)

        parsed_instr = {
            'type'   : 'S',
            'opcode' : instr[0],
            'rs2'     : instr[1],
            'rs1'    : base_reg,
            'imm'    : offset
        }

        return parsed_instr

    # l-type parsing
    elif opcode in l_type:

        # isolate the immediate offset and base register for store adddress
        offset_reg = instr[2]
        match = re.match(r'(-?\d+)\((\w+)\)', offset_reg)

        # grab base and offset
        offset = match.group(1)
        base_reg = match.group(2)

        parsed_instr = {
            'type'   : 'L',
            'opcode' : instr[0],
            'rd'     : instr[1],
            'rs1'    : base_reg,
            'imm'    : offset
        }

        return parsed_instr

    # b-type parsing
    elif opcode in b_type:
        parsed_instr = {
            'type'   : 'B',
            'opcode' : instr[0],
            'rs1'     : instr[1],
            'rs2'    : instr[2],
            'imm'    : instr[3]
        }

        return parsed_instr
    
    # u-type parsing
    elif opcode in u_type:
        parsed_instr = {
            'type'   : 'U',
            'opcode' : instr[0],
            'rd'     : instr[1],
            'imm'    : instr[2]
        }

        return parsed_instr

    # j-type parsing
    elif opcode in j_type:

        if opcode == "jal":
            
            if len(instr) == 2:
                parsed_instr = {
                    'type': 'J',
                    'opcode': instr[0],
                    'rd': 'x1',   
                    'imm': instr[1]
                }

            elif len(instr) == 3:

                parsed_instr = {
                    'type': 'J',
                    'opcode': instr[0],
                    'rd': instr[1],   
                    'imm': instr[2]
                }

        elif opcode == "jalr":
            
            if len(instr) == 3:
                # Format: jalr rd, rs1 (offset = 0 implicit)
                parsed_instr = {
                    'type': 'JALR',
                    'opcode': instr[0],
                    'rd': instr[1],
                    'rs1': instr[2],
                    'imm': '0'
                }
            elif len(instr) == 4:
                # Format: jalr rd, rs1, offset
                parsed_instr = {
                    'type': 'JALR',
                    'opcode': instr[0], 
                    'rd': instr[1],
                    'rs1': instr[2],
                    'imm': instr[3]
                }

        return parsed_instr

    # invalid instruction given
    else:
        return None

##############################################################################
# Encoding function to take the parsed instruction and produce machine code
##############################################################################
def encode_instruction(parsed_instr):

    # set up the tables on which ecncodings depend
    (r_type_encodings, i_type_encodings, l_type_encodings, s_type_encodings, b_type_encodings, u_type_encodings, j_type_encodings) = setup_encoding_tables()
    (r_type_instructions, i_type_instructions, l_type_instructions, s_type_instructions, b_type_instructions, u_type_instructions, j_type_instructions) = setup_instruction_tables()

    # handle encoding from parsed r-type to machine code
    if parsed_instr['opcode'] in r_type_instructions:
        
        # acquire all of the instruction fields
        function_fields = r_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        funct3 = function_fields['funct3']
        funct7 = function_fields['funct7']
        rd = register_to_number(parsed_instr['rd'])
        rs1 = register_to_number(parsed_instr['rs1'])
        rs2 = register_to_number(parsed_instr['rs2'])

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    # i-type instruction encoding scheme
    elif parsed_instr['opcode'] in i_type_instructions:

        # acquire all of the instruction fields
        function_fields = i_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        funct3 = function_fields['funct3']
        rd = register_to_number(parsed_instr['rd'])
        rs1 = register_to_number(parsed_instr['rs1'])
        imm = int(parsed_instr['imm'])

        # special handling for shift instructions
        if parsed_instr['opcode'] == 'slli':
            imm = imm & 0x1F                                # Keep only 5 bits for shift amount
        elif parsed_instr['opcode'] == 'srli':
            imm = imm & 0x1F                                # Keep only 5 bits for shift amount  
        elif parsed_instr['opcode'] == 'srai':
            imm = (imm & 0x1F) | 0x400                      # Set bit 10 for arithmetic shift

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    # l-type instruction encoding scheme
    elif parsed_instr['opcode'] in l_type_instructions:

        # acquire all of the instruction fields
        function_fields = l_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        funct3 = function_fields['funct3']
        rd = register_to_number(parsed_instr['rd'])
        rs1 = register_to_number(parsed_instr['rs1'])
        imm = int(parsed_instr['imm'])

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    # s-type instruction encoding scheme
    elif parsed_instr['opcode'] in s_type_instructions:

        # acquire all of the instruction fields
        function_fields = s_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        funct3 = function_fields['funct3']
        rs1 = register_to_number(parsed_instr['rs1'])
        rs2 = register_to_number(parsed_instr['rs2'])
        imm = int(parsed_instr['imm'])

        # split the immediate for encoding
        imm_11_5 = (imm >> 5) & 0x7F
        imm_4_0 = imm & 0x1F

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    # b-type instruction handling
    elif parsed_instr['opcode'] in b_type_instructions:

        # acquire all of the instruction fields
        function_fields = b_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        funct3 = function_fields['funct3']
        rs1 = register_to_number(parsed_instr['rs1'])
        rs2 = register_to_number(parsed_instr['rs2'])
        imm = int(parsed_instr['imm'])

        # split the immediate for encoding
        imm_12 = (imm >> 12) & 0x1
        imm_11 = (imm >> 11) & 0x1
        imm_10_5 = (imm >> 5) & 0x3F 
        imm_4_1 = (imm >> 1) & 0xF

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    # u-type encoding scheme
    elif parsed_instr['opcode'] in u_type_instructions:

        # acquire all of the instruction fields
        function_fields = u_type_encodings[parsed_instr['opcode']]
        op = function_fields['opcode']
        rd = register_to_number(parsed_instr['rd'])
        imm = int(parsed_instr['imm'])

        # assemble the machine code instruction from instruction field data
        encoded_instruction = (imm << 12) | (rd << 7) | op

        # sorted machine code ready
        return f"{encoded_instruction & 0xFFFFFFFF:08x}"
    
    # j-type encoding scheme
    elif parsed_instr['opcode'] in j_type_instructions:

        # divide into the two possible j instructions
        if parsed_instr['opcode'] == 'jal':

            # acquire jal fields
            function_fields = j_type_encodings[parsed_instr['opcode']]
            op = function_fields['opcode']
            rd = register_to_number(parsed_instr['rd'])
            imm = int(parsed_instr['imm'])

             # split the immediate for J-type encoding
            imm_20 = (imm >> 20) & 0x1      
            imm_19_12 = (imm >> 12) & 0xFF     
            imm_11 = (imm >> 11) & 0x1          
            imm_10_1 = (imm >> 1) & 0x3FF      
            
            # assemble the machine code instruction
            encoded_instruction = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | op

            return f"{encoded_instruction & 0xFFFFFFFF:08x}"

        # jalr handling
        elif parsed_instr['opcode'] == 'jalr':

            # acquire jalr fields
            function_fields = j_type_encodings[parsed_instr['opcode']]
            op = function_fields['opcode']
            funct3 = function_fields['funct3']
            rd = register_to_number(parsed_instr['rd'])
            rs1 = register_to_number(parsed_instr['rs1'])
            imm = int(parsed_instr['imm'])

            # assemble the machine code instruction (much simpler than jal lol)
            encoded_instruction = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op
            
            # we done
            return f"{encoded_instruction & 0xFFFFFFFF:08x}"

    else:
        print("ERROR: Invalid instruction provided.")



##############################################################################
# dictionaries to link instruction names to their types
##############################################################################
def setup_instruction_tables():
    
    # R-type: rd, rs1, rs2
    r_type_instructions = {
        'add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'
    }
    
    # I-type: rd, rs1, immediate
    i_type_instructions = {
        'addi', 'slti', 'sltiu', 'xori', 'ori', 'andi', 'slli', 'srli', 'srai'
    }
    
    # I-type loads: rd, offset(rs1)  
    l_type_instructions = {
        'lb', 'lh', 'lw', 'lbu', 'lhu'
    }
    
    # S-type: rs2, offset(rs1)
    s_type_instructions = {
        'sb', 'sh', 'sw'
    }
    
    # B-type: rs1, rs2, label/offset
    b_type_instructions = {
        'beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'
    }
    
    # U-type: rd, immediate
    u_type_instructions = {
        'lui', 'auipc'
    }
    
    # J-type: rd, label/offset (or just label for jal)
    j_type_instructions = {
        'jal', 'jalr'
    }
    
    return (r_type_instructions, i_type_instructions, l_type_instructions, s_type_instructions, b_type_instructions, u_type_instructions, j_type_instructions)

##############################################################################
# dictionaries to link register names to their indices
##############################################################################
def register_to_number(reg_name):
    register_map = {
        'x0': 0, 'zero': 0,
        'x1': 1, 'ra': 1,
        'x2': 2, 'sp': 2,
        'x3': 3, 'gp': 3,
        'x4': 4, 'tp': 4,
        'x5': 5, 't0': 5,
        'x6': 6, 't1': 6,
        'x7': 7, 't2': 7,
        'x8': 8, 's0': 8, 'fp': 8,
        'x9': 9, 's1': 9,
        'x10': 10, 'a0': 10,
        'x11': 11, 'a1': 11,
        'x12': 12, 'a2': 12,
        'x13': 13, 'a3': 13,
        'x14': 14, 'a4': 14,
        'x15': 15, 'a5': 15,
        'x16': 16, 'a6': 16,
        'x17': 17, 'a7': 17,
        'x18': 18, 's2': 18,
        'x19': 19, 's3': 19,
        'x20': 20, 's4': 20,
        'x21': 21, 's5': 21,
        'x22': 22, 's6': 22,
        'x23': 23, 's7': 23,
        'x24': 24, 's8': 24,
        'x25': 25, 's9': 25,
        'x26': 26, 's10': 26,
        'x27': 27, 's11': 27,
        'x28': 28, 't3': 28,
        'x29': 29, 't4': 29,
        'x30': 30, 't5': 30,
        'x31': 31, 't6': 31
    }
    
    # convert the regname from the parsed instruction
    reg_name = reg_name.lower()
    if reg_name in register_map:
        return register_map[reg_name]


##############################################################################
# dictionaries to link instruction names to their opcode and function fields
##############################################################################
def setup_encoding_tables():
    
    # R-type instructions: opcode, funct3, funct7
    r_type_encodings = {
        'add':  {'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x00},
        'sub':  {'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x20},
        'sll':  {'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x00},
        'slt':  {'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x00},
        'sltu': {'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x00},
        'xor':  {'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x00},
        'srl':  {'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x00},
        'sra':  {'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x20},
        'or':   {'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x00},
        'and':  {'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x00}
    }
    
    # I-type instructions: opcode, funct3
    i_type_encodings = {
        'addi':  {'opcode': 0x13, 'funct3': 0x0},
        'slti':  {'opcode': 0x13, 'funct3': 0x2},
        'sltiu': {'opcode': 0x13, 'funct3': 0x3},
        'xori':  {'opcode': 0x13, 'funct3': 0x4},
        'ori':   {'opcode': 0x13, 'funct3': 0x6},
        'andi':  {'opcode': 0x13, 'funct3': 0x7},
        'slli':  {'opcode': 0x13, 'funct3': 0x1},
        'srli':  {'opcode': 0x13, 'funct3': 0x5},
        'srai':  {'opcode': 0x13, 'funct3': 0x5}
    }
    
    # L-type instructions: opcode, funct3
    l_type_encodings = {
        'lb':  {'opcode': 0x03, 'funct3': 0x0},
        'lh':  {'opcode': 0x03, 'funct3': 0x1},
        'lw':  {'opcode': 0x03, 'funct3': 0x2},
        'lbu': {'opcode': 0x03, 'funct3': 0x4},
        'lhu': {'opcode': 0x03, 'funct3': 0x5}
    }
    
    # S-type instructions: opcode, funct3
    s_type_encodings = {
        'sb': {'opcode': 0x23, 'funct3': 0x0},
        'sh': {'opcode': 0x23, 'funct3': 0x1},
        'sw': {'opcode': 0x23, 'funct3': 0x2}
    }
    
    # B-type instructions: opcode, funct3
    b_type_encodings = {
        'beq':  {'opcode': 0x63, 'funct3': 0x0},
        'bne':  {'opcode': 0x63, 'funct3': 0x1},
        'blt':  {'opcode': 0x63, 'funct3': 0x4},
        'bge':  {'opcode': 0x63, 'funct3': 0x5},
        'bltu': {'opcode': 0x63, 'funct3': 0x6},
        'bgeu': {'opcode': 0x63, 'funct3': 0x7}
    }
    
    # U-type instructions: opcode
    u_type_encodings = {
        'lui':   {'opcode': 0x37},
        'auipc': {'opcode': 0x17}
    }
    
    # J-type instructions: opcode, funct3
    j_type_encodings = {
        'jal':  {'opcode': 0x6F},
        'jalr': {'opcode': 0x67, 'funct3': 0x0}
    }
    
    return (r_type_encodings, i_type_encodings, l_type_encodings, s_type_encodings, b_type_encodings, u_type_encodings, j_type_encodings)

if __name__ == "__main__":
    main()