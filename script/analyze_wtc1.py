import xml.etree.ElementTree as ET
import os
import re
from collections import Counter, defaultdict

base_dir = r'c:\Users\pablo\Documents\2026\PROYECTO - ABC musica Molla\source\wtc1_xml'

# Pitch to MIDI number helper
STEP_TO_SEMITONE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def pitch_to_midi(step, octave, alter=0):
    return (int(octave) + 1) * 12 + STEP_TO_SEMITONE[step] + int(alter)

def interval_category(semitones):
    s = abs(semitones)
    s = s % 12  # fold to octave
    if s == 0: return 'unison/octave'
    elif s == 1: return 'semitone(m2)'
    elif s == 2: return 'tone(M2)'
    elif s == 3: return 'm3'
    elif s == 4: return 'M3'
    elif s == 5: return 'P4'
    elif s == 6: return 'TT'
    elif s == 7: return 'P5'
    elif s == 8: return 'm6'
    elif s == 9: return 'M6'
    elif s == 10: return 'm7'
    elif s == 11: return 'M7'
    return 'other'

KEY_NAMES = {
    (0, 'major'): 'C major',
    (0, 'minor'): 'C minor',
    (1, 'major'): 'G major',
    (1, 'minor'): 'G minor',
    (2, 'major'): 'D major',
    (2, 'minor'): 'D minor',
    (3, 'major'): 'A major',
    (3, 'minor'): 'A minor',
    (4, 'major'): 'E major',
    (4, 'minor'): 'E minor',
    (5, 'major'): 'B major',
    (5, 'minor'): 'B minor',
    (6, 'major'): 'F# major',
    (6, 'minor'): 'F# minor',
    (7, 'major'): 'C# major',
    (7, 'minor'): 'C# minor',
    (-1, 'major'): 'F major',
    (-1, 'minor'): 'F minor',
    (-2, 'major'): 'Bb major',
    (-2, 'minor'): 'Bb minor',
    (-3, 'major'): 'Eb major',
    (-3, 'minor'): 'Eb minor',
    (-4, 'major'): 'Ab major',
    (-4, 'minor'): 'Ab minor',
    (-5, 'major'): 'Db major',
    (-5, 'minor'): 'Db minor',
    (-6, 'major'): 'Gb major',
    (-6, 'minor'): 'Gb minor',
    (-7, 'major'): 'Cb major',
    (-7, 'minor'): 'Cb minor',
}

