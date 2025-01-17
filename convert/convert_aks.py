import subprocess
import os, glob, sys

### ===========================================================================
### AKS TO SPM/SPX CONVERTER
### ===========================================================================

"""
Converts an AKS file into one SPM/SPX SymbOS Sound Daemon music/effect file.

usage:
python3 convert_aks.py [filename].aks M
-> converts a AKS song file with multiple sub songs into a SPM music
   collection

python3 convert_aks.py [filename].aks X
-> converts a AKS file with multiple instruments into a SPX effect collection
"""

"""

todo

"""


### ---------------------------------------------------------------------------
### execute shell command
### ---------------------------------------------------------------------------
def run_cmd(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    c = p.communicate()


### ---------------------------------------------------------------------------
### return word as binary
### ---------------------------------------------------------------------------
def word_bin(word):
    return bytearray([word % 256, int(word/256)])


### ---------------------------------------------------------------------------
### load binary
### ---------------------------------------------------------------------------
def bin_load(file):
    fil_bin = open(file, "rb")
    binary = fil_bin.read()
    fil_bin.close()
    return binary


### ---------------------------------------------------------------------------
### save binary
### ---------------------------------------------------------------------------
def bin_save(file, binary):
    fil_bin = open(file, "wb")
    fil_bin.write(binary)
    fil_bin.close()


### ---------------------------------------------------------------------------
### compress data
### ---------------------------------------------------------------------------
def compress(binary):
    bin_save("temp", binary[:len(binary) - 4])
    run_cmd("zx0 temp")
    bin_crn = bin_load("temp.zx0")
    run_cmd("del temp")
    run_cmd("del temp.zx0")
    bin_crn = binary[len(binary) - 4:] + bytearray(2) + bin_crn
    return word_bin(len(bin_crn)) + bin_crn


### ---------------------------------------------------------------------------
### generate relocator table
### ---------------------------------------------------------------------------
def snd_reloc(file, type, subs):
    file_pre, file_ext = os.path.splitext(file)

    if type == "G":
        typchr = "M"
        typcmd = "SongToAkg"
    else:
        typchr = "X"
        typcmd = "SongToSoundEffects"


    run_cmd(f"{typcmd}.exe {file} {file_pre}0.ak{type} -bin -adr 0x0004{subs}")
    run_cmd(f"{typcmd}.exe {file} {file_pre}1.ak{type} -bin -adr 0x0106{subs}")

    bin_akg0 = bin_load(f"{file_pre}0.ak{type}")
    bin_akg1 = bin_load(f"{file_pre}1.ak{type}")

    run_cmd(f"del {file_pre}0.ak{type}")
    run_cmd(f"del {file_pre}1.ak{type}")

    adr_cur = 0
    adr_lst = 0

    bin_rel = bytearray()

    while adr_cur < len(bin_akg0):
        len_skp = 0
        while (adr_cur < len(bin_akg0)) and (bin_akg0[adr_cur] == bin_akg1[adr_cur]):
            adr_cur += 1
            len_skp += 1
        if adr_cur < len(bin_akg0):
            len_rlc = 0
            while (adr_cur < len(bin_akg0)) and (bin_akg0[adr_cur] != bin_akg1[adr_cur]):
                adr_cur += 1
                len_rlc += 1
            while (len_rlc > 0) or (len_skp > 0):
                if (len_rlc == 2) and (len_skp < 128):
                    bin_rel += bytearray([128 + len_skp])
                    len_rlc = 0
                    len_skp = 0
                elif len_skp < 128:
                    bin_rel += bytearray([len_skp, min(255, int(len_rlc/2))])
                    len_rlc -= min(255*2, len_rlc)
                    len_skp = 0
                else:
                    bin_rel += bytearray([127, 0])
                    len_skp -= 127
    bin_rel += bytearray([0, 0])        # terminate reloc table

    bin_out = word_bin(len(bin_akg0)) + word_bin(len(bin_rel)) + bin_akg0 + bin_rel

    bin_save(file_pre + ".sp" + typchr.lower(), bytearray([ord("P"), ord(typchr)]) + word_bin(len(bin_out) + 32768) + compress(bin_out))



### batch
if len(sys.argv) != 3:
    print("wrong parameter; use...\nconvert_aks.py [filemask].aks [type]\n[type] can be M for converting to music SPM files or X for converting to effect SPX files\nUse M2, M3, ... instead of M if the AKS contains multiple subsongs")
else:
    typefull = sys.argv[2].upper()
    type = typefull[:1]
    if type != "M" and type != "X":
        print("wrong type; has to be M for music or X for effects")
    else:
        subs = ""
        if type == "M":
            type = "G"
            if typefull[1:] != "":
                for i in range(int(typefull[1:])):
                    subs += f"s{i+1}p1,"
                subs = " -sp " + subs[:len(subs)-1]
                
        files = glob.glob(sys.argv[1])
        if len(files) == 0:
            print("File(s) not found")
        else:
            for file in files:
                snd_reloc(file, type, subs)
