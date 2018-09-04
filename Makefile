# 目录变量
OBJ		= objects
BIN		= binaries

# 工具命令
ASM		= nasm
CXX		= g++
CC		= gcc
DD		= dd
BOCHS	= bochs
BOCHS_D	= ./tools/bochs-2.6.9/bin/bochs

.PHONY: all build debug run img clean clean-all refresh refresh-all prepare

all: prepare build
build: $(BIN)/boot/mbr.bin $(BIN)/boot/loader.bin
img: $(BIN)/hd60M.img
clean:
	-rm -f $(BIN)/boot/mbr.bin
	-rm -f $(BIN)/boot/loader.bin
clean-all: clean
refresh: clean build
refresh-all: clean-all build

prepare:
	mkdir -p $(OBJ)
	mkdir -p $(BIN)/boot

debug: $(BIN)/hd60M.img
	$(BOCHS_D) -q -f bochsrc

run: $(BIN)/hd60M.img
	$(BOCHS) -q -f bochsrc

# 磁盘映像文件
$(BIN)/hd60M.img: $(BIN)/boot/mbr.bin $(BIN)/boot/loader.bin
	$(DD) if=$(BIN)/boot/mbr.bin of=$@ bs=512 count=1 conv=notrunc
	$(DD) if=$(BIN)/boot/loader.bin of=$@ bs=512 seek=2 conv=notrunc

# MBR
$(BIN)/boot/mbr.bin: boot/mbr.S boot/boot.inc boot/printer.inc
	$(ASM) $< -o $@ -Iboot/

# Loader
$(BIN)/boot/loader.bin: boot/loader.S boot/boot.inc boot/printer.inc
	$(ASM) $< -o $@ -Iboot/
