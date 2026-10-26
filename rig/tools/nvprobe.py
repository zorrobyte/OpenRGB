# Read-only probe: does the GPU have an ENE controller at 0x67 (registers 0xA0..0xAF == 0..15)?
import ctypes as C
from ctypes import c_uint32 as U32, c_uint8 as U8, c_void_p, POINTER, byref

nv = C.WinDLL("nvapi64.dll")
qi = nv.nvapi_QueryInterface
qi.restype = c_void_p
qi.argtypes = [U32]

def fn(id_, *args):
    return C.WINFUNCTYPE(C.c_int, *args)(qi(id_))

class I2C(C.Structure):
    _fields_ = [("version", U32), ("display_mask", U32), ("is_ddc_port", U8), ("dev_addr", U8),
                ("reg_addr", POINTER(U8)), ("reg_addr_size", U32), ("data", POINTER(U8)), ("size", U32),
                ("speed", U32), ("speed_khz", U32), ("port_id", U8), ("is_port_id_set", U32)]

Init = fn(0x0150E828)
Enum = fn(0xE5AC921F, POINTER(c_void_p * 64), POINTER(U32))
PciIds = fn(0x2DDFB66E, c_void_p, POINTER(U32), POINTER(U32), POINTER(U32), POINTER(U32))
ReadEx = fn(0x4D7B0709, c_void_p, POINTER(I2C), POINTER(U32))

print("init", Init())
handles = (c_void_p * 64)(); n = U32()
print("enum", Enum(byref(handles), byref(n)), n.value)
for g in range(n.value):
    h = handles[g]
    dev, sub, rev, ext = U32(), U32(), U32(), U32()
    PciIds(h, byref(dev), byref(sub), byref(rev), byref(ext))
    print(f"gpu{g} dev={dev.value:08X} sub={sub.value:08X}")

    def read_byte_data(addr, reg):
        r = U8(reg); buf = (U8 * 4)(); unk = U32()
        i = I2C(); i.version = C.sizeof(I2C) | (3 << 16)
        i.reg_addr = C.cast(byref(r), POINTER(U8)); i.reg_addr_size = 1
        i.data = C.cast(buf, POINTER(U8)); i.size = 1
        i.speed = 0xFFFF; i.speed_khz = 0; i.port_id = 1; i.is_port_id_set = 1
        i.dev_addr = addr << 1
        rc = ReadEx(h, byref(i), byref(unk))
        return buf[0] if rc == 0 else -rc

    for addr in (0x67,):
        vals = [read_byte_data(addr, reg) for reg in range(0xA0, 0xB0)]
        ok = vals == list(range(16))
        print(f"  addr 0x{addr:02X}: {vals} -> {'ENE controller' if ok else 'no match'}")
