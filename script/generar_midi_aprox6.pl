#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# aprox6/prueba1 — 4 voces SATB, normalización LOGARÍTMICA de duraciones
#
# Igual que aprox5/prueba2 en todo excepto el mapeo de duración:
#   Lineal (aprox4/5): idx = (ps - min) / (max - min) * n
#   Logarítmica (aprox6): idx = (log(ps) - log(min)) / (log(max) - log(min)) * n
#
# La escala logarítmica comprime los valores altos y expande los bajos,
# reduciendo la concentración en corcheas/corcheas con punto y
# distribuyendo mejor hacia negras, negras con punto y blancas.
#
# Distribución esperada (sobre los 140 tetranucleótidos canónicos):
#   Major: corchea 10, corchea c/pto 38, negra 51, negra c/pto 29, blanca 12
#   Minor: corchea  5, corchea c/pto 49, negra 61, negra c/pto 18, blanca  7
#
# ESTRUCTURA DE VOCES (idéntica a aprox5/prueba2):
#
# ESTRUCTURA DE VOCES:
#   Ch 0  Soprano  Major groove  D4–D6 [MIDI 62–86]  [datos, rojo]
#   Ch 1  Alto     Generada      G3–C5 [MIDI 55–72]  [corrección, negro]
#   Ch 2  Tenor    Generado      C3–G4 [MIDI 48–67]  [corrección, negro]
#   Ch 3  Bajo     Minor groove  D2–D4 [MIDI 38–62]  [datos, azul]
#
# REGLAS PARA SOPRANO Y BAJO (heredadas de prueba1):
#   R1. Snap al grado más cercano de Re menor natural {D,E,F,G,A,Bb,C}
#   R2. Forzar al registro de la voz (octava más cercana al centro)
#   R3. Voice leading: salto > 7 semitonos → inversión por octava
#
# REGLAS PARA NOTAS DE CORRECCIÓN (Alto y Tenor):
#   R4. Solo se usan grados de Re menor natural (misma escala que S y B)
#   R5. Alto [G3–C5]: debe estar estrictamente por debajo de Soprano
#       Puntuación = movimiento_desde_anterior
#                  + 15 si disonante con Bajo (evitar: 2ª, 7ª, tritono)
#                  + 5  si < 3 semitonos de Soprano (evitar proximidad)
#       Intervalos consonantes aceptados: P1, m3, M3, P5, m6, M6
#   R6. Tenor [C3–G4]: debe estar por debajo de Alto y por encima de Bajo
#       Puntuación = movimiento_desde_anterior
#                  + 15 si disonante con Bajo
#       Fallback: si no hay posición válida, tomar la mediana entre B y A
#
# REGLAS ANTI-PARALELISMOS:
#   R7. Par Soprano–Bajo: si dos notas consecutivas forman 5as paralelas
#       (intervalo = 7st en ambos pasos) u 8as paralelas (0st), mover
#       Soprano un grado arriba en la escala de Re menor
#   R8. Par Soprano–Alto: misma lógica, mover Alto un grado abajo
#
# DURACIONES:
#   R9. Soprano y Alto comparten duración (tiempo de vida media del major groove)
#       Tenor y Bajo comparten duración (tiempo de vida media del minor groove)
#       → Dos "dúos" rítmicamente independientes: (S+A) vs (T+B)
#
# TEMPO: 72 BPM (igual que prueba1)
# =================================================================

my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub note_to_midi {
    my ($name) = @_;
    $name =~ /^([A-G]#?)(\d)$/ or die "Nota desconocida: $name\n";
    return 12 * ($2 + 1) + $note_idx{$1};
}

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
my @D_MINOR_CHROMA = (0, 2, 4, 5, 7, 9, 10); # C D E F G A Bb

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

# --- Rangos por voz (solo grados de Re menor) ---
sub d_minor_in_range {
    my ($lo, $hi) = @_;
    my @notes;
    for my $oct (0..9) {
        push @notes, $oct*12+$_ for @D_MINOR_CHROMA;
    }
    return sort { $a <=> $b } grep { $_ >= $lo && $_ <= $hi } @notes;
}

my @S_SCALE = d_minor_in_range(62, 86); # Soprano D4–D6
my @A_SCALE = d_minor_in_range(55, 72); # Alto    G3–C5
my @T_SCALE = d_minor_in_range(48, 67); # Tenor   C3–G4

my @CONSONANT = (0, 3, 4, 7, 8, 9);    # P1 m3 M3 P5 m6 M6
sub is_consonant { my $i=($_[0]-$_[1])%12; scalar grep{$_==$i}@CONSONANT }

# R5: Generar Alto
sub generate_alto {
    my ($s, $b, $prev_a) = @_;
    $prev_a //= 62;
    my ($best, $bscore) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;
        my $score = abs($c - $prev_a)
                  + (is_consonant($c, $b) ? 0 : 15)
                  + ($s - $c < 3 ? 5 : 0);
        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    return $best // 62;
}

# R6: Generar Tenor
sub generate_tenor {
    my ($s, $b, $a, $prev_t) = @_;
    $prev_t //= 52;
    my ($best, $bscore) = (undef, 1e9);
    for my $c (@T_SCALE) {
        next if $c >= $a || $c <= $b;
        my $score = abs($c - $prev_t)
                  + (is_consonant($c, $b) ? 0 : 15);
        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    # Fallback si no hay posición válida (cruce de voces inevitable)
    unless (defined $best) {
        my $mid = int(($a + $b) / 2);
        $best = (sort { abs($a-$mid) <=> abs($b-$mid) } @T_SCALE)[0] // 52;
    }
    return $best;
}

# R7: Verificar 5as/8as paralelas Soprano–Bajo
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

# R8: Verificar 5as/8as paralelas Soprano–Alto
sub check_parallel_sa {
    my ($ps, $pa, $s, $a) = @_;
    return $a unless defined $ps;
    my ($pi, $ci) = (($ps-$pa)%12, ($s-$a)%12);
    if (($pi==7&&$ci==7) || ($pi==0&&$ci==0)) {
        for my $i (1 .. $#A_SCALE) {
            return $A_SCALE[$i-1] if $A_SCALE[$i]==$a && $A_SCALE[$i-1] < $s;
        }
    }
    return $a;
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

# --- Figuras (normalización LOGARÍTMICA) ---
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
    my $log_ps  = log($ps);
    my $log_min = log($min);
    my $log_max = log($max);
    my $idx = int(($log_ps - $log_min) / ($log_max - $log_min) * $n);
    $idx = 0     if $idx < 0;
    $idx = $n-1  if $idx >= $n;
    return $FIGURES[$idx];
}

# --- Cargar todo ---
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

# --- Procesar Soprano y Bajo (R1-R3) ---
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

# --- R5–R6: Generar Alto y Tenor ---
my (@a_notes, @t_notes);
my ($prev_a, $prev_t) = (62, 52);
for my $i (0..$#tetras) {
    my ($s, $b) = ($s_notes[$i], $b_notes[$i]);
    my $a = generate_alto($s, $b, $prev_a);
    # R8: Anti-paralelismos S–A
    $a = check_parallel_sa($i>0?$s_notes[$i-1]:undef, $i>0?$a_notes[-1]:undef, $s, $a);
    my $t = generate_tenor($s, $b, $a, $prev_t);
    push @a_notes, $a;
    push @t_notes, $t;
    ($prev_a, $prev_t) = ($a, $t);
}

# --- Construir pistas MIDI ---
my $ticks = 480;
my $tempo  = 833333; # 72 BPM

sub build_track_simple {
    my ($notes_ref, $durs_ref, $ch, $name) = @_;
    my $on  = 0x90|$ch; my $off = 0x80|$ch;
    # Track name metadata
    my $track = vlq(0)."\xFF\x03".chr(length($name)).$name;
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

my $t_sop = build_track_simple(\@s_notes, \@s_dur, 0, 'Soprano (major groove)');
my $t_alt = build_track_simple(\@a_notes, \@s_dur, 1, 'Alto (correccion)');
my $t_ten = build_track_simple(\@t_notes, \@b_dur, 2, 'Tenor (correccion)');
my $t_bas = build_track_simple(\@b_notes, \@b_dur, 3, 'Bajo (minor groove)');

my $midi = "MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi .= midi_chunk("MTrk",$_) for ($tempo_track,$t_sop,$t_alt,$t_ten,$t_bas);

my $out = "$base/aprox6/prueba1/prueba1.mid";
open(my $fh_out,'>:raw',$out) or die $!;
print $fh_out $midi;
close $fh_out;

# --- Estadísticas ---
my @NOTE_NAMES = ('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn { $NOTE_NAMES[$_[0]%12].int($_[0]/12-1) }

print "Generado: $out\n";
print "Voces: 4 (SATB) | Tempo: 72 BPM | Tetranucleotidos: ".scalar(@tetras)."\n\n";

# Disonancia soprano-bajo antes/después de corrección
my ($dis_orig, $dis_corr) = (0, 0);
for my $i (0..$#s_notes) {
    my $int_orig = ($s_raw[$i]-$b_raw[$i]) % 12;
    my $int_corr = ($s_notes[$i]-$b_notes[$i]) % 12;
    $dis_orig++ unless grep{$_==$int_orig} @CONSONANT;
    $dis_corr++ unless grep{$_==$int_corr} @CONSONANT;
}
printf "Disonancias S-B: %d originales → %d tras correcciones\n\n", $dis_orig, $dis_corr;

print "Muestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-4s  A:%-4s  T:%-4s  B:%-4s\n", $tetras[$_], mn($s_notes[$_]), mn($a_notes[$_]), mn($t_notes[$_]), mn($b_notes[$_]) for 0..7;
