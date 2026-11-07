import subprocess
import os, glob, sys, math, struct

### ===========================================================================
### MOD/S3M TO SWM CONVERTER
### ===========================================================================

"""
Merges, converts and compresses multiple MOD or S3M music modules into one SWM
SymbOS Sound Daemon music file.
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

python3 convert_mod.py [filemask].s3m [fileout.swm]
-> the same with ScreamTracker 3 modules (up to 8 channels); a S3M with
   several parts (separated by the end marker 255 in its order list) gives
   one subsong per part

MOD and S3M files can be mixed in one collection; the SWM then has 8
channels, when one of the files needs more than 4.
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


arr_chan = []       # channel data (64 slots * 4 bytes)
arr_chcv = []       # flag per channel, if already converted (S3M) or still raw MOD data
arr_patt = []       # list of channel IDs per pattern
arr_samp = []       # 6 byte sample info [Wlen, Wrep, Bvol, Bfin] + sample data
num_chan = 4        # channels of the SWM (4 or 8)
pan_chan = [0] * 8  # panning per channel (0=default, else OPL4 panpot+1)
swm_flags = 0       # +1=ST3.00 volume slides (also on the first tick), +2=extended notes (note 1 = period 3424),
                    # +4=sample offset table behind the sample records
ofs_pairs = []      # (sample ID, offset) pairs used by 9xx -> the daemon creates a wave header per pair at load time


"""
SWM format

0000000        2B   "WM"
0000002        1W   total data length without samples

0000000        1B   number of samples (1-63)
0000001        1B   number of pattern (1-255)
0000002        1B   number of channels (4 or 8)
0000003        8B   panning per channel (0=default, else OPL4 panpot+1)
0000011        1B   flags (+1=volume slides also on the first tick [ST3.00],
                           +2=extended notes [note 1 = period 3424, 8 octaves];
                           without +2 the notes are 1-36 = period 856-113;
                           +4=sample offset table behind the sample records)
0000012        4B   *res*
0000016       32B   subsong lengthes in global playlist
0000048      ???B   global playlist (sum(subsong lengthes)*1)
                    1B   pattern id (0-255)
???????      ???B   sample data (number of samples*8)
                    2B   0
                    2B   length
                    2B   repeat offset
                    1B   volume (0-64)
                    1B   finetune (0-15 like MOD; 1-7 = +1/8..+7/8, 8-15 = -8/8..-1/8 halftone)
???????     ????B   sample offset table (only with flag +4; the pairs (sample, offset) of all 9xx)
                    1B   number of entries (1-64)
                    3B   per entry -> sample ID (1-63), offset (/256), 0 (the daemon stores the wave ID here)
???????     ????B   pattern data
                    1W   channel 1 offset
                    1W   channel 2 offset
                    ...  (number of channels words per pattern)
???????    ?????B   channel data

???????  ???????B   sample data


MOD packing
00iiiiii vnnnnnnn eeeevvvv dddddddd -> 4 byte note data (instrument, note, effect, effect data)
                                       vvvvv = volume (0=keep, 1-31 = silent to loud)
01nnnnnn                            -> use again note data from position actual-(64-n)
10nnnnnn                            -> n+1 empty notes
11nnnnnn                            -> repeat last note n+1 times

effects = MOD effects 0-F (E0-EF), new 9xx = sample offset xx*256


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
### adds one channel (64 slots * 4 bytes) to the channel array, returns its ID
### ---------------------------------------------------------------------------
def add_chan(bin_chan, converted):

    global arr_chan, arr_chcv

    for k in range(len(arr_chan)):                  # search same channel in channel array
        if bin_chan == arr_chan[k] and converted == arr_chcv[k]:
            return k
    arr_chan.append(bin_chan)                       # not found -> add new channel to channel array
    arr_chcv.append(converted)
    return len(arr_chan) - 1


### ---------------------------------------------------------------------------
### adds a pattern (list of channel IDs), returns its ID
### ---------------------------------------------------------------------------
def add_patt(patt):

    global arr_patt

    for k in range(len(arr_patt)):
        if arr_patt[k] == patt:
            return k
    arr_patt.append(patt)
    return len(arr_patt) - 1


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
        patt.append(add_chan(bin_chan, False))
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
def compress_chan(bin_chan, converted=False):

    if not converted:
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

        samp_new[samp_id] = samp_store(samp_data, samp_id)

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
### stores a sample (6 byte info + data) in the global sample array, returns its SWM ID (1-63)
### ---------------------------------------------------------------------------
def samp_store(samp_data, samp_id):

    global arr_samp

    for i in range(len(arr_samp)):
        if samp_data == arr_samp[i]:
            print(f"Double sample {samp_id} is already {i+1}")
            return i + 1
    arr_samp.append(samp_data)
    return len(arr_samp)


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

    return [sng_list]


