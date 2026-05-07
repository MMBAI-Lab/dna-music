import xml.etree.ElementTree as ET
import os
import re
from collections import Counter, defaultdict

base_dir = r'c:\Users\pablo\Documents\2026\PROYECTO - ABC musica Molla\source\wtc1_xml'

STEP_TO_SEMITONE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def pitch_to_midi(step, octave, alter=0):
    return (int(octave) + 1) * 12 + STEP_TO_SEMITONE[step] + int(alter)

def interval_category(semitones):
    s = abs(semitones) % 12
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

def safe_int(s):
    """Convert measure number string to int, stripping non-numeric suffix."""
    m = re.match(r'^(\d+)', str(s))
    if m:
        return int(m.group(1))
    return 0

def analyze_file(filepath):
    bwv = os.path.basename(filepath).replace('BWV_', '').replace('.xml', '')
    tree = ET.parse(filepath)
    root = tree.getroot()

    result = {'bwv': bwv}

    title_words = []
    for w in root.iter('words'):
        t = (w.text or '').strip()
        if t and len(t) < 200:
            title_words.append(t)
    result['title_words'] = title_words[:8]

    # Key
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
    result['times'] = list(dict.fromkeys(times))  # deduplicated

    # Tempo
    tempos = []
    for s in root.iter('sound'):
        t = s.get('tempo')
        if t:
            tempos.append(float(t))
    result['tempos'] = tempos

    # Harmony
    harmonies = list(root.iter('harmony'))
    result['num_harmonies'] = len(harmonies)

    # Measures
    all_measures = root.findall('.//measure')
    result['total_measures'] = len(all_measures)

    preludio_start = None
    fuga_start = None
    measure_sections = {}

    for measure in all_measures:
        mnum = safe_int(measure.get('number', 0))
        for w in measure.iter('words'):
            txt = (w.text or '').lower()
            if 'prälud' in txt or 'prelude' in txt or 'präludium' in txt:
                measure_sections[mnum] = 'preludio'
                if preludio_start is None:
                    preludio_start = mnum
            elif 'fuge' in txt or 'fugue' in txt or 'fuga' in txt:
                measure_sections[mnum] = 'fuga'
                if fuga_start is None:
                    fuga_start = mnum

    if preludio_start is None:
        preludio_start = 1

    notes_preludio = []
    notes_fuga = []
    voices_preludio = set()
    voices_fuga = set()
    note_types_preludio = Counter()
    note_types_fuga = Counter()

    current_section = 'preludio'
    preludio_measures = set()
    fuga_measures = set()

    for measure in all_measures:
        mnum = safe_int(measure.get('number', 0))

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
            octave = oct_el.text
            alter = int(float(alter_el.text)) if alter_el is not None else 0
            midi = pitch_to_midi(step, octave, alter)

            if current_section == 'preludio':
                notes_preludio.append((midi, voice, ntype))
                voices_preludio.add(voice)
                note_types_preludio[ntype] += 1
            else:
                notes_fuga.append((midi, voice, ntype))
                voices_fuga.add(voice)
                note_types_fuga[ntype] += 1

    result['preludio_measures'] = len(preludio_measures)
    result['fuga_measures'] = len(fuga_measures)
    result['voices_preludio'] = sorted(voices_preludio)
    result['voices_fuga'] = sorted(voices_fuga)
    result['note_types_preludio'] = note_types_preludio
    result['note_types_fuga'] = note_types_fuga
    result['fuga_start_measure'] = fuga_start

    def compute_intervals(notes_list):
        intervals = Counter()
        prev_midi = None
        for (midi, voice, ntype) in notes_list:
            if prev_midi is not None:
                diff = midi - prev_midi
                cat = interval_category(diff)
                intervals[cat] += 1
            prev_midi = midi
        return intervals

    result['mel_intervals_preludio'] = compute_intervals(notes_preludio)
    result['mel_intervals_fuga'] = compute_intervals(notes_fuga)

    # Harmonic intervals from chords
    harmonic_intervals = Counter()
    for measure in all_measures:
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

    # Chromatic count
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

for bwv_file in ['BWV_0856.xml', 'BWV_0861.xml']:
    fpath = os.path.join(base_dir, bwv_file)
    try:
        r = analyze_file(fpath)
        print(f"\nBWV {r['bwv']}:")
        print(f"  Keys: {r['keys']}")
        print(f"  Times: {r['times']}")
        print(f"  Tempos: {r['tempos']}")
        print(f"  Title words: {r['title_words']}")
        print(f"  Preludio: {len(r['voices_preludio'])} voces {r['voices_preludio']}, {r['preludio_measures']} compases")
        print(f"  Fuga start: {r['fuga_start_measure']}, {len(r['voices_fuga'])} voces {r['voices_fuga']}, {r['fuga_measures']} compases")
        print(f"  Note types preludio: {r['note_types_preludio'].most_common(5)}")
        print(f"  Note types fuga: {r['note_types_fuga'].most_common(5)}")
        print(f"  Mel intervals preludio: {r['mel_intervals_preludio'].most_common(5)}")
        print(f"  Mel intervals fuga: {r['mel_intervals_fuga'].most_common(5)}")
        print(f"  Harmonic intervals: {r['harmonic_intervals'].most_common(5)}")
        print(f"  Chromatic: {r['chromatic_notes']}")
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Error: {e}")
