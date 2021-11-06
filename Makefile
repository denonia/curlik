all: curlik.o curlik

curlik.o: curlik.asm
	nasm -f elf64 -o curlik.o curlik.asm

curlik: curlik.o
	gcc curlik.o -no-pie -o curlik -lcurl

clean:
	rm curlik.o curlik
	
run: curlik
	./curlik

