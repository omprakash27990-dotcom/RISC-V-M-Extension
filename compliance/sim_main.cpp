#include "Vrv32i_soc_top.h"
#include "Vrv32i_soc_top___024root.h"
#include "verilated.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <vector>
#include <string>

static constexpr uint32_t BASE      = 0x80000000u;
static constexpr uint32_t MEM_BYTES = 262144u;   // must equal MEM_BYTES in the RTL memories

#define IMEM(i) dut->rootp->rv32i_soc_top__DOT__u_imem__DOT__mem[i]
#define DMEM(i) dut->rootp->rv32i_soc_top__DOT__u_dmem__DOT__mem[i]

struct Elf32_Ehdr { uint8_t e_ident[16]; uint16_t e_type,e_machine; uint32_t e_version,e_entry,e_phoff,e_shoff,e_flags;
                     uint16_t e_ehsize,e_phentsize,e_phnum,e_shentsize,e_shnum,e_shstrndx; };
struct Elf32_Phdr { uint32_t p_type,p_offset,p_vaddr,p_paddr,p_filesz,p_memsz,p_flags,p_align; };

static bool load_elf(const char* path, std::vector<uint8_t>& image) {
    std::ifstream f(path, std::ios::binary);
    if (!f) { fprintf(stderr, "cannot open %s\n", path); return false; }
    std::vector<uint8_t> buf((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    Elf32_Ehdr eh; memcpy(&eh, buf.data(), sizeof(eh));
    for (int i = 0; i < eh.e_phnum; i++) {
        Elf32_Phdr ph;
        memcpy(&ph, buf.data() + eh.e_phoff + i * eh.e_phentsize, sizeof(ph));
        if (ph.p_type != 1) continue;
        if (ph.p_vaddr < BASE || (ph.p_vaddr - BASE + ph.p_memsz) > MEM_BYTES) {
            fprintf(stderr, "segment out of range: vaddr=0x%x memsz=0x%x\n", ph.p_vaddr, ph.p_memsz);
            return false;
        }
        uint32_t off = ph.p_vaddr - BASE;
        memcpy(image.data() + off, buf.data() + ph.p_offset, ph.p_filesz);
        for (uint32_t z = ph.p_filesz; z < ph.p_memsz; z++) image[off + z] = 0;
    }
    return true;
}

int main(int argc, char** argv) {
    if (argc < 6) {
        fprintf(stderr, "usage: %s <elf> <sig_out> <begin_sig_hex> <end_sig_hex> <tohost_hex> [max_cycles]\n", argv[0]);
        return 1;
    }
    const char* elf_path = argv[1];
    const char* sig_out  = argv[2];
    uint32_t begin_sig   = strtoul(argv[3], nullptr, 16);
    uint32_t end_sig     = strtoul(argv[4], nullptr, 16);
    uint32_t tohost_addr = strtoul(argv[5], nullptr, 16);
    uint64_t max_cycles  = (argc > 6) ? strtoull(argv[6], nullptr, 10) : 2000000ULL;

    std::vector<uint8_t> image(MEM_BYTES, 0);
    if (!load_elf(elf_path, image)) return 1;

    Verilated::commandArgs(argc, argv);
    Vrv32i_soc_top* dut = new Vrv32i_soc_top;

    for (uint32_t i = 0; i < MEM_BYTES; i++) {
        IMEM(i) = image[i];
        DMEM(i) = image[i];
    }

    dut->reset = 1;
    dut->clk = 0;
    for (int i = 0; i < 4; i++) {
        dut->clk = 0; dut->eval();
        dut->clk = 1; dut->eval();
    }
    dut->reset = 0;

    auto rd32 = [&](uint32_t off) -> uint32_t {
        return (uint32_t)DMEM(off) | ((uint32_t)DMEM(off+1) << 8)
             | ((uint32_t)DMEM(off+2) << 16) | ((uint32_t)DMEM(off+3) << 24);
    };
    auto clr64 = [&](uint32_t off) { for (int k = 0; k < 8; k++) DMEM(off + k) = 0; };

    // tohost is a 64-bit HTIF register: low word at +0, high word at +4.
    //  - high word != 0 : an HTIF command. Device 1 / command 1 = console putchar
    //                     (low word = the character). We print it and clear tohost.
    //  - high word == 0 and low bit set : exit request (1 = pass). The program keeps
    //                     rewriting it in a loop, so we require it to be stable for
    //                     8 cycles to ignore the brief state in the middle of a putchar.
    uint32_t tohost_off = tohost_addr - BASE;
    bool halted = false;
    uint32_t tohost_final = 0;
    uint32_t halt_pc = 0;
    int exit_cnt = 0;
    uint64_t cycle = 0;

    for (; cycle < max_cycles; cycle++) {
        dut->clk = 0; dut->eval();
        dut->clk = 1; dut->eval();

        uint32_t lo = rd32(tohost_off), hi = rd32(tohost_off + 4);
        if (hi != 0) {
            if ((hi >> 24) == 1 && ((hi >> 16) & 0xff) == 1) fputc((int)(lo & 0xff), stderr);
            clr64(tohost_off);
            exit_cnt = 0;
        } else if (lo & 1) {
            if (++exit_cnt >= 8) {
                halted = true; tohost_final = lo;
                halt_pc = dut->rootp->rv32i_soc_top__DOT__pc;
                break;
            }
        } else {
            exit_cnt = 0;
        }
    }

    if (!halted)
        fprintf(stderr, "TIMEOUT after %llu cycles (no HTIF exit) - %s\n",
                (unsigned long long)cycle, elf_path);

    std::ofstream out(sig_out);
    if (!out) { fprintf(stderr, "cannot write %s\n", sig_out); delete dut; return 1; }
    for (uint32_t addr = begin_sig; addr < end_sig; addr += 4) {
        uint32_t off = addr - BASE;
        char line[16];
        snprintf(line, sizeof(line), "%08x\n", rd32(off));
        out << line;
    }

    if (halted && tohost_final != 1)
        fprintf(stderr, "FAIL: tohost = 0x%x at cycle %llu, pc=0x%x - %s\n",
                tohost_final, (unsigned long long)cycle, halt_pc, elf_path);

    delete dut;
    return !halted ? 2 : (tohost_final == 1 ? 0 : 3);
}
