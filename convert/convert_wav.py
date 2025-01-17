import subprocess
import os, glob, sys

### ===========================================================================
### WAV TO SWX CONVERTER
### ===========================================================================

"""
Merges multiple WAV sample files into one SWX SymbOS Sound Daemon effect file.

usage:
python3 convert_wav.py [filemask].wav fileout.swx
-> merges multiple WAVs into one SWX, which results in one effect collection,
   where the first WAV in the list will have ID=0, the next ID=1 etc.

python3 convert_wav.py [filemask].wav
-> convertes multiple WAVs into multiple SWXs, which results in one effect
   (with ID=0) per SWX
"""

"""

todo

"""

WAV_FMT_CODE    = 0
WAV_FMT_CHAN    = 2
WAV_FMT_RATE    = 8
WAV_FMT_BITS    = 14


"""
SWX format

0000000        2B   "WX"
0000002        1W   total data length without samples

0000000        1B   number of samples (1-192)
0000001      ???B   sample data (number of samples*8)
                    2B   0
                    2B   length
                    2B   repeat offset
                    1B   0
                    1B   ?
"""



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
### get RIFF chunk
### ---------------------------------------------------------------------------
def riff_chunk(binary, id_text):
    offset = 12
    bin_chk = bytearray()
    while offset < len(binary):
        len_bin = binary[offset+4:offset+8]
        len_chk = len_bin[0] + len_bin[1] * 256 + len_bin[2] * 65536 + len_bin[3] * 256 * 65536
        if binary[offset:offset+4].decode("utf-8") == id_text:
            bin_chk = binary[offset+8:offset+8+len_chk]
            break
        offset += len_chk + 8

    return bin_chk


### ---------------------------------------------------------------------------
### add one WAV
### ---------------------------------------------------------------------------
def wav_add(file):

    print(f"adding {file}...")
    bin_wav = bin_load(file)
    if (bin_wav[0:4].decode("utf-8") != "RIFF") or (bin_wav[8:12].decode("utf-8") != "WAVE"):
        print("no WAV header")
        return bytearray(),bytearray()

    bin_fmt  = riff_chunk(bin_wav, "fmt ")
    bin_data = riff_chunk(bin_wav, "data")

    if (len(bin_fmt) == 0) or (len(bin_data) == 0):
        print("corrupt file")
        return bytearray(),bytearray()
    if bin_fmt[WAV_FMT_CODE] != 1:
        print("unsupported data format code")
        return bytearray(),bytearray()
    if bin_fmt[WAV_FMT_CHAN] != 1:
        print("not a mono wav")
        return bytearray(),bytearray()
    if (bin_fmt[WAV_FMT_BITS] != 8) and (bin_fmt[WAV_FMT_BITS] != 16):
        print("unsupported bit depth")
        return bytearray(),bytearray()

    rate = bin_fmt[WAV_FMT_RATE] + bin_fmt[WAV_FMT_RATE+1]*256
    pitch = 11025*324/rate      # 324 = 11025Hz on the Amiga
    if pitch < 108:
        print(f"pitch {pitch}/rate {rate} too low")
        pitch = 108
    if pitch > 907:
        print(f"pitch {pitch}/rate {rate} too high")
        pitch = 907

    bin_sample = bytearray()
    if bin_fmt[WAV_FMT_BITS] == 8:
        for i in range(len(bin_data)):
            bin_sample += bytearray([(bin_data[i]+128) % 256])
    elif bin_fmt[WAV_FMT_BITS] == 16:
        for i in range(len(bin_data)):
            bin_sample += bytearray([bin_data[i*2+1]])

    b = bin_sample[len(bin_sample) - 1]
    for i in range(3):
        bin_sample += bytearray([b])        # add last byte 3 times because of a strange behaviour of the OPL4 when looping a sample

    if len(bin_sample) > 65534:
        print("sample too big")
        return bytearray(),bytearray()

    bin_head = bytearray(2) + word_bin(len(bin_sample)) + bytearray([255, 255, 0, int(pitch/4)])

    return bin_head, bin_sample


### ---------------------------------------------------------------------------
### merge WAV files
### ---------------------------------------------------------------------------
def wav_merge(files, file_out):

    all_head   = bytearray()
    all_sample = bytearray()
    all_num    = 0

    # add MODs
    for file in files:
        bin_head, bin_sample = wav_add(file)
        if len(bin_head) > 0:
            all_head   += bin_head
            all_sample += bin_sample
            all_num    += 1

    file_pre, file_ext = os.path.splitext(file_out)
    bin_save(file_pre + ".swx", bytearray("WX", 'utf-8') + word_bin(len(all_head) + 1) + bytearray([all_num]) + all_head + all_sample)


### batch
files = glob.glob(sys.argv[1])
if len(files) == 0:
    print("File(s) not found")
if len(sys.argv) == 3:
    file_out = sys.argv[2]
    wav_merge(files, file_out)
else:
    for file in files:
        wav_merge([file], file)