### ===========================================================================
### S3M
### ===========================================================================

S3M_NOTE_OFS = 11               # S3M note (octave*12+halftone) - 11 = SWM note (S3M C-1 = note 1 = period 3424, C-3 = note 25 = period 856)
S3M_NOTE_MAX = 96               # 8 octaves

s3m_warn = {}

def warn(key, text, show=3):
    """counts a warning, prints the first ones"""
    n = s3m_warn.get(key, 0) + 1
    s3m_warn[key] = n
    if n <= show:
        print(text)


### ---------------------------------------------------------------------------
### S3M instruments -> global sample array; returns the info per S3M instrument
### ---------------------------------------------------------------------------
def s3m_samples(d, ins_ptr, ffi, used):

    info = {}
    for i, p in enumerate(ins_ptr):
        num = i + 1
        if num not in used or p == 0:
            continue
        if d[p] != 1:
            warn("notsample", f"instrument {num} is no sample (type {d[p]}) -> ignored")
            continue
        memseg = d[p+13] << 16 | d[p+14] | d[p+15] << 8
        length, loopbeg, loopend = struct.unpack_from("<III", d, p+16)
        vol, flags, c2spd = d[p+28], d[p+31], struct.unpack_from("<I", d, p+32)[0]
        name = d[p+48:p+76].split(b"\0")[0].decode("latin-1").strip()
        data = bytearray(d[memseg*16:memseg*16 + length * (2 if flags & 4 else 1) * (2 if flags & 2 else 1)])
        if flags & 4:
            warn("16bit", f"instrument {num}: 16 bit sample -> upper bytes taken")
            data = data[1::2]
        if flags & 2:
            warn("stereo", f"instrument {num}: stereo sample -> left channel taken")
            data = data[:length]
        if ffi == 2:
            data = bytearray(b ^ 128 for b in data)
        if flags & 1 and loopend > loopbeg:
            length = min(length, loopend)
            rep = loopbeg
            looped = True
        else:
            rep = 65535
            looped = False
        if length > 65532:
            warn("toolong", f"instrument {num}: {length} bytes -> cut to 65532")
            length = 65532
        data = data[:length]
        if rep != 65535 and rep >= length:
            rep = 65535
            looped = False
        if c2spd == 0:
            c2spd = 8363
        semis = 12 * math.log2(c2spd / 8363)
        trans = int(round(semis))
        fine = int(round((semis - trans) * 8))
        if fine < 0:
            fine += 16
        samp_data = word_bin(length + 3) + word_bin(rep) + bytearray([min(vol, 64), fine]) + data
        b = samp_data[len(samp_data) - 1]
        samp_data += bytearray([b, b, b])      # add last byte 3 times
        swm_id = samp_store(samp_data, num)
        info[num] = dict(id=swm_id, trans=trans, length=length, rep=rep, looped=looped)
        print(f"  instrument {num:2d} -> {swm_id:2d}  {length:5d} bytes  c2spd {c2spd:5d} -> {trans:+d} halftones, finetune {fine:2d}  {name}")
    return info


### ---------------------------------------------------------------------------
### unpacks a S3M pattern -> 64 rows * 32 channels of (note, ins, vol, cmd, info)
### ---------------------------------------------------------------------------
def s3m_pattern(d, p):

    rows = [[None] * 32 for i in range(64)]
    if p == 0:
        return rows
    length = struct.unpack_from("<H", d, p)[0]
    q = p + 2
    row = 0
    while row < 64 and q < p + length:
        what = d[q]
        q += 1
        if what == 0:
            row += 1
            continue
        ch = what & 31
        note = ins = vol = cmd = inf = None
        if what & 32:
            note, ins = d[q], d[q+1]
            q += 2
            if note == 255:
                note = None
            if ins == 0:
                ins = None
        if what & 64:
            vol = d[q]
            q += 1
            if vol > 64:
                vol = None
        if what & 128:
            cmd, inf = d[q], d[q+1]
            q += 2
            if cmd == 0:
                cmd = inf = None
        rows[row][ch] = (note, ins, vol, cmd, inf)
    return rows


