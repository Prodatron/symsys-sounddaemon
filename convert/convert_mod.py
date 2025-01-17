import subprocess
import os, glob, sys

### ===========================================================================
### MOD TO SWM CONVERTER
### ===========================================================================

"""
Merges, converts and compresses multiple MOD music modules into one SWM SymbOS
Sound Daemon music file.
Compression is done in multiple steps:
- double samples will be removed and shared
- double tracks will be removed and shared
- pattern data is packed using RLE-like methodes (see below)
- meta and pattern data is compressed using the ZX0 compressor by Einar Saukas

usage:
python3 convert_mod.py [filemask].mod fileout.swm
-> merges multiple MODs into one SWM, which results in a music collection,
   where the first song in the list will have ID=0, the next ID=1 etc.

python3 convert_mod.py [filemask].mod
-> convertes multiple MODs into multiple SWMs, which results in one music
   (with ID=0) per SWM
"""


"""
todo

"""


MOD_SAMP_DATBEG = 20
MOD_SAMP_DATLEN = 30

MOD_SAMP_NAME   = 0
MOD_SAMP_LENGTH = 22
MOD_SAMP_PITCH  = 24
MOD_SAMP_VOLUME = 25
MOD_SAMP_REPBEG = 26
MOD_SAMP_REPBEG = 28

MOD_TYPEID      = 1080


arr_chan = []
arr_patt = []
arr_samp = []       # 6 byte sample info [Wlen, Wrep, Bvol, Bfin] + sample data


