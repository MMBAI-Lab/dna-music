# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **DNA-to-music sonification research project** ("ABC Musica Molla"). It maps DNA tetranucleotide sequence dynamics — derived from molecular dynamics simulations — to musical parameters. The project was presented at YIB2024 (see `MollaDans_YIB2024.pptx`).

The core scientific concept: DNA double helix grooves (major and minor) open and close dynamically. These opening/closing events are measured from MD simulations for each unique 4-base DNA sequence (tetranucleotide), and the resulting metrics become musical parameters.

## Data Format

There are 140 `.dat` files per groove type (not 256 — only unique tetranucleotides, accounting for reverse-complement symmetry). Each file is a plain UTF-8 text file (4 lines) despite the binary-seeming `.dat` extension:

```
Entradas: 52660
Frecuencia de entrada: 0.052660 por ps
Tiempo de vida media: 5.260179 ps
Ocupación: 27.700100 %
```

Fields:
- **Entradas**: Number of groove-opening events observed in the simulation
- **Frecuencia de entrada**: Event frequency (events per picosecond)
- **Tiempo de vida media**: Mean lifetime of the open-groove state (picoseconds)
- **Ocupación**: Fraction of simulation time spent in open state (%)

## Directory Structure

```
source/
  MUSIC.majorgroove/            # 140 files, named XXXX.MG.dat (uppercase extension)
  MUSIC.minorgroove/            # 140 files, named XXXX.mg.dat (lowercase extension)
  MollaDans_YIB2024.pptx        # Main research presentation (~299 MB)
  Full score ADN MiniABC.pdf    # Full musical score (reference)
  SecuenciaMiniABC_1_RAW.wav    # Reference audio: stereo, 44100 Hz, 16-bit PCM, ~17s
                                #   (has a JUNK chunk before fmt — common in DAW exports)
data/
  notas_cromaticas_C1_a_C7.csv          # Chromatic scale C1–C7, frequencies in Hz (3 decimals)
  notas_256_majorgroove.csv             # All 256 tetranucleotides → note mapping, major groove
  notas_256_minorgroove.csv             # All 256 tetranucleotides → note mapping, minor groove
script/
  generar_midi.pl                       # Perl script: DNA sequence → MIDI file
aprox1/prueba1/prueba1.mid              # First test: 58 quarter notes, major groove, 120 BPM
```

Tetranucleotide names use IUPAC DNA bases: A, C, G, T. File names encode the central step of a DNA duplex (e.g., `AACG.MG.dat` = tetranucleotide AACG).

## Working with the Data

To read a data file, use `xxd` or any text reader (files are UTF-8 despite binary extension):

```bash
xxd MUSIC.majorgroove/AAAA.MG.dat
```

To list all tetranucleotides with their occupancy values (for both grooves):
```bash
for f in MUSIC.majorgroove/*.MG.dat; do
  base=$(basename "$f" .MG.dat)
  occ=$(xxd "$f" | grep -oP '[\d.]+(?= %)' )
  echo "$base $occ"
done
```

The minor groove files use lowercase `.mg.dat`; major groove uses uppercase `.MG.dat`.
