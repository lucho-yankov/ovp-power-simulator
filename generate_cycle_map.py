import re

def parse_dis_line(line):
  stripped_comment_line = re.sub(r';.*$', '', line)
  parsed_line = re.match(r'^\s*([0-9a-f]+):\s*[0-9a-f]{4}(?:\s[0-9a-f]{4})?\s*\t([\w.]+)\s*(.*)$', stripped_comment_line)
  return parsed_line

def parse_dis_file(file_name):
  instructions = list()
  with open(file_name) as f:
    for line in f:
      parsed_line = parse_dis_line(line)
      if parsed_line is None or len(parsed_line.groups()) != 3:
        print "Error parsing line: ", line
      else:
        instructions.append(parsed_line.groups())
  return instructions
  
def store_table(table, file_name):
  with open(file_name, 'w') as f:
    for entry in table:
      f.write("%s:%d:%d\n" % entry)
  
def count_instruction_cycles(i):
  # based on data from: http://web.mit.edu/clarkds/www/Files/slides1.pdf
  branch = False

  if i[1] == 'muls':
    cycles = 32
  elif i[1] == 'pop':
    cycles = 1 + len(i[2].split(','))
    if 'pc' in i[2]:
      cycles += 3
  elif i[1] == 'push':
    cycles = 1 + len(i[2].split(','))
  elif i[1] in ('ldmia', 'stmia'):
    registers = re.search(r'({.*})', i[2]).group(1)
    cycles = 1 + len(registers.split(','))
  elif i[1] in ('bl', 'dmb', 'dsb', 'isb', 'msr', 'mrs'):
    cycles = 4
  elif i[2].startswith('pc'):
    cycles = 3
  elif i[1].startswith('b'):
    cycles = 1
    branch = True
  elif i[1].startswith('ldr') or i[1].startswith('str') or i[1] in ('wfe', 'wfi'):
    cycles = 2
  elif i[1] == '' or i[1] is None or 'illegal' in i[2]:
    cycles = 0
  else:
    cycles = 1
   
  return (i[0], cycles, branch)
  
def map_cycles(instructions):
  table = list()
  for i in instructions:
    branch = False
    
    instruction_cycles = count_instruction_cycles(i)
    
    if instruction_cycles[1] == 0:
      print "Unsupported instruction: ", i
      
    table.append(instruction_cycles)
    
  return table
      
if __name__ == '__main__':
  instructions = parse_dis_file('dis.b.asm')
  table = map_cycles(instructions)
  store_table(table, 'cycles_map.txt')