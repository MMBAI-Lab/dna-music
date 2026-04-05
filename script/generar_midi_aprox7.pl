#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# aprox7/prueba1 — Correcciones con anticipación (lookahead)
#
# MEJORAS SOBRE aprox6:
#
# 1. ANTICIPACIÓN (lookahead +1):
#    Al generar la nota de corrección en posición i, se conoce ya la
#    nota de bajo en la posición i+1 (siempre conocida porque la
#    secuencia de ADN está disponible completa). Se elige la nota que
#    minimiza la disonancia tanto en i como en i+1.
#    → Esto hace el algoritmo universalmente aplicable a cualquier
#      secuencia: una app web puede precalcular toda la secuencia y
#      generar la música sin intervención manual.
#
# 2. PENALIZACIÓN DE SEMITONOS CROMÁTICOS:
#    Un movimiento de exactamente 1 semitono en una voz de corrección
#    suena ajeno a Re menor natural. Se penaliza con peso 12.
#    (Ejemplo: de Bb3 a A3 en el Alto suena a error, no a melodía.)
#
# 3. PENALIZACIÓN DE TRITONO:
#    En Re menor natural, el único tritono posible dentro de la escala
#    es Bb↔E (6 semitonos). Se penaliza el salto de tritono con peso 5.
#
# 4. MOVIMIENTO CONTRARIO A LA SOPRANO:
#    Cuando la soprano sube, las voces de corrección prefieren bajar
#    (y viceversa). Esto aumenta la independencia de voces y reduce
#    los paralelismos accidentales. Peso 3 de penalización por
#    movimiento paralelo con la soprano.
#
# 5. VERIFICACIÓN EXTENDIDA DE PARALELISMOS:
#    Se verifican S-A y B-T dentro de la función de coste
#    (no como corrección post-hoc separada).
#
# 6. ATRACCIÓN HACIA EL CENTRO DEL REGISTRO:
#    Penalización suave (peso ~1) por alejarse del centro del registro,
#    evitando que las voces se acumulen en los extremos.
#
# FUNCIÓN DE COSTE (Alto):
#   min(|movim.|,6) ×  1  — suavidad (cap en 6st)
#        semitono  × 12  — evitar cromatismo
#        tritono   ×  5  — evitar salto Bb↔E
#   disonancia[i]  × 15  — consonancia actual
#  disonancia[i+1] ×  8  — consonancia anticipada (lookahead)
#   < 3st soprano  ×  5  — espacio mínimo entre voces
#     paralel. S–A × 20  — 5as/8as paralelas S–A
#   dir. paralela  ×  3  — preferir movimiento contrario a soprano
#    nota repetida ×  3  — variedad melódica
#   distancia_cent ×  1  — atracción al centro del registro
#
# FUNCIÓN DE COSTE (Tenor) — igual + paralel. B–T × 20
#
# INSTRUMENTOS (igual que aprox6/prueba3):
#   Soprano  (Ch 0)  Acoustic Grand Piano  GM  0
#   Alto     (Ch 1)  Acoustic Grand Piano  GM  0
#   Tenor    (Ch 2)  Acoustic Grand Piano  GM  0
#   Bajo     (Ch 3)  Contrabass            GM 43
#
# REGLAS HEREDADAS (sin cambio):
#   R1. Snap S, B a Re menor natural {D,E,F,G,A,Bb,C}
#   R2. Forzar registro: S D4–D6, A G3–C5, T C3–G4, B D2–D4
#   R3. Voice leading S, B: salto > 7st → inversión por octava
#   R4. Alto y Tenor usan exclusivamente grados de Re menor
#   R7. Par S–B: si 5as/8as paralelas → mover soprano un grado arriba
#   R9. S+A comparten duración (major groove); T+B comparten (minor)
#
# REGLAS ELIMINADAS:
#   R8 (corrección post-hoc S–A) absorbida en la función de coste.
# =================================================================

