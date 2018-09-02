# 目录变量
OBJ		= objects
BIN		= binaries

# 工具命令
ASM		= nasm
CXX		= g++
CC		= gcc
DD		= dd
BOCHS	= ./tools/bochs-2.6.9/bin/bochs

.PHONY: build run img clean clean-all refresh refresh-all prepare

build: prepare $(BIN)/boot/mbr.bin
img: $(BIN)/hd60M.img
clean:
	-rm -f $(BIN)/boot/mbr.bin
clean-all: clean
refresh: clean build
refresh-all: clean-all build

prepare:
	mkdir -p $(OBJ)
	mkdir -p $(BIN)/boot

run: $(BIN)/hd60M.img
	$(BOCHS) -f bochsrc

# 磁盘映像文件
$(BIN)/hd60M.img: $(BIN)/boot/mbr.bin
	$(DD) if=$< of=$@ bs=512 count=1 conv=notrunc

# MBR
$(BIN)/boot/mbr.bin: boot/mbr.S
	$(ASM) $^ -o $@
