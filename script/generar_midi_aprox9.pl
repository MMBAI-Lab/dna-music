#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# =================================================================
# aprox9/prueba1 — Normalización rítmica del CBI + Conducción Bach
#
# CONTEXTO:
#   Análisis de 43 233 notas de los 24 archivos MusicXML del CBI I
#   (BWV 846–869). Hallazgos de transición rítmica:
#     - 72.5 % de transiciones son 1:1 (misma figura)
#     - 10.3 % son 2:1 (siguiente = mitad)
#     -  9.6 % son 1:2 (siguiente = doble)
#     -  0.0 % son 1:3 o 3:1 (saltos extremos no existen en el CBI)
#     - Runs promedio: 3.64 notas; picos en 4, 6, 8, 12, 16.
#
# ALGORITMO applyWTCRhythm (post-procesado de duraciones):
#   1. Snap a figura — normalización logarítmica a paleta de 5 figuras.
#   2. Homogeneización de runs — para pares de figuras contiguas
#      (índice de paleta diferente en 1), elevar ambas a la mayor.
#      → Aumenta la tasa de transiciones 1:1 hacia el 72.5 % del CBI.
#   3. Tope 2:1 — eliminar transiciones > 2:1 (0 % en el CBI).
#
# CONDUCCIÓN DE VOCES (hereda aprox8):
#   wtcMelodicCost: M2/m2 = 0; P4 = 9; P5+ = 15/24
#   wtcHarmonicCost: m3/M3 = 0; m6/M6 = 1; P4 = 7; P5 = 4; TT = 20
#   Resolución de salto (leapResolutionCost)
#   Movimiento contrario S–A (bonus –5), T–B (bonus –4)
#   Lookahead: 2 pasos (bNext + bNext2)
#
# REGLAS HEREDADAS:
#   R1. Snap S, B a Re menor natural
#   R2. Registros: S D4–D6, A G3–C5, T C3–G4, B D2–D4
#   R3. Voice leading S, B: salto > 7st → inversión por octava
#   R7. Paralelismos S–B → mover soprano un grado arriba
#   R9. S+A comparten duración (major); T+B (minor)
#
# INSTRUMENTOS:
#   Soprano (Ch 0) / Alto (Ch 1) / Tenor (Ch 2) : Grand Piano (GM 0)
#   Bajo (Ch 3) : Contrabass (GM 43)
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
my @D_MINOR_CHROMA = (0, 2, 4, 5, 7, 9, 10);

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
# FUNCIONES DE COSTE WTC/Bach (heredadas de aprox8)
# =============================================================

sub wtc_melodic_cost {
    my ($prev, $curr) = @_;
    my $step = abs($curr - $prev);
    return  0 if $step <= 2;
    return  4 if $step <= 4;
    return  9 if $step <= 5;
    return 15 if $step <= 7;
    return 24;
}

sub wtc_harmonic_cost {
    my ($a, $b) = @_;
    my $i = abs($a - $b) % 12;
    return  0 if $i == 3 || $i == 4;
    return  1 if $i == 8 || $i == 9;
    return  4 if $i == 7;
    return  5 if $i == 0;
    return  7 if $i == 5;
    return 11 if $i == 2 || $i == 10;
    return 16 if $i == 1 || $i == 11;
    return 20 if $i == 6;
    return  6;
}

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

sub generate_alto_wtc {
    my ($s, $b, $prev_a, $pp_a, $s_prev, $b_next, $b_next2) = @_;
    $prev_a //= 62;
    my ($best, $bscore) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;
        my $score = 0;
        $score += wtc_melodic_cost($prev_a, $c);
        $score += 2 * wtc_harmonic_cost($c, $b);
        $score += wtc_harmonic_cost($c, $b_next)          if defined $b_next;
        $score += 0.5 * wtc_harmonic_cost($c, $b_next2)   if defined $b_next2;
        $score += leap_resolution_cost($pp_a, $prev_a, $c);
        if (defined $s_prev) {
            my $s_dir = ($s > $s_prev) ? 1 : ($s < $s_prev) ? -1 : 0;
            my $a_dir = ($c > $prev_a) ? 1 : ($c < $prev_a) ? -1 : 0;
            $score -= 5 if $s_dir != 0 && $a_dir != 0 && $s_dir != $a_dir;
        }
        $score += 20 if has_parallel($s_prev, $prev_a, $s, $c);
        $score += 4  if ($s - $c) < 3;
        $score += 0.1 * abs($c - $A_CENTER);
        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    return $best // $prev_a;
}

