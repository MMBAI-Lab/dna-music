#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# Genera partitura LilyPond para aprox5/prueba2
# 4 voces SATB:
#   Soprano (major groove) → rojo
#   Alto    (corrección)   → negro
#   Tenor   (corrección)   → negro
#   Bajo    (minor groove) → azul
# =================================================================

# ---- Notas y duraciones ----
my @LY_NAMES = ('c','cis','d','dis','e','f','fis','g','gis','a','bes','b');

sub midi_to_ly {
    my ($midi) = @_;
    my $chroma = $midi % 12;
    my $octave = int($midi / 12) - 1;  # C4 = octave 4
    my $name   = $LY_NAMES[$chroma];
    my $marks  = '';
    if    ($octave > 3) { $marks = "'" x ($octave - 3); }
    elsif ($octave < 3) { $marks = "," x (3 - $octave); }
    return $name . $marks;
}

my %TICKS_TO_LY = (240=>'8', 360=>'8.', 480=>'4', 720=>'4.', 960=>'2');

# ---- Utilidades ----
my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

# ---- Escala Re menor natural ----
my @D_MINOR_CHROMA = (0, 2, 4, 5, 7, 9, 10);

sub snap_to_d_minor {
    my ($midi) = @_;
    my $chroma = $midi % 12; my $base = $midi - $chroma;
    my ($bc,$bd) = ($D_MINOR_CHROMA[0], 99);
    for my $c (@D_MINOR_CHROMA) {
        my $d = abs($chroma-$c); $d = 12-$d if $d>6;
        if ($d<$bd) { $bd=$d; $bc=$c; }
    }
    my $n = $base+$bc;
    $n+=12 if ($chroma-$bc)>6;
    $n-=12 if ($bc-$chroma)>6;
    return $n;
}

sub force_register {
    my ($midi,$center,$lo,$hi) = @_;
    my $chroma = $midi%12;
    my ($best,$bd) = ($midi,999);
    for my $oct (0..9) {
        my $c=$oct*12+$chroma; next if $c<$lo||$c>$hi;
        my $d=abs($c-$center); if ($d<$bd){$bd=$d;$best=$c;}
    }
    return $best;
}

sub apply_voice_leading {
    my ($notes_ref,$max_leap,$lo,$hi) = @_;
    my @r=($notes_ref->[0]);
    for my $i (1..$#$notes_ref) {
        my($prev,$curr)=($r[-1],$notes_ref->[$i]);
        if (abs($curr-$prev)>$max_leap) {
            my $adj=($curr>$prev)?$curr-12:$curr+12;
            $curr=$adj if $adj>=$lo&&$adj<=$hi;
        }
        push @r,$curr;
    }
    return @r;
}

sub d_minor_in_range {
    my ($lo,$hi) = @_;
    my @n;
    for my $o (0..9) { push @n, $o*12+$_ for @D_MINOR_CHROMA; }
    return sort{$a<=>$b} grep{$_>=$lo&&$_<=$hi} @n;
}

my @A_SCALE = d_minor_in_range(55,72);
my @T_SCALE = d_minor_in_range(48,67);
my @S_SCALE = d_minor_in_range(62,86);

my @CONSONANT = (0,3,4,7,8,9);
sub is_consonant { my $i=($_[0]-$_[1])%12; scalar grep{$_==$i}@CONSONANT }

sub generate_alto {
    my ($s,$b,$prev_a) = @_;
    $prev_a //= 62;
    my ($best,$bs)=(undef,1e9);
    for my $c (@A_SCALE) {
        next if $c>=$s;
        my $sc=abs($c-$prev_a)+(is_consonant($c,$b)?0:15)+($s-$c<3?5:0);
        if ($sc<$bs){$bs=$sc;$best=$c;}
    }
    return $best//62;
}

sub generate_tenor {
    my ($s,$b,$a,$prev_t)=@_;
    $prev_t//=52;
    my ($best,$bs)=(undef,1e9);
    for my $c (@T_SCALE) {
        next if $c>=$a||$c<=$b;
        my $sc=abs($c-$prev_t)+(is_consonant($c,$b)?0:15);
        if ($sc<$bs){$bs=$sc;$best=$c;}
    }
    unless (defined $best) {
        my $mid=int(($a+$b)/2);
        $best=(sort{abs($a-$mid)<=>abs($b-$mid)}@T_SCALE)[0]//52;
    }
    return $best;
}

