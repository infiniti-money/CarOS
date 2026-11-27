"""Generate original CarOS PNG icons using only Python stdlib."""
from pathlib import Path
import struct
import zlib

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

def png(size):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            a, b = x * 512 / size, y * 512 / size
            left = 100 + (350 - b) * 110 / 225
            right = 412 - (350 - b) * 110 / 225
            blue = 125 <= b <= 350 and left <= a <= right and (b <= 185 or abs(a - 256) >= (b - 185) * 80 / 165)
            white = 226 <= a <= 286 and 350 <= b <= 402
            rows.extend((241,245,250) if white else (139,196,255) if blue else (16,27,45))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")

if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "webapp" / "icons"
    target.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        (target / f"icon-{size}.png").write_bytes(png(size))