my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
                G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub vlq {
    my ($val) = @_;
    return chr($val) if $val < 128;
    my @bytes;
    push @bytes, $val & 0x7F;
    $val >>= 7;
    while ($val > 0) { push @bytes, ($val & 0x7F) | 0x80; $val >>= 7; }
    return join('', map { chr($_) } reverse @bytes);
}

sub midi_chunk { $_[0] . pack('N', length($_[1])) . $_[1] }

# --- Escala Re menor natural ---
my @D_MINOR_CHROMA = (0, 2, 4, 5, 7, 9, 10); # D E F G A Bb C

sub snap_to_d_minor {
    my ($midi) = @_;
    my $chroma = $midi % 12;
    my $base   = $midi - $chroma;
    my ($best_c, $best_diff) = ($D_MINOR_CHROMA[0], 99);
    for my $c (@D_MINOR_CHROMA) {
        my $diff = abs($chroma - $c);
        $diff = 12 - $diff if $diff > 6;
        if ($diff < $best_diff) { $best_diff = $diff; $best_c = $c; }
    }
    my $new = $base + $best_c;
    $new += 12 if ($chroma - $best_c) > 6;
    $new -= 12 if ($best_c - $chroma) > 6;
    return $new;
}

sub force_register {
    my ($midi, $center, $lo, $hi) = @_;
    my $chroma = $midi % 12;
    my ($best, $best_diff) = ($midi, 999);
    for my $oct (0..9) {
        my $c = $oct * 12 + $chroma;
        next if $c < $lo || $c > $hi;
        my $diff = abs($c - $center);
        if ($diff < $best_diff) { $best_diff = $diff; $best = $c; }
    }
    return $best;
}

sub apply_voice_leading {
    my ($notes_ref, $max_leap, $lo, $hi) = @_;
    my @result = ($notes_ref->[0]);
    for my $i (1 .. $#$notes_ref) {
        my $prev = $result[-1];
        my $curr = $notes_ref->[$i];
        if (abs($curr - $prev) > $max_leap) {
            my $adj = ($curr > $prev) ? $curr - 12 : $curr + 12;
            $curr = $adj if $adj >= $lo && $adj <= $hi;
        }
        push @result, $curr;
    }
    return @result;
}

# --- Notas de Re menor dentro de un registro ---
sub d_minor_in_range {
    my ($lo, $hi) = @_;
    my @notes;
    for my $oct (0..9) { push @notes, $oct*12+$_ for @D_MINOR_CHROMA; }
    return sort { $a <=> $b } grep { $_ >= $lo && $_ <= $hi } @notes;
}

my @S_SCALE = d_minor_in_range(62, 86); # Soprano D4–D6
my @A_SCALE = d_minor_in_range(55, 72); # Alto    G3–C5
my @T_SCALE = d_minor_in_range(48, 67); # Tenor   C3–G4

# Centros de registro para atracción suave
my $A_CENTER = 62; # D4 — centro aprox. de G3–C5
my $T_CENTER = 57; # A3 — centro aprox. de C3–G4

# Consonancias aceptadas: P1, m3, M3, P5, m6, M6
my @CONSONANT = (0, 3, 4, 7, 8, 9);
sub is_consonant { my $i=($_[0]-$_[1])%12; scalar grep{$_==$i}@CONSONANT }

# 5as/8as paralelas entre dos pares consecutivos de notas
sub has_parallel {
    my ($v1p, $v2p, $v1c, $v2c) = @_;
    return 0 unless defined $v1p && defined $v2p;
    my $pi = ($v1p - $v2p) % 12;
    my $ci = ($v1c - $v2c) % 12;
    return (($pi==7 && $ci==7) || ($pi==0 && $ci==0)) ? 1 : 0;
}

# --- R7: Anti-paralelismos S–B (mueve soprano) ---
sub check_parallel_sb {
    my ($ps, $pb, $s, $b) = @_;
    return $s unless defined $ps;
    my ($pi, $ci) = (($ps-$pb)%12, ($s-$b)%12);
    if (($pi==7&&$ci==7) || ($pi==0&&$ci==0)) {
        for my $i (0 .. $#S_SCALE-1) {
            return $S_SCALE[$i+1] if $S_SCALE[$i] == $s;
        }
    }
    return $s;
}

# =============================================================
# FUNCIÓN DE COSTE — Alto con lookahead
# Parámetros:
#   $s      = soprano actual
#   $b      = bajo actual
#   $prev_a = alto anterior
#   $s_prev = soprano anterior (para paralelismo; undef en i=0)
#   $b_next = bajo siguiente  (lookahead; undef en último paso)
# =============================================================
sub generate_alto_look {
    my ($s, $b, $prev_a, $s_prev, $b_next) = @_;
    $prev_a //= 62;

    my ($best, $bscore) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;  # Alto estrictamente por debajo de Soprano

        my $motion = abs($c - $prev_a);
        my $score  = 0;

        # Suavidad (cap en 6 semitonos para no sobre-penalizar saltos grandes)
        $score += ($motion < 6 ? $motion : 6);

        # Penalización semitono cromático
        $score += 12 if $motion == 1;

        # Penalización tritono (Bb↔E en Re menor = 6 semitonos)
        $score += 5  if $motion == 6;

        # Consonancia actual con bajo
        $score += 15 unless is_consonant($c, $b);

        # Consonancia anticipada con bajo siguiente (lookahead)
        if (defined $b_next) {
            $score += 8 unless is_consonant($c, $b_next);
        }

        # Espacio mínimo con soprano (< 3 semitonos)
        $score += 5 if ($s - $c) < 3;

        # 5as/8as paralelas S–A
        $score += 20 if has_parallel($s_prev, $prev_a, $s, $c);

        # Preferir movimiento contrario a soprano
        if (defined $s_prev && $s != $s_prev && $motion > 0) {
            $score += 3 if (($s > $s_prev) == ($c > $prev_a));
        }

        # Pequeña penalización por nota repetida
        $score += 3 if $c == $prev_a;

        # Atracción suave al centro del registro
        $score += int(abs($c - $A_CENTER) / 4);

        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    return $best // $prev_a;
}

# =============================================================
# FUNCIÓN DE COSTE — Tenor con lookahead
# Parámetros adicionales:
#   $a      = alto actual
#   $b_prev = bajo anterior (para paralelismo B–T)
# =============================================================
sub generate_tenor_look {
    my ($s, $b, $a, $prev_t, $s_prev, $b_prev, $b_next) = @_;
    $prev_t //= 52;

    my ($best, $bscore) = (undef, 1e9);
    for my $c (@T_SCALE) {
        next if $c >= $a || $c <= $b;  # B < T < A

        my $motion = abs($c - $prev_t);
        my $score  = 0;

        $score += ($motion < 6 ? $motion : 6);
        $score += 12 if $motion == 1;
        $score += 5  if $motion == 6;

        $score += 15 unless is_consonant($c, $b);

        if (defined $b_next) {
            $score += 8 unless is_consonant($c, $b_next);
        }

        # 5as/8as paralelas S–T
        $score += 20 if has_parallel($s_prev, $prev_t, $s, $c);

        # 5as/8as paralelas B–T
        $score += 20 if has_parallel($b_prev, $prev_t, $b, $c);

        # Preferir movimiento contrario a soprano
        if (defined $s_prev && $s != $s_prev && $motion > 0) {
            $score += 3 if (($s > $s_prev) == ($c > $prev_t));
        }

        $score += 3 if $c == $prev_t;

        $score += int(abs($c - $T_CENTER) / 4);

        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }

    # Fallback si no hay posición válida (cruce de voces inevitable)
    unless (defined $best) {
        my $mid = int(($a + $b) / 2);
        $best = (sort { abs($a-$mid) <=> abs($b-$mid) } @T_SCALE)[0] // 52;
    }
    return $best;
}

# --- Carga de datos ---
sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>;
    while (<$fh>) {
        chomp; my @f = split(',', $_);
        $f[4] =~ /^([A-G]#?)(\d)$/ and $map{$f[0]} = 12*($2+1)+$note_idx{$1};
    }
    close $fh; return %map;
}

sub load_dat_tiempo {
    my ($dir) = @_;
    my %map;
    opendir(my $dh, $dir) or die $!;
    while (my $f = readdir($dh)) {
        next unless $f =~ /\.dat$/i;
        my $content = do { local $/; open(my $fh,'<:encoding(UTF-8)',"$dir/$f") or die $!; <$fh> };
        (my $key = $f) =~ s/\.(MG|mg)\.dat$//i;
        $content =~ /Tiempo de vida media: ([\d.]+)/ and $map{$key} = $1+0;
    }
    closedir $dh; return %map;
}

my %comp = (A=>'T',T=>'A',C=>'G',G=>'C');
sub rev_comp { join('', reverse map { $comp{$_} } split('',$_[0])) }
sub get_tiempo {
    my ($r,$t) = @_;
    return $r->{$t}           if exists $r->{$t};
    return $r->{rev_comp($t)} if exists $r->{rev_comp($t)};
    die "No encontrado: $t\n";
}

# --- Figuras (normalización logarítmica, igual que aprox6) ---
my @FIGURES = (
    {ticks=>240, name=>'corchea'},
    {ticks=>360, name=>'corchea con punto'},
    {ticks=>480, name=>'negra'},
    {ticks=>720, name=>'negra con punto'},
    {ticks=>960, name=>'blanca'},
);
sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }
sub ps_to_ticks_log {
    my ($ps, $min, $max) = @_;
    my $n       = scalar @FIGURES;
    my $idx = int((log($ps)-log($min))/(log($max)-log($min))*$n);
    $idx = 0     if $idx < 0;
    $idx = $n-1  if $idx >= $n;
    return $FIGURES[$idx];
}

# --- Cargar datos ---
my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg_midi    = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn_midi    = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mg_tiempo  = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %mn_tiempo  = load_dat_tiempo("$base/source/MUSIC.minorgroove");
my ($mg_min,$mg_max) = (list_min(values %mg_tiempo), list_max(values %mg_tiempo));
my ($mn_min,$mn_max) = (list_min(values %mn_tiempo), list_max(values %mn_tiempo));

my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for (my $i=0; $i+4<=length($seq); $i++) { push @tetras, substr($seq,$i,4); }

# --- R1–R3: Soprano y Bajo ---
my (@s_raw, @b_raw, @s_dur, @b_dur);
for my $t (@tetras) {
    push @s_raw, force_register(snap_to_d_minor($mg_midi{$t}), 69, 62, 86);
    push @s_dur, ps_to_ticks_log(get_tiempo(\%mg_tiempo,$t), $mg_min, $mg_max);
    push @b_raw, force_register(snap_to_d_minor($mn_midi{$t}), 50, 38, 62);
    push @b_dur, ps_to_ticks_log(get_tiempo(\%mn_tiempo,$t), $mn_min, $mn_max);
}
my @s_notes = apply_voice_leading(\@s_raw, 7, 62, 86);
my @b_notes = apply_voice_leading(\@b_raw, 7, 38, 62);

# --- R7: Anti-paralelismos S–B ---
for my $i (1..$#s_notes) {
    $s_notes[$i] = check_parallel_sb($s_notes[$i-1], $b_notes[$i-1], $s_notes[$i], $b_notes[$i]);
}

# --- R5–R6 (nuevo): Alto y Tenor con lookahead ---
my (@a_notes, @t_notes);
my ($prev_a, $prev_t) = (62, 52);
for my $i (0..$#tetras) {
    my $s      = $s_notes[$i];
    my $b      = $b_notes[$i];
    my $s_prev = $i > 0 ? $s_notes[$i-1] : undef;
    my $b_prev = $i > 0 ? $b_notes[$i-1] : undef;
    my $b_next = $i < $#tetras ? $b_notes[$i+1] : undef;

    my $a = generate_alto_look($s, $b, $prev_a, $s_prev, $b_next);
    my $t = generate_tenor_look($s, $b, $a, $prev_t, $s_prev, $b_prev, $b_next);

    push @a_notes, $a;
    push @t_notes, $t;
    ($prev_a, $prev_t) = ($a, $t);
}

# --- Construir pistas MIDI ---
my $ticks  = 480;
my $tempo  = 833333; # 72 BPM

sub build_track {
    my ($notes_ref, $durs_ref, $ch, $program, $name) = @_;
    my ($on, $off, $pc) = (0x90|$ch, 0x80|$ch, 0xC0|$ch);
    my $track = vlq(0)."\xFF\x03".chr(length($name)).$name;
    $track .= vlq(0).chr($pc).chr($program);
    for my $i (0..$#$notes_ref) {
        my ($m,$dur) = ($notes_ref->[$i], $durs_ref->[$i]{ticks});
        $track .= vlq(0).chr($on).chr($m).chr(85);
        $track .= vlq($dur).chr($off).chr($m).chr(0);
    }
    $track .= vlq(0)."\xFF\x2F\x00";
    return $track;
}

my $tempo_track = vlq(0)."\xFF\x03\x05Tempo"
    .vlq(0)."\xFF\x51\x03"
    .chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF)
    .vlq(0)."\xFF\x2F\x00";

my $t_sop = build_track(\@s_notes, \@s_dur, 0,  0, 'Soprano - Grand Piano');
my $t_alt = build_track(\@a_notes, \@s_dur, 1,  0, 'Alto - Grand Piano');
my $t_ten = build_track(\@t_notes, \@b_dur, 2,  0, 'Tenor - Grand Piano');
my $t_bas = build_track(\@b_notes, \@b_dur, 3, 43, 'Bajo - Contrabajo');

my $midi = "MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi .= midi_chunk("MTrk",$_) for ($tempo_track,$t_sop,$t_alt,$t_ten,$t_bas);

my $out = "$base/aprox7/prueba1/prueba1.mid";
open(my $fh_out,'>:raw',$out) or die $!;
print $fh_out $midi;
close $fh_out;

# --- Estadísticas ---
my @NOTE_NAMES = ('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn { $NOTE_NAMES[$_[0]%12].int($_[0]/12-1) }

# Disonancias
my ($dis_orig, $dis_corr) = (0, 0);
for my $i (0..$#s_notes) {
    my $int_orig = ($s_raw[$i]-$b_raw[$i]) % 12;
    my $int_corr = ($s_notes[$i]-$b_notes[$i]) % 12;
    $dis_orig++ unless grep{$_==$int_orig} @CONSONANT;
    $dis_corr++ unless grep{$_==$int_corr} @CONSONANT;
}

# Semitonos consecutivos en voces de corrección
my ($semi_a, $semi_t) = (0, 0);
for my $i (1..$#a_notes) {
    $semi_a++ if abs($a_notes[$i]-$a_notes[$i-1]) == 1;
    $semi_t++ if abs($t_notes[$i]-$t_notes[$i-1]) == 1;
}

# Disonancias A-B y T-B
my ($dis_ab, $dis_tb) = (0, 0);
for my $i (0..$#a_notes) {
    $dis_ab++ unless is_consonant($a_notes[$i], $b_notes[$i]);
    $dis_tb++ unless is_consonant($t_notes[$i], $b_notes[$i]);
}

print "Generado: $out\n";
print "Voces: 4 (SATB) | Tempo: 72 BPM | Tetranucleotidos: ".scalar(@tetras)."\n";
print "Instrumentos: S+A+T=GrandPiano(0), B=Contrabajo(43)\n\n";
printf "Disonancias S–B: %d originales → %d tras correcciones\n", $dis_orig, $dis_corr;
printf "Disonancias A–B: %d / %d  |  T–B: %d / %d\n\n",
    $dis_ab, scalar(@tetras), $dis_tb, scalar(@tetras);
printf "Semitonos consecutivos — Alto: %d  |  Tenor: %d\n\n", $semi_a, $semi_t;

print "Muestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-4s  A:%-4s  T:%-4s  B:%-4s\n",
    $tetras[$_], mn($s_notes[$_]), mn($a_notes[$_]), mn($t_notes[$_]), mn($b_notes[$_])
    for 0..7;