sub check_parallel_sb {
    my ($ps,$pb,$s,$b)=@_;
    return $s unless defined $ps;
    my ($pi,$ci)=(($ps-$pb)%12,($s-$b)%12);
    if (($pi==7&&$ci==7)||($pi==0&&$ci==0)) {
        for my $i (0..$#S_SCALE-1) { return $S_SCALE[$i+1] if $S_SCALE[$i]==$s; }
    }
    return $s;
}

sub check_parallel_sa {
    my ($ps,$pa,$s,$a)=@_;
    return $a unless defined $ps;
    my ($pi,$ci)=(($ps-$pa)%12,($s-$a)%12);
    if (($pi==7&&$ci==7)||($pi==0&&$ci==0)) {
        for my $i (1..$#A_SCALE) { return $A_SCALE[$i-1] if $A_SCALE[$i]==$a&&$A_SCALE[$i-1]<$s; }
    }
    return $a;
}

# ---- Carga de datos ----
sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>; # skip header
    while (my $line = <$fh>) {
        chomp $line;
        my @f = split(',', $line);
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
        if ($content =~ /Tiempo de vida media: ([\d.]+)/) {
            $map{$key} = $1 + 0;
        }
    }
    closedir $dh;
    return %map;
}

my %comp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rev_comp { join('',reverse map{$comp{$_}} split('',$_[0])) }
sub get_tiempo {
    my($r,$t)=@_;
    return $r->{$t}           if exists $r->{$t};
    return $r->{rev_comp($t)} if exists $r->{rev_comp($t)};
    die "No encontrado: $t\n";
}

my @FIGURES=({ticks=>240},{ticks=>360},{ticks=>480},{ticks=>720},{ticks=>960});
sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }
sub ps_to_ticks_linear {
    my ($ps,$min,$max)=@_;
    my $n=scalar @FIGURES;
    my $idx=int(($ps-$min)/($max-$min)*$n);
    $idx=0 if $idx<0; $idx=$n-1 if $idx>=$n;
    return $FIGURES[$idx]{ticks};
}

my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg_midi   = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn_midi   = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mg_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %mn_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");
my ($mg_min,$mg_max)=(list_min(values %mg_tiempo),list_max(values %mg_tiempo));
my ($mn_min,$mn_max)=(list_min(values %mn_tiempo),list_max(values %mn_tiempo));

my $seq="GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for (my $i=0;$i+4<=length($seq);$i++) { push @tetras, substr($seq,$i,4); }

# ---- Generar las 4 voces (mismo algoritmo que prueba2) ----
my (@s_raw,@b_raw,@s_ticks,@b_ticks);
for my $t (@tetras) {
    push @s_raw,   force_register(snap_to_d_minor($mg_midi{$t}), 69, 62, 86);
    push @s_ticks, ps_to_ticks_linear(get_tiempo(\%mg_tiempo,$t),$mg_min,$mg_max);
    push @b_raw,   force_register(snap_to_d_minor($mn_midi{$t}), 50, 38, 62);
    push @b_ticks, ps_to_ticks_linear(get_tiempo(\%mn_tiempo,$t),$mn_min,$mn_max);
}
my @s_notes=apply_voice_leading(\@s_raw,7,62,86);
my @b_notes=apply_voice_leading(\@b_raw,7,38,62);
for my $i (1..$#s_notes) {
    $s_notes[$i]=check_parallel_sb($s_notes[$i-1],$b_notes[$i-1],$s_notes[$i],$b_notes[$i]);
}
my (@a_notes,@t_notes);
my ($prev_a,$prev_t)=(62,52);
for my $i (0..$#tetras) {
    my ($s,$b)=($s_notes[$i],$b_notes[$i]);
    my $a=generate_alto($s,$b,$prev_a);
    $a=check_parallel_sa($i>0?$s_notes[$i-1]:undef,$i>0?$a_notes[-1]:undef,$s,$a);
    my $t=generate_tenor($s,$b,$a,$prev_t);
    push @a_notes,$a; push @t_notes,$t;
    ($prev_a,$prev_t)=($a,$t);
}