"""
SWM format

0000000        2B   "WM"
0000002        1W   total data length without samples

0000000        1B   number of samples (1-63)
0000001        1B   number of pattern (1-255)
0000002        1B   number of channels (currently only 4)
0000003       13B   *res*
0000016       32B   subsong lengthes in global playlist
0000048      ???B   global playlist (sum(subsong lengthes)*1)
                    1B   pattern id (0-255)
???????      ???B   sample data (number of samples*8)
                    2B   0
                    2B   length
                    2B   repeat offset
                    1B   volume (0-64)
                    1B   finetune (-8 - 7)
???????     ????B   pattern data
                    1W   channel 1 offset
                    1W   channel 2 offset
                    1W   channel 3 offset
                    1W   channel 4 offset
???????    ?????B   channel data

???????  ???????B   sample data


MOD packing
00iiiiii 00nnnnnn eeee0000 dddddddd -> 4 byte note data (instument, period, effect, effect data)
01nnnnnn                            -> use again note data from position actual-(64-n)
10nnnnnn                            -> n+1 empty notes
11nnnnnn                            -> repeat last note n+1 times


opl4
master clock
17 or 33mhz (?)
88 cycles write
28 cycles for memory data write -> 2 nops (3,5mhz), 4 nops (7mhz)
38 cycles for memory data read


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
### return bin as hexstr
### ---------------------------------------------------------------------------
def bin_hex(binary):
    strng = ""
    for i in range(len(binary)):
        hx = "0" + hex(binary[i]).replace("0x","")
        strng += hx[len(hx)-2:].upper() + " "

    return strng


### ---------------------------------------------------------------------------
### return big-endian word
### ---------------------------------------------------------------------------
def word_bige(binary):
    return (binary[0] * 256 + binary[1]) * 2


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
    print(f"{len(binary)} -> {len(bin_crn)}")
    return word_bin(len(bin_crn)) + bin_crn


### ---------------------------------------------------------------------------
### compresses and add pattern
### ---------------------------------------------------------------------------
def compress_patt(bin_patt, pat_renum):

    global arr_chan, arr_patt

    patt = []
    for i in range(4):              # for each channel in pattern
        bin_chan = bytearray()
        for j in range(64):         # build channel binary
            bin_chan += bin_patt[j*16 + i*4 : j*16 + i*4 + 4]
        k = 0
        for chan in arr_chan:       # search same channel in channel array
            if bin_chan == chan:
                patt.append(k)      # found -> use ID
                break
            k += 1
        if k == len(arr_chan):      # not found -> add new channel to channel array
            arr_chan.append(bin_chan)
            patt.append(k)
    arr_patt.append(patt)


### ---------------------------------------------------------------------------
### convert channel data
### ---------------------------------------------------------------------------

#   orig    00iipppp pppppppp iiiieeee dddddddd
#   conv    00iiiiii 0nnnnnnn eeee0000 dddddddd

def convert_chan(bin_chan):

    periods = [0, 856,808,762,720,678,640,604,570,538,508,480,453, 428,404,381,360,339,320,302,285,269,254,240,226, 214,202,190,180,170,160,151,143,135,127,120,113]
    
    bin_conv = bytearray()

    for i in range(64):
        period = bin_chan[i*4:i*4+2]
        period = 256 * (period[0] & 15) + period[1]
        if period in periods:
            note = periods.index(period)
        else:
            note = 0
            print(f"Note: unknown period {period}")
        instrument = int(bin_chan[i*4+0] / 16) * 16 + int(bin_chan[i*4+2] / 16)
        effect = bin_chan[i*4+2] & 15
        fxdata = bin_chan[i*4+3]

        if effect == 13:        # convert pattern break D00 to BFF
            if fxdata > 0:
                print(f"Dxx: unsupported in-pattern jump {fxdata}")
            effect = 11
            fxdata = 255
        elif effect == 15:      # convert speed from bpm to ticks
            if fxdata > 32:
                print(f"Fxx: bpm speed {fxdata} found -> converted to {round(750/fxdata)} ticks")
                fxdata = round(750/fxdata)
            if fxdata < 2:
                print(f"Fxx: speed {fxdata} too fast -> increased to 2 ticks")
                fxdata = 2
        elif effect == 9:       # unsupported sample offset
            print(f"9xx: sample offset command {fxdata} not supported -> removed")
            effect = 0
            fxdata = 0

        bin_conv += bytearray([instrument, note, effect*16, fxdata])

    return bin_conv


### ---------------------------------------------------------------------------
### compresses channel data
### ---------------------------------------------------------------------------
def compress_chan(bin_chan):

    bin_chan = convert_chan(bin_chan)

    double_cnt = 0
    double_was = 0     # 0=nothing, 1=empty, 2=double
    bin_last = bytearray()
    bin_cmpr = bytearray()
    line_cnt = 0

    for i in range(64):
        bin_pos = bin_chan[i*4:i*4+4]
        if bin_pos == bytearray(4):                         # slot is empty
            if double_was == 2:
                bin_cmpr += bytearray([double_cnt + 192])   # mode was double -> close double mode
            if double_was == 1:
                double_cnt += 1                             # mode was already empty -> just increase counter
            else:
                double_cnt = 0                              # mode wasn't empty -> start with empty mode
                double_was = 1

        elif bin_pos == bin_last:                           # slot is like last
            if double_was == 1:
                bin_cmpr += bytearray([double_cnt + 128])   # mode was empty -> close empty mode
            if double_was == 2:
                double_cnt += 1                             # mode was already double -> just increase counter
            else:
                double_cnt = 0                              # mode wasn't double -> start with double mode
                double_was = 2

        else:                                               # slot is new
            if double_was > 0:                              # close empty/double mode
                bin_cmpr += bytearray([double_cnt + 64 + 64 * double_was])
                double_was = 0
            k = 0
            for j in range(line_cnt):                       # search in previous slots
                if bin_pos == bin_chan[j*4:j*4+4]:
                    bin_cmpr += bytearray([128-line_cnt+j]) # found -> point to previous slots
                    break
                k += 1
            if k == line_cnt:                               # not found -> add full new slot
                bin_cmpr += bin_pos

        line_cnt += 1
        bin_last = bin_pos

    if double_was > 0:
        bin_cmpr += bytearray([double_cnt + 64 + 64 * double_was])

    return bin_cmpr


### ---------------------------------------------------------------------------
### add samples
### ---------------------------------------------------------------------------
def add_samp(bin_mod, num_samp, num_patt, ofs_patt, ofs_samp):

    global arr_samp

    # find used samples
    samp_used = []
    for i in range(num_patt * 4 * 64):
        slot = bin_mod[i * 4 + ofs_patt : i * 4 + ofs_patt + 3]
        samp_id = int(slot[0] / 16) * 16 + int(slot[2] / 16)
        if samp_id > 0:
            if samp_id not in samp_used:
                samp_used.append(samp_id)
    samp_used.sort()

    # calculate sample data begin
    samp_beg = {}
    adr = ofs_samp
    for i in range(num_samp):
        samp_beg[i+1] = adr
        adr += word_bige(bin_mod[i * 30 + 20 + 22 : i * 30 + 20 + 24])

    # add/sort in used samples to global sample array
    samp_new = {}
    for samp_id in samp_used:
        adr = (samp_id - 1) * 30 + 20 + 22
        samp_len = word_bige(bin_mod[adr+0:adr+2])
        samp_rep = word_bige(bin_mod[adr+4:adr+6])
        samp_rln = word_bige(bin_mod[adr+6:adr+8])
        if samp_rln > 2:
            samp_len = min(samp_len, samp_rep + samp_rln)
        else:
            samp_rep = 65535
        samp_data = word_bin(samp_len+3) + word_bin(samp_rep) + bytearray([min(bin_mod[adr+3],64), bin_mod[adr+2]])
        samp_data += bin_mod[samp_beg[samp_id]:samp_beg[samp_id] + samp_len]
        b = samp_data[len(samp_data) - 1]
        for i in range(3):
            samp_data += bytearray([b])         # add last byte 3 times

        samp_sel = -1
        for i in range(len(arr_samp)):
            if samp_data == arr_samp[i]:
                print(f"Double sample {samp_id} is already {i+1}")
                samp_sel = i
                break
        if samp_sel == -1:
            samp_sel = len(arr_samp)
            arr_samp.append(samp_data)
        samp_new[samp_id] = samp_sel + 1

    # replace sample ID in pattern
    bin_mod = bytearray(bin_mod)

    for i in range(num_patt * 4 * 64):
        slot = bin_mod[i * 4 + ofs_patt : i * 4 + ofs_patt + 3]
        samp_id = int(slot[0] / 16) * 16 + int(slot[2] / 16)
        if samp_id > 0:
            samp_rep = samp_new[samp_id]
            bin_mod[i*4+ofs_patt+0] = (int(samp_rep/16) * 16) + (slot[0] % 16)
            bin_mod[i*4+ofs_patt+2] = ( (samp_rep % 16) * 16) + (slot[2] % 16)

    return bin_mod


### ---------------------------------------------------------------------------
### add MOD file
### ---------------------------------------------------------------------------
def mod_add(file):

    global arr_patt, arr_samp, arr_list

    print(f"Adding {file}...")

    bin_mod = bin_load(file)

    mod_id = bin_mod[MOD_TYPEID:MOD_TYPEID+4].decode("utf-8")
    if (mod_id == "M.K.") or (mod_id == "M!K!") or (mod_id == "FLT4") or (mod_id == "4CHN"):
        num_samp = 31
        ofs_patt = 4
    else:
        num_samp = 15
        ofs_patt = 0
    ofs_list = num_samp * MOD_SAMP_DATLEN + MOD_SAMP_DATBEG
    ofs_patt += ofs_list + 128 + 2

    num_patt = 0
    for i in bin_mod[ofs_list + 2:ofs_list + 2 + 128]:
        num_patt = max(num_patt, i)
    num_patt += 1
    ofs_samp = ofs_patt + num_patt * 1024

    # [arr_samp] add samples -> remove unused samples, sort into existing samples, renumber in pattern
    bin_mod = add_samp(bin_mod, num_samp, num_patt, ofs_patt, ofs_samp)

    # [arr_patt] compress pattern -> add patterns and reduce double channels
    pat_renum = len(arr_patt)
    for i in range(num_patt):
        compress_patt(bin_mod[ofs_patt + i * 1024:ofs_patt + i * 1024 + 1024], pat_renum)

    # update songlist with pat_renum
    sng_list = bytearray(bin_mod[ofs_list + 2:ofs_list + 2 + bin_mod[ofs_list]])
    for i in range(len(sng_list)):
        sng_list[i] += pat_renum

    return sng_list


### ---------------------------------------------------------------------------
### merge MOD file
### ---------------------------------------------------------------------------
def mod_merge(files, file_out):

    global arr_chan, arr_patt, arr_samp
    arr_chan = []
    arr_patt = []
    arr_samp = []
    arr_list = []
    len_list = []

    # add MODs
    for file in files:
        sng_list = mod_add(file)
        len_list.append(len(sng_list))
        arr_list.extend(sng_list)

    # compress channels -> reduce double/empty slots
    ofs_chan = []
    siz_chan = 0
    for i in range(len(arr_chan)):
        ofs_chan.append(siz_chan)
        arr_chan[i] = compress_chan(arr_chan[i])
        siz_chan += len(arr_chan[i])

    # build output binary
    bin_head =  bytearray("WM", 'utf-8')

    bin_data  = bytearray([len(arr_samp)])          # number of samples
    bin_data += bytearray([len(arr_patt)])          # number of pattern
    bin_data += bytearray([4])                      # number of channels
    bin_data += bytearray(13)                       # *res*

    bin_data += bytearray(len_list)                 # subsong lengthes
    bin_data += bytearray(32-len(len_list))

    bin_data += bytearray(arr_list)                 # global playlist

    for i in range(len(arr_samp)):                  # sample header data
        bin_data += bytearray(2) + arr_samp[i][0:6]
    ofs_total = len(bin_data) + len(arr_patt) * 4 * 2
    for i in range(len(arr_patt)):                  # pattern data
        for j in range(4):
            bin_data += word_bin(ofs_chan[arr_patt[i][j]] + ofs_total)
    for i in range(len(arr_chan)):                  # channel data
        bin_data += arr_chan[i]

    bin_samp = bytearray()
    for i in range(len(arr_samp)):
        bin_samp += arr_samp[i][6:]

    file_pre, file_ext = os.path.splitext(file_out)
    bin_save(file_pre + ".swm", bin_head + word_bin(len(bin_data)+32768) + compress(bin_data) + bin_samp)


### batch
files    = glob.glob(sys.argv[1])
if len(files) == 0:
    print("File(s) not found")
if len(sys.argv) == 3:
    file_out = sys.argv[2]
    mod_merge(files, file_out)
else:
    for file in files:
        mod_merge([file], file)