def analyze_file(filepath):
    bwv = os.path.basename(filepath).replace('BWV_', '').replace('.xml', '')
    tree = ET.parse(filepath)
    root = tree.getroot()

    result = {'bwv': bwv}

    # Title info from direction words
    title_words = []
    for w in root.iter('words'):
        t = (w.text or '').strip()
        if t and ('Bach' not in t) and len(t) < 200:
            title_words.append(t)
    result['title_words'] = title_words[:5]

    # Part list
    parts = root.findall('.//score-part')
    result['num_parts'] = len(parts)
    part_ids = [p.get('id') for p in parts]

    # Key signatures found (may change)
    keys = []
    for k in root.iter('key'):
        fifths_el = k.find('fifths')
        mode_el = k.find('mode')
        if fifths_el is not None:
            fifths = int(fifths_el.text)
            mode = mode_el.text if mode_el is not None else 'major'
            keys.append((fifths, mode))
    result['keys'] = keys

    # Time signatures
    times = []
    for t in root.iter('time'):
        beats_el = t.find('beats')
        bt_el = t.find('beat-type')
        if beats_el is not None:
            times.append(f"{beats_el.text}/{bt_el.text if bt_el is not None else '?'}")
    result['times'] = times

    # Tempo
    tempos = []
    for s in root.iter('sound'):
        t = s.get('tempo')
        if t:
            tempos.append(float(t))
    result['tempos'] = tempos

    # Harmony elements
    harmonies = list(root.iter('harmony'))
    result['num_harmonies'] = len(harmonies)

    # Now analyze measures: detect Preludio vs Fuga sections
    # Look for section markers in direction/words
    all_measures = root.findall('.//measure')
    result['total_measures'] = len(all_measures)

    # Find Preludio and Fuga boundary
    preludio_start = None
    fuga_start = None
    fuga_voices_set = set()

    measure_sections = {}  # measure_num -> section

    for measure in all_measures:
        mnum = int(measure.get('number', 0))
        for w in measure.iter('words'):
            txt = (w.text or '').lower()
            if 'prälud' in txt or 'prelude' in txt or 'präludium' in txt or 'prélude' in txt:
                measure_sections[mnum] = 'preludio'
                if preludio_start is None:
                    preludio_start = mnum
            elif 'fuge' in txt or 'fugue' in txt or 'fuga' in txt:
                measure_sections[mnum] = 'fuga'
                if fuga_start is None:
                    fuga_start = mnum

    if preludio_start is None:
        preludio_start = 1

    # Collect notes by section
    # We'll use a simple heuristic: if fuga_start is known, split there
    # Otherwise look at voice count changes

    notes_preludio = []
    notes_fuga = []
    voices_preludio = set()
    voices_fuga = set()
    note_types_preludio = Counter()
    note_types_fuga = Counter()

    current_section = 'preludio'
    preludio_measures = set()
    fuga_measures = set()

    # Stretto detection: multiple entrances close together
    # We'll look for subject-like motifs but that's complex; skip for now

    for measure in all_measures:
        mnum = int(measure.get('number', 0))

        # Determine section from marker or boundary
        if mnum in measure_sections:
            current_section = measure_sections[mnum]
        elif fuga_start and mnum >= fuga_start:
            current_section = 'fuga'
        else:
            current_section = 'preludio'

        if current_section == 'preludio':
            preludio_measures.add(mnum)
        else:
            fuga_measures.add(mnum)

        for note in measure.findall('note'):
            rest = note.find('rest')
            if rest is not None:
                continue

            voice_el = note.find('voice')
            voice = voice_el.text if voice_el is not None else '1'

            type_el = note.find('type')
            ntype = type_el.text if type_el is not None else 'unknown'

            pitch_el = note.find('pitch')
            if pitch_el is None:
                continue

            step_el = pitch_el.find('step')
            oct_el = pitch_el.find('octave')
            alter_el = pitch_el.find('alter')

            if step_el is None or oct_el is None:
                continue

            step = step_el.text
            octave = int(oct_el.text)
            alter = int(float(alter_el.text)) if alter_el is not None else 0
            midi = pitch_to_midi(step, octave, alter)

            dot = note.find('dot') is not None

            if current_section == 'preludio':
                notes_preludio.append((midi, voice, ntype, dot))
                voices_preludio.add(voice)
                note_types_preludio[ntype] += 1
            else:
                notes_fuga.append((midi, voice, ntype, dot))
                voices_fuga.add(voice)
                note_types_fuga[ntype] += 1

    result['preludio_measures'] = len(preludio_measures)
    result['fuga_measures'] = len(fuga_measures)
    result['voices_preludio'] = sorted(voices_preludio)
    result['voices_fuga'] = sorted(voices_fuga)
    result['note_types_preludio'] = note_types_preludio
    result['note_types_fuga'] = note_types_fuga
    result['fuga_start_measure'] = fuga_start

    # Melodic intervals
    def compute_intervals(notes_list):
        intervals = Counter()
        prev_midi = None
        for (midi, voice, ntype, dot) in notes_list:
            if prev_midi is not None:
                diff = midi - prev_midi
                cat = interval_category(diff)
                intervals[cat] += 1
            prev_midi = midi
        return intervals

    result['mel_intervals_preludio'] = compute_intervals(notes_preludio)
    result['mel_intervals_fuga'] = compute_intervals(notes_fuga)

    # Harmonic intervals: notes sounding simultaneously
    # Approximate by same measure, check chord notes (notes with <chord/>)
    harmonic_intervals = Counter()
    for measure in all_measures:
        # Group by voice and look for chords
        chord_groups = []
        current_chord = []
        for note in measure.findall('note'):
            rest = note.find('rest')
            if rest is not None:
                current_chord = []
                continue
            chord_el = note.find('chord')
            pitch_el = note.find('pitch')
            if pitch_el is None:
                continue
            step_el = pitch_el.find('step')
            oct_el = pitch_el.find('octave')
            alter_el = pitch_el.find('alter')
            if step_el is None or oct_el is None:
                continue
            midi = pitch_to_midi(step_el.text, oct_el.text,
                                  int(float(alter_el.text)) if alter_el is not None else 0)

            if chord_el is not None:
                current_chord.append(midi)
            else:
                if current_chord:
                    chord_groups.append(current_chord)
                current_chord = [midi]
        if current_chord:
            chord_groups.append(current_chord)

        for group in chord_groups:
            if len(group) >= 2:
                group_sorted = sorted(group)
                for i in range(len(group_sorted)-1):
                    diff = group_sorted[i+1] - group_sorted[i]
                    cat = interval_category(diff)
                    harmonic_intervals[cat] += 1

    result['harmonic_intervals'] = harmonic_intervals

    # Check for chromatic elements (alterations)
    chromatic_count = 0
    for measure in all_measures:
        for note in measure.findall('note'):
            pitch_el = note.find('pitch')
            if pitch_el is None:
                continue
            alter_el = pitch_el.find('alter')
            if alter_el is not None:
                chromatic_count += 1
    result['chromatic_notes'] = chromatic_count

    return result


