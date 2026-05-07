import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
import os
import glob

note_type_to_duration = {
    'whole': 4.0,
    'half': 2.0,
    'quarter': 1.0,
    'eighth': 0.5,
    '16th': 0.25,
    '32nd': 0.125,
    '64th': 0.0625
}

def extract_note_types(xml_file):
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except Exception as e:
        return []
    
    notes_sequence = []
    
    for note in root.findall('.//note'):
        if note.find('chord') is not None:
            continue
        if note.find('rest') is not None:
            continue
        
        type_elem = note.find('type')
        if type_elem is None:
            continue
        
        note_type = type_elem.text
        has_dot = note.find('dot') is not None
        
        notes_sequence.append((note_type, has_dot))
    
    return notes_sequence

def analyze_corpus(file_paths):
    all_notes = []
    
    for f in file_paths:
        notes = extract_note_types(f)
        all_notes.extend(notes)
    
    if not all_notes:
        return None
    
    types_sequence = [nt[0] for nt in all_notes]
    
    bigrams = []
    for i in range(len(types_sequence) - 1):
        bigrams.append((types_sequence[i], types_sequence[i+1]))
    
    bigram_counts = Counter(bigrams)
    total_bigrams = len(bigrams)
    
    durations = [note_type_to_duration[nt] for nt in types_sequence]
    ratio_categories = defaultdict(int)
    
    for i in range(len(durations) - 1):
        d1, d2 = durations[i], durations[i+1]
        ratio = d2 / d1 if d1 > 0 else 1
        
        if abs(ratio - 1.0) < 0.01:
            ratio_categories['1:1'] += 1
        elif abs(ratio - 2.0) < 0.01:
            ratio_categories['1:2'] += 1
        elif abs(ratio - 0.5) < 0.01:
            ratio_categories['2:1'] += 1
        elif abs(ratio - 3.0) < 0.01:
            ratio_categories['1:3'] += 1
        elif abs(ratio - 1/3) < 0.05:
            ratio_categories['3:1'] += 1
        elif abs(ratio - 1.5) < 0.1 or abs(ratio - 2/3) < 0.1:
            ratio_categories['dotted'] += 1
        else:
            ratio_categories['otros'] += 1
    
    trigrams = []
    for i in range(len(types_sequence) - 2):
        trigrams.append((types_sequence[i], types_sequence[i+1], types_sequence[i+2]))
    
    trigram_counts = Counter(trigrams)
    
    runs = []
    current_run_length = 1
    for i in range(1, len(types_sequence)):
        if types_sequence[i] == types_sequence[i-1]:
            current_run_length += 1
        else:
            runs.append(current_run_length)
            current_run_length = 1
    if current_run_length > 1:
        runs.append(current_run_length)
    
    avg_run_length = sum(runs) / len(runs) if runs else 0
    
    dotted_patterns = []
    for i in range(len(all_notes) - 1):
        if all_notes[i][1]:
            dotted_patterns.append((all_notes[i][0], all_notes[i+1][0]))
    
    dotted_count = len(dotted_patterns)
    dotted_pct = (dotted_count / total_bigrams * 100) if total_bigrams > 0 else 0
    
    return {
        'total_notes': len(types_sequence),
        'bigrams': bigram_counts,
        'total_bigrams': total_bigrams,
        'ratio_categories': dict(ratio_categories),
        'trigrams': trigram_counts,
        'runs': runs,
        'avg_run_length': avg_run_length,
        'dotted_patterns': dotted_patterns,
        'dotted_count': dotted_count,
        'dotted_pct': dotted_pct,
        'distribution_runs': Counter(runs)
    }

src_base = r'c:\Users\pablo\Documents\2026\PROYECTO - ABC musica Molla\source\wtc1_xml'
all_files = sorted(glob.glob(os.path.join(src_base, 'BWV_*.xml')))

print(f"Total de archivos encontrados: {len(all_files)}\n")

result = analyze_corpus(all_files)

if result:
    print("=== ANALISIS DE PATRONES RITMICOS - WTC Libro I (CORPUS COMPLETO) ===\n")
    
    print(f"Total de notas analizadas: {result['total_notes']}")
    print(f"Total de bigramas: {result['total_bigrams']}\n")
    
    print("1. TOP 15 TRANSICIONES (bigrams):")
    for (n1, n2), count in result['bigrams'].most_common(15):
        pct = (count / result['total_bigrams'] * 100)
        print(f"   {n1:6} -> {n2:6}: {count:5} ({pct:5.2f}%)")
    
    print("\n2. RATIO ENTRE DURACIONES:")
    total_ratios = sum(result['ratio_categories'].values())
    for cat in ['1:1', '1:2', '2:1', '1:3', '3:1', 'dotted', 'otros']:
        count = result['ratio_categories'].get(cat, 0)
        pct = (count / total_ratios * 100) if total_ratios > 0 else 0
        print(f"   {cat:8}: {pct:6.2f}%")
    
    print("\n3. TOP 10 TRIGRAMS:")
    for (n1, n2, n3), count in result['trigrams'].most_common(10):
        print(f"   {n1:6} -> {n2:6} -> {n3:6}: {count:5}")
    
    print(f"\n4. RUNS DE MISMA FIGURA:")
    print(f"   Longitud promedio: {result['avg_run_length']:.2f}")
    print(f"   Distribuciones (top 20 longitudes):")
    top_runs = result['distribution_runs'].most_common(20)
    for length, count in sorted(top_runs, key=lambda x: x[0]):
        print(f"     Longitud {length:3}: {count:4} runs")
    
    print(f"\n5. PATRONES PUNTEADOS:")
    print(f"   Ocurrencias totales: {result['dotted_count']}")
    print(f"   Porcentaje del corpus: {result['dotted_pct']:.2f}%")
    if result['dotted_patterns']:
        dotted_bigrams = Counter(result['dotted_patterns'])
        print(f"   Top patrones punteados:")
        for (n1, n2), count in dotted_bigrams.most_common(8):
            pct_of_dotted = (count / result['dotted_count'] * 100) if result['dotted_count'] > 0 else 0
            print(f"     {n1:6} (.) -> {n2:6}: {count:3} ({pct_of_dotted:5.2f}% de punteados)")
else:
    print("No se pudo analizar el corpus")

