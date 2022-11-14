RED    := '\033[0;31m'
YELLOW := '\033[0;33m'
NC     := '\033[0m'

files := out/main.o out/stdlib.o out/memory_manager.o

default:
	@echo -e no option specified

recompile: refresh inter 

refresh:
	@touch src/*

clear:
	@clear

#linking
inter: clear ${files}
	@echo -e ${RED}linking program${NC}
	@ld -o main ${files}

#assembling
out/main.o: src/main.asm
	@echo -e ${YELLOW}assembling main.asm${NC}
	@nasm -f elf64 src/main.asm
	@mv src/main.o out/

out/stdlib.o: src/stdlib.asm
	@echo -e ${YELLOW}assembling stdlib.asm${NC}
	@nasm -f elf64 src/stdlib.asm
	@mv src/stdlib.o out/

out/memory_manager.o: src/memory_manager.asm
	@echo -e ${YELLOW}assembling memory_manager.asm${NC}
	@nasm -f elf64 src/memory_manager.asm
	@mv src/memory_manager.o out/


#refreshing
src/main.asm:
	@touch src/main.asm
src/stdlib.asm:
	@touch src/stdlib.asm
src/memory_manager.asm:
	@touch src/memory_manager.asm