# Analyze all files
files = sorted([f for f in os.listdir(base_dir) if f.endswith('.xml')])
all_results = []

for fname in files:
    fpath = os.path.join(base_dir, fname)
    try:
        r = analyze_file(fpath)
        all_results.append(r)
    except Exception as e:
        print(f"ERROR in {fname}: {e}")

print("Analysis complete for", len(all_results), "files")

# Print results per file
for r in all_results:
    bwv = r['bwv']
    keys = r['keys']

    # Primary key (first key signature found)
    if keys:
        fifths, mode = keys[0]
        key_name = KEY_NAMES.get((fifths, mode), f"fifths={fifths} {mode}")
    else:
        key_name = "unknown"
        mode = "?"

    # Key changes
    unique_keys = list(dict.fromkeys(keys))  # preserve order, deduplicate

    times = r['times']
    time_preludio = times[0] if times else "?"
    # Fuga time: look for a second time signature if present
    time_fuga = times[1] if len(times) > 1 else time_preludio

    # Note types
    def top_types(counter, n=4):
        if not counter:
            return "none"
        total = sum(counter.values())
        top = counter.most_common(n)
        return ", ".join([f"{t}({v})" for t,v in top])

    def top_intervals(counter, n=5):
        if not counter:
            return "none"
        top = counter.most_common(n)
        return ", ".join([f"{t}({v})" for t,v in top])

    # Dots
    has_dots_p = sum(1 for (m,v,t,d) in [] if d)  # simplified

    voices_p = r['voices_preludio']
    voices_f = r['voices_fuga']

    print(f"\n{'='*70}")
    print(f"BWV {bwv} — Tonalidad: {key_name} | Key changes: {unique_keys}")
    print(f"  Compas P: {time_preludio} | Compas F: {time_fuga}")
    print(f"  Preludio: {len(voices_p)} voces {voices_p}, {r['preludio_measures']} compases")
    print(f"  Fuga: {len(voices_f)} voces {voices_f}, {r['fuga_measures']} compases (empieza compas {r['fuga_start_measure']})")
    print(f"  Tipos nota Preludio: {top_types(r['note_types_preludio'])}")
    print(f"  Tipos nota Fuga: {top_types(r['note_types_fuga'])}")
    print(f"  Intervalos mel. Preludio: {top_intervals(r['mel_intervals_preludio'])}")
    print(f"  Intervalos mel. Fuga: {top_intervals(r['mel_intervals_fuga'])}")
    print(f"  Intervalos armonicos: {top_intervals(r['harmonic_intervals'])}")
    print(f"  Notas cromaticas: {r['chromatic_notes']} | Harmonias XML: {r['num_harmonies']}")
    print(f"  Titulo: {r['title_words']}")
    if r['tempos']:
        print(f"  Tempo: {r['tempos'][:3]}")

print("\n\n" + "="*70)
print("SUMMARY GLOBAL")
print("="*70)

# Global key distribution
major_keys = []
minor_keys = []
for r in all_results:
    if r['keys']:
        fifths, mode = r['keys'][0]
        kname = KEY_NAMES.get((fifths, mode), f"fifths={fifths} {mode}")
        if mode == 'major':
            major_keys.append(kname)
        else:
            minor_keys.append(kname)

print(f"\nTonalidades MAYORES ({len(major_keys)}): {major_keys}")
print(f"Tonalidades MENORES ({len(minor_keys)}): {minor_keys}")

# Global rhythmic patterns
all_preludio_types = Counter()
all_fuga_types = Counter()
for r in all_results:
    all_preludio_types += r['note_types_preludio']
    all_fuga_types += r['note_types_fuga']

print(f"\nRitmo global PRELUDIOS: {all_preludio_types.most_common(8)}")
print(f"Ritmo global FUGAS: {all_fuga_types.most_common(8)}")

# Global intervals
all_mel_p = Counter()
all_mel_f = Counter()
all_harm = Counter()
for r in all_results:
    all_mel_p += r['mel_intervals_preludio']
    all_mel_f += r['mel_intervals_fuga']
    all_harm += r['harmonic_intervals']

print(f"\nIntervalos melodicos PRELUDIOS: {all_mel_p.most_common(8)}")
print(f"Intervalos melodicos FUGAS: {all_mel_f.most_common(8)}")
print(f"Intervalos armonicos globales: {all_harm.most_common(8)}")

# Fuga voice counts
print("\nConteo de voces por fuga:")
for r in all_results:
    print(f"  BWV {r['bwv']}: {len(r['voices_fuga'])} voces {r['voices_fuga']}")

# Chromaticism
print("\nCromatismo (notas alteradas):")
for r in all_results:
    print(f"  BWV {r['bwv']}: {r['chromatic_notes']}")