### ---------------------------------------------------------------------------
### converts one S3M cell -> 4 bytes SWM note data; st = state of the channel
### ---------------------------------------------------------------------------
def s3m_cell(cell, st, sinfo, jump):

    note, ins, vol, cmd, inf = cell
    out_ins = out_note = out_vol = 0
    fx = fxd = 0

    if ins:
        st["ins"] = ins
        if ins in sinfo:
            out_ins = sinfo[ins]["id"]
        else:
            warn("noins", f"instrument {ins} has no sample -> ignored")
    cur = sinfo.get(st["ins"])

    if note is not None and note < 254:
        n = (note >> 4) * 12 + (note & 15) - S3M_NOTE_OFS
        if cur:
            n += cur["trans"]
        else:
            warn("noteins", "note without instrument -> no sample rate correction")
        if n < 1:
            warn("notelow", f"note {n} below the range -> 1")
            n = 1
        elif n > S3M_NOTE_MAX:
            warn("notehigh", f"note {n} above the range -> {S3M_NOTE_MAX}")
            n = S3M_NOTE_MAX
        out_note = n
    keyoff = note == 254

    if vol is not None:
        out_vol = max(1, min(31, 1 + int(round(vol * 30 / 64))))

    if cmd is not None:
        c = chr(64 + cmd)
        if c in "DEFIJKLQRS":                 # shared effect memory of ST3
            if inf:
                st["mem"] = inf
            else:
                inf = st["mem"]
        x, y = inf >> 4, inf & 15
        if c == "A":
            if inf:
                fx, fxd = 15, inf
        elif c == "B":
            pos = jump(inf)
            if pos is None:
                warn("jump", f"Bxx: jump to order {inf} outside of the subsong -> removed")
            else:
                fx, fxd = 11, pos
        elif c == "C":
            row = x * 10 + y
            if row:
                warn("break", f"Cxx: unsupported in-pattern jump to row {row} -> break to row 0")
            fx, fxd = 11, 255
        elif c == "D":
            if inf:
                if y == 15 and x:
                    fx, fxd = 14, 0xA0 | x
                elif x == 15 and y:
                    fx, fxd = 14, 0xB0 | y
                elif y == 0:
                    fx, fxd = 10, x << 4
                elif x == 0:
                    fx, fxd = 10, y
                else:
                    warn("dxy", f"D{inf:02X}: both nibbles set -> slide down {y} (like ST3)")
                    fx, fxd = 10, y
        elif c in "EF":
            up = c == "F"
            if inf >= 0xF0:
                fx, fxd = 14, (0x10 if up else 0x20) | y
            elif inf >= 0xE0:
                v = (y + 2) // 4
                warn("extrafine", f"{c}{inf:02X}: extra fine slide {y}/4 -> fine slide {v}")
                if v:
                    fx, fxd = 14, (0x10 if up else 0x20) | v
            elif inf:
                fx, fxd = (1 if up else 2), inf
        elif c == "G":                      # own memory of G (the player keeps the speed only on rows with a note)
            if inf:
                st["memg"] = inf
            else:
                inf = st.get("memg", 0)
            fx, fxd = 3, inf
        elif c == "H":
            fx, fxd = 4, inf
        elif c == "I":
            warn("tremor", f"I{inf:02X}: tremor not supported -> removed")
        elif c == "J":
            if inf:
                fx, fxd = 0, inf
        elif c == "K":
            fx, fxd = 6, inf
        elif c == "L":
            fx, fxd = 5, inf
        elif c == "O":
            if cur and inf:
                if inf * 256 >= cur["length"]:
                    if cur["looped"]:
                        warn("offsetend", f"O{inf:02X}: offset beyond the sample end -> plays from the loop start")
                    else:
                        warn("offsetend", f"O{inf:02X}: offset beyond the sample end -> nothing is played")
                elif cur["looped"] and inf * 256 > cur["rep"]:
                    warn("offsetloop", f"O{inf:02X}: offset behind the loop start -> the loop starts at the offset")
                pair = (cur["id"], inf)
                if pair in ofs_pairs or len(ofs_pairs) < 64:
                    if pair not in ofs_pairs:
                        ofs_pairs.append(pair)
                    fx, fxd = 9, inf
                else:
                    warn("offsetmax", f"O{inf:02X}: more than 64 (sample, offset) pairs -> offset removed")
        elif c == "Q":
            if x:
                warn("retrigvol", f"Q{inf:02X}: volume change on retrigger not supported -> ignored")
            if y:
                fx, fxd = 14, 0x90 | y
        elif c == "R":
            fx, fxd = 7, inf
        elif c == "S":
            sub = {2: 0x50, 3: 0x40, 4: 0x70, 0xB: 0x60, 0xC: 0xC0, 0xD: 0xD0, 0xE: 0xE0}.get(x)
            if sub is not None:
                fx, fxd = 14, sub | y
            else:
                warn("s%X" % x, f"S{inf:02X}: not supported -> removed")
        elif c == "T":
            warn("tempo", f"T{inf:02X}: tempo change not supported -> removed (the player runs at 50 ticks per second)")
        elif c == "U":
            v = (y + 2) // 4
            warn("finevib", f"U{inf:02X}: fine vibrato depth {y}/4 -> vibrato depth {v}")
            fx, fxd = 4, x << 4 | v
        elif c == "V":
            warn("globvol", f"V{inf:02X}: global volume not supported -> removed")
        elif c in "XZ":
            warn("x", f"{c}{inf:02X}: not supported -> removed")
        else:
            warn("unknown", f"{c}{inf:02X}: unknown effect -> removed")

    if keyoff:                                 # key off = volume 0 (the volume field never collides with an effect)
        out_vol = 1

    return bytearray([out_ins, out_note | (out_vol & 16) << 3, fx << 4 | (out_vol & 15), fxd])


### ---------------------------------------------------------------------------
### add S3M file; returns the song lists of its parts
### ---------------------------------------------------------------------------
def s3m_add(file):

    global num_chan, pan_chan, swm_flags, s3m_warn, ofs_pairs

    print(f"Adding {file}...")
    s3m_warn = {}

    d = bin_load(file)
    if d[0x2C:0x30] != b"SCRM" or d[0x1D] != 0x10:
        print("not a S3M file")
        return []
    title = d[:28].split(b"\0")[0].decode("latin-1").strip()
    ordnum, insnum, patnum, flags, cwtv, ffi = struct.unpack_from("<HHHHHH", d, 0x20)
    glovol, speed, tempo = d[0x30], d[0x31], d[0x32]
    orders = list(d[0x60:0x60 + ordnum])
    o = 0x60 + ordnum
    ins_ptr = [struct.unpack_from("<H", d, o + 2 * i)[0] * 16 for i in range(insnum)]
    o += 2 * insnum
    pat_ptr = [struct.unpack_from("<H", d, o + 2 * i)[0] * 16 for i in range(patnum)]

    chans = [i for i in range(32) if d[0x40 + i] < 16]      # enabled PCM channels
    if len(chans) > 8:
        print(f"{len(chans)} channels -> only the first 8 are converted")
        chans = chans[:8]
    nchan = 4 if len(chans) <= 4 else 8
    print(f"  \"{title}\": {len(chans)} channels, {ordnum} orders, {patnum} patterns, speed {speed}, tempo {tempo}")
    if tempo != 125:
        print(f"  tempo {tempo} -> the player runs at 50 ticks per second (tempo 125), the song plays {'slower' if tempo > 125 else 'faster'} by {abs(tempo - 125) * 100 // 125} %")
    if glovol != 64:
        print(f"  global volume {glovol} ignored")
    if cwtv == 0x1300 or flags & 64:
        print("  ST3.00 volume slides (also on the first tick)")
        swm_flags |= 1
    swm_flags |= 2
    num_chan = max(num_chan, nchan)
    for k, ch in enumerate(chans):
        pan = 5 if d[0x40 + ch] < 8 else 11
        if pan_chan[k] == 0:
            pan_chan[k] = pan + 1
        elif pan_chan[k] != pan + 1:
            warn("pan", f"channel {k}: panning differs from the other files of the collection")

    # patterns
    patts = [s3m_pattern(d, p) for p in pat_ptr]
    used = set()
    for rows in patts:
        for row in rows:
            for ch in chans:
                if row[ch] and row[ch][1]:
                    used.add(row[ch][1])
    sinfo = s3m_samples(d, ins_ptr, ffi, used)

    # parts of the order list: 255 ends a part, 254 is skipped
    parts = []
    part = []
    for i, p in enumerate(orders):
        if p == 255:
            if part:
                parts.append(part)
            part = []
        elif p != 254:
            part.append((i, p))
    if part:
        parts.append(part)

    lists = []
    for part in parts:
        pos_of = {i: k for k, (i, p) in enumerate(part)}
        jump = lambda target: pos_of.get(target)
        state = [dict(ins=0, mem=0) for k in range(nchan)]
        sng_list = bytearray()
        for i, p in part:
            if p >= patnum:
                warn("badpat", f"order {i}: pattern {p} does not exist -> empty pattern")
                rows = s3m_pattern(d, 0)
            else:
                rows = patts[p]
            patt = []
            for k in range(nchan):
                bin_chan = bytearray()
                ch = chans[k] if k < len(chans) else None
                for row in rows:
                    cell = row[ch] if ch is not None else None
                    if cell is None:
                        bin_chan += bytearray(4)
                    else:
                        bin_chan += s3m_cell(cell, state[k], sinfo, jump)
                patt.append(add_chan(bin_chan, True))
            sng_list.append(add_patt(patt))
        lists.append(sng_list)
    print(f"  {len(parts)} part(s): " + ", ".join(f"{len(l)} positions" for l in lists))
    for key, n in s3m_warn.items():
        if n > 3:
            print(f"  ({n} warnings of the kind '{key}')")
    return lists


### ---------------------------------------------------------------------------
### merge MOD/S3M files
### ---------------------------------------------------------------------------
def mod_merge(files, file_out):

    global arr_chan, arr_chcv, arr_patt, arr_samp, num_chan, pan_chan, swm_flags, ofs_pairs
    ofs_pairs = []
    arr_chan = []
    arr_chcv = []
    arr_patt = []
    arr_samp = []
    arr_list = []
    len_list = []
    num_chan = 4
    pan_chan = [0] * 8
    swm_flags = 0

    # add modules
    for file in files:
        if file.lower().endswith(".s3m"):
            lists = s3m_add(file)
        else:
            lists = mod_add(file)
        for sng_list in lists:
            len_list.append(len(sng_list))
            arr_list.extend(sng_list)

    if len(arr_samp) > 63:
        sys.exit(f"ERROR: {len(arr_samp)} samples, the SWM format allows 63")
    if len(arr_patt) > 255:
        sys.exit(f"ERROR: {len(arr_patt)} patterns, the SWM format allows 255")
    if len(len_list) > 32:
        sys.exit(f"ERROR: {len(len_list)} subsongs, the SWM format allows 32")

    # compress channels -> reduce double/empty slots
    ofs_chan = []
    siz_chan = 0
    for i in range(len(arr_chan)):
        ofs_chan.append(siz_chan)
        arr_chan[i] = compress_chan(arr_chan[i], arr_chcv[i])
        siz_chan += len(arr_chan[i])
    chan_empty = -1
    for patt in arr_patt:                           # patterns with less channels get empty ones
        while len(patt) < num_chan:
            if chan_empty < 0:
                chan_empty = len(arr_chan)
                ofs_chan.append(siz_chan)
                arr_chan.append(compress_chan(bytearray(64 * 4), True))
                siz_chan += len(arr_chan[chan_empty])
            patt.append(chan_empty)

    # build output binary
    bin_head =  bytearray("WM", 'utf-8')

    bin_data  = bytearray([len(arr_samp)])          # number of samples
    bin_data += bytearray([len(arr_patt)])          # number of pattern
    bin_data += bytearray([num_chan])               # number of channels
    bin_data += bytearray(pan_chan)                 # panning per channel
    bin_data += bytearray([swm_flags])              # flags
    bin_data += bytearray(4)                        # *res*

    bin_data += bytearray(len_list)                 # subsong lengthes
    bin_data += bytearray(32-len(len_list))

    bin_data += bytearray(arr_list)                 # global playlist

    for i in range(len(arr_samp)):                  # sample header data
        bin_data += bytearray(2) + arr_samp[i][0:6]
    if ofs_pairs:                                   # sample offset table
        bin_data[11] |= 4
        bin_data += bytearray([len(ofs_pairs)])
        for sid, off in ofs_pairs:
            bin_data += bytearray([sid, off, 0])
    ofs_total = len(bin_data) + len(arr_patt) * num_chan * 2
    for i in range(len(arr_patt)):                  # pattern data
        for j in range(num_chan):
            bin_data += word_bin(ofs_chan[arr_patt[i][j]] + ofs_total)
    for i in range(len(arr_chan)):                  # channel data
        bin_data += arr_chan[i]

    bin_samp = bytearray()
    for i in range(len(arr_samp)):
        bin_samp += arr_samp[i][6:]

    print(f"{len(arr_samp)} samples ({len(bin_samp)} bytes), {len(arr_patt)} patterns, {len(arr_chan)} channels, {num_chan} channels per pattern, {len(len_list)} subsong(s), {len(ofs_pairs)} sample offset variants")
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
