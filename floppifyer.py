BOOT_SECTOR_SIZE = 512
FLOPPY_SIZE = 1474560  # 1.44 MB

BOOT_PATH = r"boot.bin"
KERNEL_PATH = r"kernel.bin"
IMG_PATH    = r"accidentalos.img"

with open(BOOT_PATH, "rb") as b:
    boot_sector = b.read()

with open(KERNEL_PATH, "rb") as k:
    kernel = k.read()

if len(boot_sector) != BOOT_SECTOR_SIZE:
    raise ValueError(f"Boot sector must be exactly 512 bytes (got {len(boot_sector)})")

with open(IMG_PATH, "wb") as f:
    f.write(boot_sector)
    f.write(b"\x00" * (32 * 512))
    f.write(kernel)
    remaining = FLOPPY_SIZE - f.tell()
    if remaining > 0:
        f.write(b"\x00" * remaining)

print("accidentalos.img created successfully")