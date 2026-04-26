BOOT_SECTOR_SIZE = 512
FLOPPY_SIZE = 1474560  # 1.44 MB

BOOT_PATH = r"boot.bin"
IMG_PATH    = r"accidentalos.img"

with open(BOOT_PATH, "rb") as f:
    boot_sector = f.read()

if len(boot_sector) != BOOT_SECTOR_SIZE:
    raise ValueError(f"Boot sector must be exactly 512 bytes (got {len(boot_sector)})")

with open(IMG_PATH, "wb") as f:
    f.write(boot_sector)
    f.write(b"\x00" * (FLOPPY_SIZE - BOOT_SECTOR_SIZE))

print("accidentalos.img created successfully")