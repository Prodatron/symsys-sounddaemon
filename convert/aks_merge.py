import xml.etree.ElementTree as ET
import subprocess
import os, glob, sys
from zipfile import ZipFile, ZIP_DEFLATED


### ===========================================================================
### AKS MUSIC MODULE MERGER
### ===========================================================================

"""
Merges multiple AKS music modules into one, using the subsong feature. Double
instuments will be shared.

usage:
python3 aks_merge.py [filemask].aks [fileout].aks

example:

python3 aks_merge.py lemmings*.aks lemmings-all.aks
"""


TAG_PRE = "{http://www.julien-nevo.com/ArkosTrackerSong}"
TAG_INSTR = TAG_PRE + "fmInstruments"
TAG_ARPEG = TAG_PRE + "arpeggios"
TAG_PITCH = TAG_PRE + "pitchs"
TAG_SONGS = TAG_PRE + "subsongs"

instr_all = []
arpeg_all = []
pitch_all = []

instr_trl = {}
arpeg_trl = {}
pitch_trl = {}

instr_nam = []
arpeg_nam = []
pitch_nam = []


### ---------------------------------------------------------------------------
### get unziped file from aks
### ---------------------------------------------------------------------------
def zipget(file):
    archive = ZipFile(file, mode="r")
    file_xml = archive.namelist()[0]
    archive.extract(file_xml, path="tmpaks/")
    archive.close()
    return "tmpaks/" + file_xml


### ---------------------------------------------------------------------------
### execute shell command
### ---------------------------------------------------------------------------
def run_cmd(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    c = p.communicate()


### ---------------------------------------------------------------------------
### return integer as #-hexstr
### ---------------------------------------------------------------------------
def hexstr(value):
    return "#" + hex(value).replace("0x","")


### ---------------------------------------------------------------------------
### return mainpart of filename
### ---------------------------------------------------------------------------
def file_main(file):
    file_pre, file_ext = os.path.splitext(file)
    return file_pre


### ---------------------------------------------------------------------------
### adds an element list to the global list
### ---------------------------------------------------------------------------
def elements_add(elements, elements_all, elements_trl, elements_nam, sub_id, name):
    for element in elements:
        elold_id = element[0].text
        el_name = element[1].text
        element[0].text = "-"
        element[1].text = "#"
        i = 0
        elnew_id = 0
        for elall in elements_all:
            if ET.tostring(elall) == ET.tostring(element):
                elnew_id = i + 1
                print(f"double {name} at {elnew_id} in subsong {sub_id}")
                break
            i += 1
        if elnew_id == 0:
            elnew_id = len(elements_all) + 1
            elements_all.append(element)
            elements_nam.append(el_name)

        elements_trl[sub_id + "-" + elold_id] = elnew_id

    return elements_all, elements_trl, elements_nam


### ---------------------------------------------------------------------------
### rebuild element list
### ---------------------------------------------------------------------------
def elements_rebuild(root, tagstr, elem_all, elem_nam):
    for elements in root.findall(tagstr):
        while len(elements) > 0:
            for element in elements:
                elements.remove(element)
    elements = root.find(tagstr)
    i = 0
    for element in elem_all:
        if len(elem_nam) > 0:
            element[1].text = elem_nam[i]
            i += 1
            element[0].text = str(i)
        elements.append(element)


### ---------------------------------------------------------------------------
### adds all AKS elements to the global lists
### ---------------------------------------------------------------------------
def aks_add(root, sub_id):
    global instr_all, arpeg_all, pitch_all
    global instr_trl, arpeg_trl, pitch_trl
    global instr_nam, arpeg_nam, pitch_nam

    for child in root.findall(TAG_INSTR):
        instr_all, instr_trl, instr_nam = elements_add(child, instr_all, instr_trl, instr_nam, sub_id, "instr")
    for child in root.findall(TAG_ARPEG):
        arpeg_all, arpeg_trl, arpeg_nam = elements_add(child, arpeg_all, arpeg_trl, arpeg_nam, sub_id, "arpeg")
    for child in root.findall(TAG_PITCH):
        pitch_all, pitch_trl, pitch_nam = elements_add(child, pitch_all, pitch_trl, pitch_nam, sub_id, "pitch")


### ---------------------------------------------------------------------------
### merges multiple AKS as subsongs into one AKS
### ---------------------------------------------------------------------------
def aks_merge(files, file_out):
    global instr_all, arpeg_all, pitch_all
    global instr_trl, arpeg_trl, pitch_trl
    global instr_nam, arpeg_nam, pitch_nam
    songs_all = []

    sub_id = 0
    for file in files:
        print(f"Adding {file}...")
 
        tree = ET.parse(zipget(file))
        root = tree.getroot()
        aks_add(root, str(sub_id))
        for subsongs in root.findall(TAG_SONGS):
            for subsong in subsongs:
                subsong[0].text = file_main(file) + " - " + subsong[0].text
                for tracks in subsong.findall(TAG_PRE + "tracks"):
                    for track in tracks:
                        for cell in track.findall(TAG_PRE + "cell"):
                            for cellprop in cell:
                                if cellprop.tag == TAG_PRE + "instrument":                                              # translate instrument ID
                                    if cellprop.text != "0":
                                        cellprop.text = str(instr_trl[str(sub_id) + "-" + cellprop.text])
                                elif cellprop.tag == TAG_PRE + "effectAndValue":
                                    efxval = cellprop[2].text[1:]
                                    efxval = efxval[:len(efxval)-1]
                                    if efxval != "":
                                        if cellprop[1].text == "arpeggioTable":
                                            cellprop[2].text = hexstr(arpeg_trl[str(sub_id) + "-" + str(int(efxval, 16))]) + "0"  # translate arpeggio ID
                                        elif cellprop[1].text == "pitchTable":
                                            cellprop[2].text = hexstr(pitch_trl[str(sub_id) + "-" + str(int(efxval, 16))]) + "0"  # translate pitch ID
                songs_all.append(subsong)
        sub_id += 1

    tree = ET.parse(zipget(files[0]))
    root = tree.getroot()

    root[1].text = file_main(file_out)
    filstr = ""
    for file in files:
        filstr += file_main(file) + ", "
    root[4].text = "contains: " + filstr[:len(filstr)-2]

    elements_rebuild(root, TAG_INSTR, instr_all, instr_nam)
    elements_rebuild(root, TAG_ARPEG, arpeg_all, arpeg_nam)
    elements_rebuild(root, TAG_PITCH, pitch_all, pitch_nam)
    elements_rebuild(root, TAG_SONGS, songs_all, [])

    xmlstr = ET.tostring(root).decode('utf-8')
    xmlstr = xmlstr.replace("ns0:", "aks:")
    xmlstr = xmlstr.replace("ns0=", "aks=")

    fil = open(file_out, "w")
    fil.write(xmlstr)
    fil.close()

    archive = ZipFile("tmpaks.zip", "w", ZIP_DEFLATED, compresslevel=9)
    archive.write(file_out)
    archive.close()

    run_cmd(f"del {file_out}")
    run_cmd(f"ren tmpaks.zip {file_out}")
    run_cmd(f"rd tmpaks /S /Q")
    #run_cmd(f"python3 snd_reloc.py {file_out} M{len(songs_all)}")



### batch
if len(sys.argv) == 3:
    files = glob.glob(sys.argv[1])
    if len(files) == 0:
        print("File(s) not found")
    else:
        file_out = sys.argv[2]
        aks_merge(files, file_out)
else:
    print("Wrong arguments; use aks_merger.py [filemask].aks [fileout].aks")
