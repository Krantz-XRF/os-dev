# 目录变量
OBJ		= objects
BIN		= binaries

# 参数选项
CXXFLAGS	= -std=c++17

# 工具命令
AS		= as --32
CXX		= g++ -c $(CXXFLAGS)
GXX		= g++
CC		= gcc
LD		= ld
DD		= dd
OBJCOPY	= objcopy
BOCHS	= bochs
BOCHS_D	= tools/bochs-2.6.9/bin/bochs

.PHONY: all build debug run img clean clean-all refresh refresh-all prepare

all: prepare build
build: $(BIN)/boot/mbr_s.bin $(BIN)/boot/loader.bin
img: $(BIN)/hd60M.img
clean:
	-rm -f $(BIN)/boot/mbr.bin
	-rm -f $(BIN)/boot/loader.bin
clean-all: clean
	-rm -f $(OBJ)/boot/*.o
	-rm -f $(OBJ)/boot/bits16/*.o
	-rm -f $(OBJ)/helper/*.o
	-rm -f $(OBJ)/*.o
refresh: clean build
refresh-all: clean-all build

prepare:
	mkdir -p $(OBJ)/boot/bits16
	mkdir -p $(BIN)/boot
	mkdir -p $(OBJ)/helper
	mkdir -p $(BIN)/helper

debug: $(BIN)/hd60M.img
	$(BOCHS_D) -q -f bochsrc

run: $(BIN)/hd60M.img
	$(BOCHS) -q -f bochsrc

# 磁盘映像文件
$(BIN)/hd60M.img: $(BIN)/boot/mbr_s.bin $(BIN)/boot/loader.bin
	$(DD) if=$(BIN)/boot/mbr_s.bin of=$@ bs=512 count=1 conv=notrunc
	$(DD) if=$(BIN)/boot/loader.bin of=$@ bs=512 seek=1 conv=notrunc

# Printer16
$(OBJ)/boot/bits16/printer.o: boot/bits16/printer.S
	$(AS) $< -o $@

# DiskRead16
$(OBJ)/boot/bits16/read_disk.o: boot/bits16/read_disk.S
	$(AS) $< -o $@

# MBR 签名生成工具
$(BIN)/helper/sign_mbr: $(OBJ)/helper/sign_mbr.o
	$(GXX) $^ -o $@
$(OBJ)/helper/sign_mbr.o: helper/sign_mbr.cpp
	$(CXX) $^ -o $@

# MBR
$(OBJ)/boot/mbr.o: boot/mbr.S boot/boot.inc boot/bits16/printer.inc
	$(AS) $< -o $@ -Iboot
$(BIN)/boot/mbr.bin: $(OBJ)/boot/mbr.o $(OBJ)/boot/bits16/printer.o $(OBJ)/boot/bits16/read_disk.o
	$(LD) -T boot/ld-mbr.ld $^ -o $@
	$(OBJCOPY) -O binary -j .text $@
$(BIN)/boot/mbr_s.bin: $(BIN)/boot/mbr.bin $(BIN)/helper/sign_mbr
	$(BIN)/helper/sign_mbr $< $@

# Loader
$(OBJ)/boot/loader.o: boot/loader.S boot/boot.inc boot/bits16/printer.inc
	$(AS) $< -o $@ -Iboot
$(BIN)/boot/loader.bin: $(OBJ)/boot/loader.o $(OBJ)/boot/bits16/printer.o
	$(LD) -T boot/ld-loader.ld $^ -o $@
	$(OBJCOPY) -O binary -j .text $@
