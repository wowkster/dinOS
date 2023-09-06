ASM=nasm

SRC_DIR=src
BUILD_DIR=build

#
# Floppy Image
#
floppy_image: $(BUILD_DIR)/main.img
$(BUILD_DIR)/main.img: build_dir bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main.img bs=512 count=2880
	$(shell brew --prefix dosfstools)/sbin/mkfs.fat -F 12 -n "DINOS" $(BUILD_DIR)/main.img
	dd if=$(BUILD_DIR)/stage1.bin of=$(BUILD_DIR)/main.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/stage2.bin "::boot.bin"
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
# Ensures that the build directory exists
#
build_dir: $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)

#
# Bootloader (Both Stages)
#
bootloader: bootloader_stage1 bootloader_stage2

#
# Bootloader (Stage 1)
#
bootloader_stage1: $(BUILD_DIR)/stage1.bin
$(BUILD_DIR)/stage1.bin: $(SRC_DIR)/bootloader/stage1/*.asm
	$(ASM) -i$(SRC_DIR)/bootloader/stage1/ $(SRC_DIR)/bootloader/stage1/boot.asm -f bin -o $(BUILD_DIR)/stage1.bin

#
# Bootloader (Stage 2)
#
bootloader_stage2: $(BUILD_DIR)/stage2.bin
$(BUILD_DIR)/stage2.bin: $(SRC_DIR)/bootloader/stage2/*.asm
	$(ASM) -i$(SRC_DIR)/bootloader/stage2/ $(SRC_DIR)/bootloader/stage2/main.asm -f bin -o $(BUILD_DIR)/stage2.bin

#
# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel/*.asm
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin