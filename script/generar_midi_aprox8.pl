#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# aprox8/prueba1 — Conducción de voces inspirada en el CBI (Bach)
#
# CONTEXTO:
#   Se analizaron los 24 archivos MusicXML del Clave Bien Temperado
#   Libro I (BWV 846–869). Los hallazgos principales que informan
#   esta aproximación son:
#     - El 70 % de los intervalos melódicos en las fugas son M2 o m2.
#       Las voces internas de Bach se mueven casi siempre por grado
#       conjunto; los saltos son la excepción, no la norma.
#     - Los intervalos armónicos simultáneos más frecuentes son
#       terceras (m3/M3) y sextas (m6/M6). Las cuartas (P4) se
#       evitan entre voces internas; las quintas (P5) son toleradas.
#     - Resolución de salto: un salto de P4 o mayor va seguido casi
#       siempre de un movimiento en dirección contraria (paso).
#     - El movimiento contrario entre voces externas (S vs B) y entre
#       voz interna y la voz adyacente es una característica constante.
#
# FUNCIÓN DE COSTE (Alto):
#   wtcMelodicCost(Δ)   ×  1   — preferencia por grado conjunto
#   wtcHarmonicCost(c,b) ×  2   — 3ras/6tas; P4 penalizado
#   wtcHarmonicCost(c,bN)×  1   — anticipación paso +1
#   wtcHarmonicCost(c,bN2)× 0.5 — anticipación paso +2
#   leapResolutionCost  × 10   — penaliza dos saltos consecutivos
#                                 en la misma dirección
#   movimiento contrario S–A   — bonus –5 si van en dirs. opuestas
#   paralel. 5as/8as S–A       × 20
#   espacio mínimo S–A < 3st   × 4
#   atracción centro registro  × 0.1 por semitono
#
# FUNCIÓN DE COSTE (Tenor):
#   wtcMelodicCost(Δ)   ×  1
#   wtcHarmonicCost(c,b) × 1.5
#   wtcHarmonicCost(c,a) × 0.8
#   wtcHarmonicCost(c,bN)×  1
#   wtcHarmonicCost(c,bN2)× 0.5
#   leapResolutionCost  × 10
#   movimiento contrario T–B   — bonus –4 si van en dirs. opuestas
#   paralel. 5as/8as S–T + B–T × 20 cada una
#   atracción centro registro  × 0.1 por semitono
#
# REGLAS HEREDADAS (sin cambio vs aprox7):
#   R1. Snap S, B a la escala activa (Re menor natural)
#   R2. Forzar registro: S D4–D6, A G3–C5, T C3–G4, B D2–D4
#   R3. Voice leading S, B: salto > 7st → inversión por octava
#   R7. Par S–B: 5as/8as paralelas → mover soprano un grado arriba
#   R9. S+A comparten duración (major groove); T+B (minor groove)
#   Duración: normalización logarítmica (igual que aprox6/7)
#
# NOVEDADES vs aprox7:
#   - wtcMelodicCost: paso M2/m2 = coste 0; P4 = 9; P5+ = 15/24
#   - wtcHarmonicCost: m3/M3 = 0; m6/M6 = 1; P4 = 7 (disonante en
#     voces internas); P5 = 4; tritono = 20
#   - Resolución de salto: si |Δi-1| ≥ 5 y |Δi| ≥ 3 en misma
#     dirección → penalización +10
#   - Movimiento contrario S–A: bonus explícito –5
#   - Movimiento contrario T–B: bonus explícito –4
#   - Lookahead extendido a 2 pasos (bNext + bNext2)
#
# INSTRUMENTOS (igual que aprox6/7):
#   Soprano  (Ch 0)  Acoustic Grand Piano  GM  0
#   Alto     (Ch 1)  Acoustic Grand Piano  GM  0
#   Tenor    (Ch 2)  Acoustic Grand Piano  GM  0
#   Bajo     (Ch 3)  Contrabass            GM 43
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

sub d_minor_in_range {
    my ($lo, $hi) = @_;
    my @notes;
    for my $oct (0..9) { push @notes, $oct*12+$_ for @D_MINOR_CHROMA; }
    return sort { $a <=> $b } grep { $_ >= $lo && $_ <= $hi } @notes;
}

my @S_SCALE = d_minor_in_range(62, 86);
my @A_SCALE = d_minor_in_range(55, 72);
my @T_SCALE = d_minor_in_range(48, 67);

my $A_CENTER = 62;
my $T_CENTER = 57;

sub has_parallel {
    my ($v1p, $v2p, $v1c, $v2c) = @_;
    return 0 unless defined $v1p && defined $v2p;
    my $pi = ($v1p - $v2p) % 12;
    my $ci = ($v1c - $v2c) % 12;
    return (($pi==7 && $ci==7) || ($pi==0 && $ci==0)) ? 1 : 0;
}

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
# FUNCIONES DE COSTE WTC/Bach
# =============================================================

# Coste melódico — preferencia fuerte por movimiento por grado
# conjunto (M2/m2 = 0), intervalos mayores progresivamente costosos.
sub wtc_melodic_cost {
    my ($prev, $curr) = @_;
    my $step = abs($curr - $prev);
    return  0 if $step <= 2;   # M2 / m2 — norma del CBI (~70 %)
    return  4 if $step <= 4;   # m3 / M3 — salto tolerable
    return  9 if $step <= 5;   # P4      — moderado
    return 15 if $step <= 7;   # P5      — salto grande
    return 24;                 # M6+     — evitar
}

# Coste armónico — terceras y sextas primero (análisis CBI).
# P4 se penaliza como disonancia entre voces internas.
sub wtc_harmonic_cost {
    my ($a, $b) = @_;
    my $i = abs($a - $b) % 12;
    return  0 if $i == 3 || $i == 4;    # m3 / M3 — primera elección
    return  1 if $i == 8 || $i == 9;    # m6 / M6 — segunda elección
    return  4 if $i == 7;               # P5
    return  5 if $i == 0;               # P8 / unison
    return  7 if $i == 5;               # P4 — disonante entre voces int.
    return 11 if $i == 2 || $i == 10;   # M2 / m7
    return 16 if $i == 1 || $i == 11;   # m2 / M7
    return 20 if $i == 6;               # tritono
    return  6;
}

# Resolución de salto — dos saltos consecutivos en la misma dirección.
sub leap_resolution_cost {
    my ($pp, $p, $c) = @_;
    return 0 unless defined $pp;
    my $l1 = $p - $pp;
    my $l2 = $c - $p;
    if (abs($l1) >= 5 && abs($l2) >= 3) {
        my $s1 = $l1 > 0 ? 1 : ($l1 < 0 ? -1 : 0);
        my $s2 = $l2 > 0 ? 1 : ($l2 < 0 ? -1 : 0);
        return 10 if $s1 == $s2 && $s1 != 0;
    }
    return 0;
}

# =============================================================
# GENERACIÓN DE ALTO — lookahead 2 pasos
# =============================================================
sub generate_alto_wtc {
    my ($s, $b, $prev_a, $pp_a, $s_prev, $b_next, $b_next2) = @_;
    $prev_a //= 62;

    my ($best, $bscore) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;

        my $score = 0;

        # Coste melódico WTC
        $score += wtc_melodic_cost($prev_a, $c);

        # Coste armónico con bajo (peso 2)
        $score += 2 * wtc_harmonic_cost($c, $b);

        # Anticipación +1
        if (defined $b_next) {
            $score += wtc_harmonic_cost($c, $b_next);
        }

        # Anticipación +2
        if (defined $b_next2) {
            $score += 0.5 * wtc_harmonic_cost($c, $b_next2);
        }

        # Resolución de salto
        $score += leap_resolution_cost($pp_a, $prev_a, $c);

        # Movimiento contrario con soprano — bonus si van en dirs. opuestas
        if (defined $s_prev) {
            my $s_dir = ($s > $s_prev) ? 1 : ($s < $s_prev) ? -1 : 0;
            my $a_dir = ($c > $prev_a) ? 1 : ($c < $prev_a) ? -1 : 0;
            if ($s_dir != 0 && $a_dir != 0 && $s_dir != $a_dir) {
                $score -= 5;  # bonus movimiento contrario
            }
        }

        # 5as/8as paralelas S–A
        $score += 20 if has_parallel($s_prev, $prev_a, $s, $c);

        # Espacio mínimo entre S y A
        $score += 4 if ($s - $c) < 3;

        # Atracción suave al centro del registro
        $score += 0.1 * abs($c - $A_CENTER);

        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    return $best // $prev_a;
}

# =============================================================
# GENERACIÓN DE TENOR — lookahead 2 pasos
# =============================================================
sub generate_tenor_wtc {
    my ($s, $b, $a, $prev_t, $pp_t, $s_prev, $b_prev, $b_next, $b_next2) = @_;
    $prev_t //= 52;

    my ($best, $bscore) = (undef, 1e9);
    for my $c (@T_SCALE) {
        next if $c >= $a || $c <= $b;

        my $score = 0;

        $score += wtc_melodic_cost($prev_t, $c);

        # Coste armónico con bajo (peso 1.5) y alto (peso 0.8)
        $score += 1.5 * wtc_harmonic_cost($c, $b);
        $score += 0.8 * wtc_harmonic_cost($c, $a);

        if (defined $b_next)  { $score += wtc_harmonic_cost($c, $b_next); }
        if (defined $b_next2) { $score += 0.5 * wtc_harmonic_cost($c, $b_next2); }

        $score += leap_resolution_cost($pp_t, $prev_t, $c);

        # Movimiento contrario T–B — bonus
        if (defined $b_prev) {
            my $b_dir = ($b > $b_prev) ? 1 : ($b < $b_prev) ? -1 : 0;
            my $t_dir = ($c > $prev_t) ? 1 : ($c < $prev_t) ? -1 : 0;
            if ($b_dir != 0 && $t_dir != 0 && $b_dir != $t_dir) {
                $score -= 4;
            }
        }

        $score += 20 if has_parallel($s_prev, $prev_t, $s, $c);
        $score += 20 if has_parallel($b_prev, $prev_t, $b, $c);

        $score += 0.1 * abs($c - $T_CENTER);

        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }

    unless (defined $best) {
        my $mid = int(($a + $b) / 2);
        ($best) = sort { abs($a-$mid) <=> abs($b-$mid) }
                  grep { $_ > $b && $_ < $a } @T_SCALE;
        $best //= 52;
    }
    return $best;
}

# =============================================================
# CARGA DE DATOS
# =============================================================
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

# --- Normalización logarítmica (igual que aprox6/7) ---
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
    my $n   = scalar @FIGURES;
    my $idx = int((log($ps)-log($min))/(log($max)-log($min))*$n);
    $idx = 0    if $idx < 0;
    $idx = $n-1 if $idx >= $n;
    return $FIGURES[$idx];
}

# =============================================================
# PIPELINE PRINCIPAL
# =============================================================
my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg_midi   = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn_midi   = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mg_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %mn_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");
my ($mg_min,$mg_max) = (list_min(values %mg_tiempo), list_max(values %mg_tiempo));
my ($mn_min,$mn_max) = (list_min(values %mn_tiempo), list_max(values %mn_tiempo));

my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for (my $i=0; $i+4<=length($seq); $i++) { push @tetras, substr($seq,$i,4); }

# R1–R3: Soprano y Bajo
my (@s_raw, @b_raw, @s_dur, @b_dur);
for my $t (@tetras) {
    push @s_raw, force_register(snap_to_d_minor($mg_midi{$t}), 69, 62, 86);
    push @s_dur, ps_to_ticks_log(get_tiempo(\%mg_tiempo,$t), $mg_min, $mg_max);
    push @b_raw, force_register(snap_to_d_minor($mn_midi{$t}), 50, 38, 62);
    push @b_dur, ps_to_ticks_log(get_tiempo(\%mn_tiempo,$t), $mn_min, $mn_max);
}
my @s_notes = apply_voice_leading(\@s_raw, 7, 62, 86);
my @b_notes = apply_voice_leading(\@b_raw, 7, 38, 62);

# R7: Anti-paralelismos S–B
for my $i (1..$#s_notes) {
    $s_notes[$i] = check_parallel_sb($s_notes[$i-1], $b_notes[$i-1],
                                     $s_notes[$i],   $b_notes[$i]);
}

# Alto y Tenor con coste WTC, lookahead 2 pasos
my (@a_notes, @t_notes);
my ($prev_a, $prev_t)   = (62, 52);
my ($pp_a,   $pp_t)     = (undef, undef);

for my $i (0..$#tetras) {
    my $s      = $s_notes[$i];
    my $b      = $b_notes[$i];
    my $s_prev = $i > 0            ? $s_notes[$i-1] : undef;
    my $b_prev = $i > 0            ? $b_notes[$i-1] : undef;
    my $b_next = $i < $#tetras     ? $b_notes[$i+1] : undef;
    my $b_nxt2 = $i < $#tetras - 1 ? $b_notes[$i+2] : undef;

    my $a = generate_alto_wtc($s, $b, $prev_a, $pp_a, $s_prev, $b_next, $b_nxt2);
    my $t = generate_tenor_wtc($s, $b, $a, $prev_t, $pp_t, $s_prev, $b_prev, $b_next, $b_nxt2);

    push @a_notes, $a;
    push @t_notes, $t;
    ($pp_a,   $pp_t)   = ($prev_a, $prev_t);
    ($prev_a, $prev_t) = ($a,      $t);
}

# =============================================================
# CONSTRUCCIÓN DEL MIDI
# =============================================================
my $ticks = 480;
my $tempo = 833333; # 72 BPM

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

my $out = "$base/aprox8/prueba1/prueba1.mid";
open(my $fh_out,'>:raw',$out) or die $!;
print $fh_out $midi;
close $fh_out;

# =============================================================
# ESTADÍSTICAS
# =============================================================
my @NOTE_NAMES = ('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn { $NOTE_NAMES[$_[0]%12].int($_[0]/12-1) }

my @CONSONANT = (0, 3, 4, 7, 8, 9);
sub is_consonant { my $i=($_[0]-$_[1])%12; scalar grep{$_==$i}@CONSONANT }

# Intervalos melódicos en voces de corrección (verificar preferencia por grado)
my (%mel_a, %mel_t);
for my $i (1..$#a_notes) {
    my $da = abs($a_notes[$i]-$a_notes[$i-1]);
    my $dt = abs($t_notes[$i]-$t_notes[$i-1]);
    $mel_a{$da}++; $mel_t{$dt}++;
}
my ($step_a, $total_a) = (0, 0);
my ($step_t, $total_t) = (0, 0);
for my $d (keys %mel_a) { $total_a += $mel_a{$d}; $step_a += $mel_a{$d} if $d <= 2; }
for my $d (keys %mel_t) { $total_t += $mel_t{$d}; $step_t += $mel_t{$d} if $d <= 2; }

# Intervalos armónicos A–B: contar 3ras/6tas vs resto
my ($thirds_ab, $total_ab) = (0, 0);
for my $i (0..$#a_notes) {
    my $iv = abs($a_notes[$i]-$b_notes[$i]) % 12;
    $total_ab++;
    $thirds_ab++ if $iv==3||$iv==4||$iv==8||$iv==9;
}

# Disonancias
my ($dis_ab, $dis_tb) = (0, 0);
for my $i (0..$#a_notes) {
    $dis_ab++ unless is_consonant($a_notes[$i], $b_notes[$i]);
    $dis_tb++ unless is_consonant($t_notes[$i], $b_notes[$i]);
}

# Resoluciones de salto: contar saltos P4+ seguidos de paso contrario
my ($leaps_resolved, $leaps_total) = (0, 0);
for my $i (2..$#a_notes) {
    my $l1 = $a_notes[$i-1] - $a_notes[$i-2];
    my $l2 = $a_notes[$i]   - $a_notes[$i-1];
    if (abs($l1) >= 5) {
        $leaps_total++;
        my $s1 = $l1>0?1:($l1<0?-1:0);
        my $s2 = $l2>0?1:($l2<0?-1:0);
        $leaps_resolved++ if $s1 != $s2 && $s1 != 0;
    }
}

print "Generado: $out\n";
print "Voces: 4 (SATB) | Tempo: 72 BPM | Tetranucleotidos: ".scalar(@tetras)."\n";
print "Algoritmo: Bach/CBI-informed (wtcMelodicCost + wtcHarmonicCost + lookahead×2)\n\n";

printf "Movimiento por grado conjunto (M2/m2) — Alto:  %d / %d  (%.1f %%)\n",
    $step_a, $total_a, $total_a ? 100*$step_a/$total_a : 0;
printf "Movimiento por grado conjunto (M2/m2) — Tenor: %d / %d  (%.1f %%)\n\n",
    $step_t, $total_t, $total_t ? 100*$step_t/$total_t : 0;

printf "Intervalos armónicos 3ras/6tas en A–B: %d / %d  (%.1f %%)\n\n",
    $thirds_ab, $total_ab, $total_ab ? 100*$thirds_ab/$total_ab : 0;

printf "Resolución de saltos (Alto): %d / %d  (%.1f %% resueltos al contrario)\n\n",
    $leaps_resolved, $leaps_total, $leaps_total ? 100*$leaps_resolved/$leaps_total : 0;

printf "Disonancias A–B: %d / %d  |  T–B: %d / %d\n\n",
    $dis_ab, scalar(@tetras), $dis_tb, scalar(@tetras);

print "Muestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-4s  A:%-4s  T:%-4s  B:%-4s\n",
    $tetras[$_], mn($s_notes[$_]), mn($a_notes[$_]), mn($t_notes[$_]), mn($b_notes[$_])
    for 0..7;