# ---- Construir secuencias LilyPond ----
# Insertar barra visual cada 8 notas para legibilidad
sub build_ly_seq {
    my ($notes_ref,$ticks_ref,$notes_per_bar) = @_;
    $notes_per_bar //= 8;
    my @out;
    for my $i (0..$#$notes_ref) {
        push @out, midi_to_ly($notes_ref->[$i]) . $TICKS_TO_LY{$ticks_ref->[$i]};
        if (($i+1) % $notes_per_bar == 0 && $i < $#$notes_ref) {
            push @out, '\bar "|"';
        }
    }
    return join(' ', @out);
}

my $sop_ly = build_ly_seq(\@s_notes, \@s_ticks);
my $alt_ly = build_ly_seq(\@a_notes, \@s_ticks);  # Alto comparte duraciones con Soprano
my $ten_ly = build_ly_seq(\@t_notes, \@b_ticks);  # Tenor comparte duraciones con Bajo
my $bas_ly = build_ly_seq(\@b_notes, \@b_ticks);

# ---- Generar archivo .ly ----
my $ly = <<'HEADER';
\version "2.24.0"

% ============================================================
% ABC Música Mollá — aprox5/prueba2
% 4 voces SATB: soprano y bajo desde datos de ADN,
%               alto y tenor como corrección armónica
%
% Colores:
%   Rojo  = Soprano (major groove) — datos
%   Negro = Alto y Tenor           — corrección armónica
%   Azul  = Bajo (minor groove)    — datos
%
% Secuencia ADN:
%   GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGG
%   CGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAAT
%   GTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAG
%   AGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC
%   (234 bases, 231 tetranucleótidos solapados)
%
% Transformaciones:
%   - Escala: Re menor natural (D E F G A Bb C)
%   - Soprano: major groove, registro D4-D6, snap Re menor, voice leading
%   - Bajo:    minor groove, registro D2-D4, snap Re menor, voice leading
%   - Alto:    corrección armónica, G3-C5, minimiza disonancia con bajo
%   - Tenor:   corrección armónica, C3-G4, entre bajo y alto
%   - Duración: normalización lineal del tiempo de vida media (aprox4)
%   - Tempo: 72 BPM
% ============================================================

colorRojo = {
  \override NoteHead.color   = #red
  \override Stem.color       = #red
  \override Flag.color       = #red
  \override Beam.color       = #red
  \override Accidental.color = #red
  \override Dots.color       = #red
}

colorAzul = {
  \override NoteHead.color   = #blue
  \override Stem.color       = #blue
  \override Flag.color       = #blue
  \override Beam.color       = #blue
  \override Accidental.color = #blue
  \override Dots.color       = #blue
}

soprano = {
  \clef treble
  \key d \minor
  \tempo "Andante moderato" 4 = 72
  \cadenzaOn
  \colorRojo
HEADER

$ly .= "  $sop_ly\n";
$ly .= "  \\bar \"|.\"\n}\n\n";

$ly .= "alto = {\n  \\clef treble\n  \\key d \\minor\n  \\cadenzaOn\n";
$ly .= "  $alt_ly\n";
$ly .= "  \\bar \"|.\"\n}\n\n";

$ly .= "tenor = {\n  \\clef bass\n  \\key d \\minor\n  \\cadenzaOn\n";
$ly .= "  $ten_ly\n";
$ly .= "  \\bar \"|.\"\n}\n\n";

$ly .= "bass = {\n  \\clef bass\n  \\key d \\minor\n  \\cadenzaOn\n  \\colorAzul\n";
$ly .= "  $bas_ly\n";
$ly .= "  \\bar \"|.\"\n}\n\n";

$ly .= <<'FOOTER';
\score {
  \new ChoirStaff <<
    \new Staff \with { instrumentName = "S." shortInstrumentName = "S." }
      { \soprano }
    \new Staff \with { instrumentName = "A." shortInstrumentName = "A." }
      { \alto }
    \new Staff \with { instrumentName = "T." shortInstrumentName = "T." }
      { \tenor }
    \new Staff \with { instrumentName = "B." shortInstrumentName = "B." }
      { \bass }
  >>
  \layout {
    indent = 2\cm
    \context {
      \Score
      \omit BarNumber
    }
  }
}
FOOTER

my $out = "$base/aprox5/prueba2/prueba2.ly";
open(my $fh,'>:encoding(UTF-8)',$out) or die $!;
print $fh $ly;
close $fh;

printf "Generado: %s\n", $out;
printf "Notas por voz: %d\n", scalar @tetras;
printf "Compilar con: lilypond \"%s\"\n", $out;