sub generate_tenor_wtc {
    my ($s, $b, $a, $prev_t, $pp_t, $s_prev, $b_prev, $b_next, $b_next2) = @_;
    $prev_t //= 52;
    my ($best, $bscore) = (undef, 1e9);
    for my $c (@T_SCALE) {
        next if $c >= $a || $c <= $b;
        my $score = 0;
        $score += wtc_melodic_cost($prev_t, $c);
        $score += 1.5 * wtc_harmonic_cost($c, $b);
        $score += 0.8 * wtc_harmonic_cost($c, $a);
        $score += wtc_harmonic_cost($c, $b_next)          if defined $b_next;
        $score += 0.5 * wtc_harmonic_cost($c, $b_next2)   if defined $b_next2;
        $score += leap_resolution_cost($pp_t, $prev_t, $c);
        if (defined $b_prev) {
            my $b_dir = ($b > $b_prev) ? 1 : ($b < $b_prev) ? -1 : 0;
            my $t_dir = ($c > $prev_t) ? 1 : ($c < $prev_t) ? -1 : 0;
            $score -= 4 if $b_dir != 0 && $t_dir != 0 && $b_dir != $t_dir;
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
# NORMALIZACIÓN RÍTMICA WTC (aprox9)
# =============================================================
#
# Paleta de 5 figuras (ticks):
#   0: corchea          (240)
#   1: corchea con punto(360)
#   2: negra            (480)
#   3: negra con punto  (720)
#   4: blanca           (960)
#
# Algoritmo:
#   1. Snap cada duración a la figura más cercana (distancia mínima en ticks).
#   2. Homogeneización de runs: para cada par consecutivo cuyo índice de paleta
#      difiere en 1 (ratio ≤ 1.5), elevar ambas a la figura mayor.
#      → Aumenta la tasa de transiciones 1:1 hacia el 72.5 % del CBI.
#   3. Tope 2:1: tras la homogeneización, eliminar transiciones > 2:1
#      recortando a la figura válida más cercana dentro de ese límite.

my @WTC_FIGS = (240, 360, 480, 720, 960);

sub snap_to_fig {
    my ($ticks) = @_;
    my ($best, $bd) = ($WTC_FIGS[0], 1e9);
    for my $f (@WTC_FIGS) {
        my $d = abs($f - $ticks);
        if ($d < $bd) { $bd = $d; $best = $f; }
    }
    return $best;
}

sub fig_idx { my ($f) = @_; for my $i (0..$#WTC_FIGS) { return $i if $WTC_FIGS[$i]==$f; } return -1; }

sub apply_wtc_rhythm {
    my (@durs) = @_;
    return () unless @durs;

    # Step 1 — snap to figure
    my @s = map { snap_to_fig($_) } @durs;

    # Step 2 — run homogenisation (adjacent figure indices → raise to longer)
    for my $i (0 .. $#s - 1) {
        my $ai = fig_idx($s[$i]);
        my $bi = fig_idx($s[$i+1]);
        if (abs($ai - $bi) == 1) {
            my $longer = $s[$i] > $s[$i+1] ? $s[$i] : $s[$i+1];
            $s[$i+1] = $longer;
        }
    }

    # Step 3 — boundary cap: no transition > 2:1 or < 1:2
    my @result = ($s[0]);
    for my $i (1 .. $#s) {
        my $prev = $result[-1];
        my $curr = $s[$i];
        if ($curr > $prev * 2) {
            # Too large: highest figure ≤ prev×2
            my $best = $prev;
            for my $f (@WTC_FIGS) { $best = $f if $f <= $prev * 2; }
            push @result, $best;
        } elsif ($curr * 2 < $prev) {
            # Too small: lowest figure ≥ prev/2
            my $best = $prev;
            for my $f (@WTC_FIGS) { $best = $f; last if $f >= $prev / 2; }
            push @result, $best;
        } else {
            push @result, $curr;
        }
    }
    return @result;
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

sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }

sub ps_to_ticks_log {
    my ($ps, $min, $max) = @_;
    my $n   = scalar @WTC_FIGS;
    my $idx = floor((log($ps)-log($min))/(log($max)-log($min))*$n);
    $idx = 0    if $idx < 0;
    $idx = $n-1 if $idx >= $n;
    return { ticks => $WTC_FIGS[$idx] };
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

# R1–R3: Soprano y Bajo — notas y duraciones brutas
my (@s_raw, @b_raw, @s_dur_raw, @b_dur_raw);
for my $t (@tetras) {
    push @s_raw,     force_register(snap_to_d_minor($mg_midi{$t}), 69, 62, 86);
    push @s_dur_raw, ps_to_ticks_log(get_tiempo(\%mg_tiempo,$t), $mg_min, $mg_max)->{ticks};
    push @b_raw,     force_register(snap_to_d_minor($mn_midi{$t}), 50, 38, 62);
    push @b_dur_raw, ps_to_ticks_log(get_tiempo(\%mn_tiempo,$t), $mn_min, $mn_max)->{ticks};
}

# Aplicar normalización rítmica WTC (aprox9)
my @s_dur_ticks = apply_wtc_rhythm(@s_dur_raw);
my @b_dur_ticks = apply_wtc_rhythm(@b_dur_raw);

# Convertir a estructuras compatibles con build_track
my @s_dur = map { {ticks=>$_} } @s_dur_ticks;
my @b_dur = map { {ticks=>$_} } @b_dur_ticks;

my @s_notes = apply_voice_leading(\@s_raw, 7, 62, 86);
my @b_notes = apply_voice_leading(\@b_raw, 7, 38, 62);

# R7: Anti-paralelismos S–B
for my $i (1..$#s_notes) {
    $s_notes[$i] = check_parallel_sb($s_notes[$i-1], $b_notes[$i-1],
                                     $s_notes[$i],   $b_notes[$i]);
}

# Alto y Tenor — conducción de voces WTC (aprox8)
my (@a_notes, @t_notes);
my ($prev_a, $prev_t) = (62, 52);
my ($pp_a,   $pp_t)   = (undef, undef);

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

my $out = "$base/aprox9/prueba1/prueba1.mid";
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

# Tasa de transiciones 1:1 en S (tras WTC rhythm)
my ($same_s, $same_b) = (0, 0);
for my $i (1..$#s_dur_ticks) {
    $same_s++ if $s_dur_ticks[$i] == $s_dur_ticks[$i-1];
    $same_b++ if $b_dur_ticks[$i] == $b_dur_ticks[$i-1];
}
my $n = scalar @tetras;

# Intervalos melódicos Alto
my ($step_a, $total_a) = (0, 0);
for my $i (1..$#a_notes) {
    my $d = abs($a_notes[$i]-$a_notes[$i-1]);
    $total_a++; $step_a++ if $d <= 2;
}

# Intervalos armónicos 3ras/6tas A–B
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

# Distribución de figuras tras WTC rhythm
my %fig_names = (240=>'corchea', 360=>'corchea con punto',
                 480=>'negra', 720=>'negra con punto', 960=>'blanca');
my (%dist_s, %dist_b);
$dist_s{$_}++ for @s_dur_ticks;
$dist_b{$_}++ for @b_dur_ticks;

print "Generado: $out\n";
print "Voces: 4 (SATB) | Tempo: 72 BPM | Tetranucleotidos: $n\n";
print "Algoritmo: WTC rhythm + WTC voice leading (Bach/CBI, completo)\n\n";

printf "Transiciones 1:1 (misma figura) — S: %d / %d  (%.1f %%)  B: %d / %d  (%.1f %%)\n",
    $same_s, $n-1, ($n>1?100*$same_s/($n-1):0),
    $same_b, $n-1, ($n>1?100*$same_b/($n-1):0);
print "(CBI: 72.5 %)\n\n";

printf "Movimiento por grado conjunto Alto (M2/m2): %d / %d  (%.1f %%)\n",
    $step_a, $total_a, ($total_a?100*$step_a/$total_a:0);
print "(CBI fugas: ~70 %)\n\n";

printf "Intervalos 3ras/6tas en A–B: %d / %d  (%.1f %%)\n\n",
    $thirds_ab, $total_ab, ($total_ab?100*$thirds_ab/$total_ab:0);

printf "Disonancias A–B: %d / %d  |  T–B: %d / %d\n\n",
    $dis_ab, $n, $dis_tb, $n;

print "Distribución de figuras (Soprano, tras WTC rhythm):\n";
for my $f (sort { $a <=> $b } keys %dist_s) {
    printf "  %-22s %d\n", $fig_names{$f}, $dist_s{$f};
}
print "\nDistribución de figuras (Bajo, tras WTC rhythm):\n";
for my $f (sort { $a <=> $b } keys %dist_b) {
    printf "  %-22s %d\n", $fig_names{$f}, $dist_b{$f};
}

print "\nMuestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-4s  A:%-4s  T:%-4s  B:%-4s  S-ticks:%d\n",
    $tetras[$_], mn($s_notes[$_]), mn($a_notes[$_]),
    mn($t_notes[$_]), mn($b_notes[$_]), $s_dur_ticks[$_]
    for 0..7;
