ASM=nasm

SRC_DIR=src
BUILD_DIR=build

#
# Floppy Image
#
floppy_image: $(BUILD_DIR)/main.img
$(BUILD_DIR)/main.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main.img bs=512 count=2880
	$(shell brew --prefix dosfstools)/sbin/mkfs.fat -F 12 -n "DINOS" $(BUILD_DIR)/main.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main.img $(BUILD_DIR)/kernel.bin "::kernel.bin"


#
# Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin
$(BUILD_DIR)/bootloader.bin: $(SRC_DIR)/bootloader/*.asm
	mkdir -p build
	$(ASM) -i$(SRC_DIR)/bootloader/ $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: $(SRC_DIR)/kernel/*.asm
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin