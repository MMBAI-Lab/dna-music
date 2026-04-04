#!/usr/bin/perl
use strict;
use warnings;

# ============================================================
# aprox5/prueba1 — Transformación estilo Bach (Contrapunctus 1)
#
# Transformaciones aplicadas sobre los datos de ADN:
#   1. Pitch: quantizar a Re menor natural (D E F G A Bb C)
#   2. Registro: soprano (major groove, D4–D6) / bajo (minor groove, D2–D4)
#   3. Voice leading: suavizar saltos > 7 semitonos por inversión de octava
#   4. Duración: normalización lineal del tiempo de vida media (aprox4)
#   5. Tempo: 72 BPM (♩ = 833333 µs)
# ============================================================

# ---- Escala Re menor natural (valores cromáticos mod 12) ----
# D=2, E=4, F=5, G=7, A=9, Bb=10, C=0
my @D_MINOR = (0, 2, 4, 5, 7, 9, 10);

sub snap_to_d_minor {
    my ($midi) = @_;
    my $chroma = $midi % 12;
    my $base   = $midi - $chroma;
    my ($best_c, $best_diff) = ($D_MINOR[0], 99);
    for my $c (@D_MINOR) {
        my $diff = abs($chroma - $c);
        $diff = 12 - $diff if $diff > 6;
        if ($diff < $best_diff) { $best_diff = $diff; $best_c = $c; }
    }
    my $new_midi = $base + $best_c;
    $new_midi += 12 if ($chroma - $best_c) > 6;
    $new_midi -= 12 if ($best_c - $chroma) > 6;
    return $new_midi;
}

# Forzar nota al registro más cercano al centro, dentro de [lo, hi]
sub force_register {
    my ($midi, $center, $lo, $hi) = @_;
    my $chroma = $midi % 12;
    my ($best, $best_diff) = ($midi, 999);
    for my $oct (0..9) {
        my $candidate = $oct * 12 + $chroma;
        next if $candidate < $lo || $candidate > $hi;
        my $diff = abs($candidate - $center);
        if ($diff < $best_diff) { $best_diff = $diff; $best = $candidate; }
    }
    return $best;
}

# Suavizar saltos grandes: si intervalo > max_leap, intentar inversión de octava
sub apply_voice_leading {
    my ($notes_ref, $max_leap, $lo, $hi) = @_;
    my @result = ($notes_ref->[0]);
    for my $i (1 .. $#$notes_ref) {
        my $prev = $result[-1];
        my $curr = $notes_ref->[$i];
        if (abs($curr - $prev) > $max_leap) {
            my $adjusted = ($curr > $prev) ? $curr - 12 : $curr + 12;
            $curr = $adjusted if $adjusted >= $lo && $adjusted <= $hi;
        }
        push @result, $curr;
    }
    return @result;
}

# ---- Utilidades MIDI ----
sub vlq {
    my ($val) = @_;
    return chr($val) if $val < 128;
    my @bytes;
    push @bytes, $val & 0x7F;
    $val >>= 7;
    while ($val > 0) { push @bytes, ($val & 0x7F) | 0x80; $val >>= 7; }
    return join('', map { chr($_) } reverse @bytes);
}

sub midi_chunk {
    my ($tag, $data) = @_;
    return $tag . pack('N', length($data)) . $data;
}

# ---- Carga de datos ----
my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>;
    while (<$fh>) {
        chomp;
        my @f = split(',', $_);
        if ($f[4] =~ /^([A-G]#?)(\d)$/) {
            $map{$f[0]} = 12 * ($2 + 1) + $note_idx{$1};
        }
    }
    close $fh;
    return %map;
}

sub load_dat_tiempo {
    my ($dir) = @_;
    my %map;
    opendir(my $dh, $dir) or die "No se puede abrir $dir: $!";
    while (my $f = readdir($dh)) {
        next unless $f =~ /\.dat$/i;
        my $content = do { local $/; open(my $fh, '<:encoding(UTF-8)', "$dir/$f") or die $!; <$fh> };
        (my $key = $f) =~ s/\.(MG|mg)\.dat$//i;
        if ($content =~ /Tiempo de vida media: ([\d.]+)/) { $map{$key} = $1 + 0; }
    }
    closedir $dh;
    return %map;
}

my %comp = (A=>'T', T=>'A', C=>'G', G=>'C');
sub rev_comp { join('', reverse map { $comp{$_} } split('', $_[0])) }

sub get_tiempo {
    my ($map_ref, $tetra) = @_;
    return $map_ref->{$tetra}            if exists $map_ref->{$tetra};
    return $map_ref->{rev_comp($tetra)}  if exists $map_ref->{rev_comp($tetra)};
    die "Tetranucleotido no encontrado: $tetra\n";
}

# ---- Figuras (normalización lineal aprox4) ----
my @FIGURES = (
    { ticks => 240, name => 'corchea'           },
    { ticks => 360, name => 'corchea con punto' },
    { ticks => 480, name => 'negra'             },
    { ticks => 720, name => 'negra con punto'   },
    { ticks => 960, name => 'blanca'            },
);

sub ps_to_ticks_linear {
    my ($ps, $min, $max) = @_;
    my $n   = scalar @FIGURES;
    my $idx = int(($ps - $min) / ($max - $min) * $n);
    $idx = 0     if $idx < 0;
    $idx = $n-1  if $idx >= $n;
    return $FIGURES[$idx];
}

sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }

# ---- Cargar datos ----
my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %major_midi   = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %minor_midi   = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %major_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %minor_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");

my ($mg_min, $mg_max) = (list_min(values %major_tiempo), list_max(values %major_tiempo));
my ($mn_min, $mn_max) = (list_min(values %minor_tiempo), list_max(values %minor_tiempo));

# ---- Secuencia ----
my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i++) {
    push @tetras, substr($seq, $i, 4);
}

# ---- Registros ----
# Soprano (major): D4(62)–D6(86), centro A4(69)  → voz superior tipo Bach
# Bajo    (minor): D2(38)–D4(62), centro D3(50)  → voz inferior tipo Bach
my ($sop_lo, $sop_hi, $sop_ctr) = (62, 86, 69);
my ($bas_lo, $bas_hi, $bas_ctr) = (38, 62, 50);

# ---- Procesar notas ----
my (@sop_notes, @bas_notes, @sop_durs, @bas_durs);
for my $tetra (@tetras) {
    # Soprano: snap a Re menor → forzar registro D4-D6
    my $snapped = snap_to_d_minor($major_midi{$tetra});
    push @sop_notes, force_register($snapped, $sop_ctr, $sop_lo, $sop_hi);
    push @sop_durs,  ps_to_ticks_linear(get_tiempo(\%major_tiempo, $tetra), $mg_min, $mg_max);

    # Bajo: snap a Re menor → forzar registro D2-D4
    $snapped = snap_to_d_minor($minor_midi{$tetra});
    push @bas_notes, force_register($snapped, $bas_ctr, $bas_lo, $bas_hi);
    push @bas_durs,  ps_to_ticks_linear(get_tiempo(\%minor_tiempo, $tetra), $mn_min, $mn_max);
}

# ---- Voice leading ----
@sop_notes = apply_voice_leading(\@sop_notes, 7, $sop_lo, $sop_hi);
@bas_notes = apply_voice_leading(\@bas_notes, 7, $bas_lo, $bas_hi);

# ---- Construir pistas MIDI ----
sub build_track {
    my ($notes_ref, $durs_ref, $ch) = @_;
    my ($note_on, $note_off) = (0x90|$ch, 0x80|$ch);
    my ($track, %fig_count) = ('');
    for my $i (0 .. $#$notes_ref) {
        my ($m, $dur) = ($notes_ref->[$i], $durs_ref->[$i]);
        $fig_count{$dur->{name}}++;
        $track .= vlq(0)             . chr($note_on)  . chr($m) . chr(85);
        $track .= vlq($dur->{ticks}) . chr($note_off) . chr($m) . chr(0);
    }
    $track .= vlq(0) . "\xFF\x2F\x00";
    return ($track, %fig_count);
}

my $tempo = 833333;  # 72 BPM
my $ticks = 480;

my $tempo_track = vlq(0) . "\xFF\x51\x03"
    . chr(($tempo>>16)&0xFF) . chr(($tempo>>8)&0xFF) . chr($tempo&0xFF)
    . vlq(0) . "\xFF\x2F\x00";

my ($track_sop, %fig_sop) = build_track(\@sop_notes, \@sop_durs, 0);
my ($track_bas, %fig_bas) = build_track(\@bas_notes, \@bas_durs, 1);

my $midi = "MThd" . pack('N',6) . pack('n',1) . pack('n',3) . pack('n',$ticks);
$midi .= midi_chunk("MTrk", $tempo_track);
$midi .= midi_chunk("MTrk", $track_sop);
$midi .= midi_chunk("MTrk", $track_bas);

my $out = "$base/aprox5/prueba1/prueba1.mid";
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Tempo: 72 BPM | Tetranucleotidos: " . scalar(@tetras) . "\n";
print "Escala: Re menor natural | Soprano D4-D6 | Bajo D2-D4\n\n";

my @note_names = ('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
print "Soprano (major groove) — primeras 10 notas:\n";
for my $i (0..9) {
    my $n = $sop_notes[$i];
    printf "  %s  %-4s (MIDI %d)  %s\n",
        $tetras[$i], $note_names[$n%12].int($n/12-1), $n, $sop_durs[$i]{name};
}
print "\nDistribución de figuras — Soprano:\n";
printf "  %-22s %d\n", $_->{name}, ($fig_sop{$_->{name}}//0) for @FIGURES;
print "\nDistribución de figuras — Bajo:\n";
printf "  %-22s %d\n", $_->{name}, ($fig_bas{$_->{name}}//0) for @FIGURES;
