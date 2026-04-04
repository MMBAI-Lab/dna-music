#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# aprox5/prueba3 — Secuencia de ADN diseñada para aproximar
#                  Contrapunctus 1 (J.S. Bach, BWV 1080)
#
# ESTRATEGIA:
#   1. Definir melodía objetivo basada en el sujeto del Contrapunctus 1
#      desarrollado hasta ~2 minutos (~170 notas a 72 BPM)
#   2. Para cada uno de los 256 tetranucleótidos, precalcular la nota
#      soprano resultante (snap a Re menor → registro D4–D6)
#   3. Construir el grafo de adyacencia: ABCD → BCDE (4 posibles)
#   4. Búsqueda greedy: en cada paso, de los 4 posibles sucesores,
#      elegir el que produce la nota más cercana a la nota objetivo
#   5. Generar MIDI con la misma cadena de transformaciones que prueba1
#   6. Guardar secuencia ADN en archivo .dat
#
# MELODÍA OBJETIVO — Sujeto del Contrapunctus 1 desarrollado:
#   El sujeto original (Re menor, 11 notas):
#     D5 A4 F4 G4 A4 Bb4 A4 G4 F4 E4 D4
#   Seguido de: respuesta, fragmentos, secuencias, inversión, stretta
#   Longitud total: ~170 notas → DNA de ~173 bases
#
# DURACIÓN: normalización lineal (aprox4), tempo 72 BPM
#   Duración promedio ~0.67s → ~170 notas ≈ 113s ≈ 1:53 min
# =================================================================

my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);
my @NOTE_NAMES = ('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn { $NOTE_NAMES[$_[0]%12].int($_[0]/12-1) }

sub vlq {
    my ($val) = @_;
    return chr($val) if $val < 128;
    my @bytes;
    push @bytes, $val & 0x7F; $val >>= 7;
    while ($val>0) { push @bytes, ($val&0x7F)|0x80; $val>>=7; }
    return join('', map{chr($_)} reverse @bytes);
}
sub midi_chunk { $_[0].pack('N',length($_[1])).$_[1] }

my @D_MINOR_CHROMA = (0, 2, 4, 5, 7, 9, 10);

sub snap_to_d_minor {
    my ($midi) = @_;
    my $chroma = $midi%12; my $base = $midi-$chroma;
    my ($bc,$bd) = ($D_MINOR_CHROMA[0], 99);
    for my $c (@D_MINOR_CHROMA) {
        my $d = abs($chroma-$c); $d = 12-$d if $d>6;
        if ($d<$bd) { $bd=$d; $bc=$c; }
    }
    my $n = $base+$bc;
    $n+=12 if ($chroma-$bc)>6; $n-=12 if ($bc-$chroma)>6;
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

my @FIGURES = (
    {ticks=>240,name=>'corchea'},
    {ticks=>360,name=>'corchea con punto'},
    {ticks=>480,name=>'negra'},
    {ticks=>720,name=>'negra con punto'},
    {ticks=>960,name=>'blanca'},
);
sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }
sub ps_to_ticks_linear {
    my ($ps,$min,$max)=@_;
    my $n=scalar @FIGURES;
    my $idx=int(($ps-$min)/($max-$min)*$n);
    $idx=0 if $idx<0; $idx=$n-1 if $idx>=$n;
    return $FIGURES[$idx];
}

sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh,'<:encoding(UTF-8)',$path) or die $!; <$fh>;
    while (<$fh>) {
        chomp; my @f=split(',',$_);
        $f[4]=~/^([A-G]#?)(\d)$/ and $map{$f[0]}=12*($2+1)+$note_idx{$1};
    }
    close $fh; return %map;
}

sub load_dat_tiempo {
    my ($dir) = @_;
    my %map;
    opendir(my $dh,$dir) or die $!;
    while (my $f=readdir($dh)) {
        next unless $f=~/\.dat$/i;
        my $c=do{local $/;open(my $fh,'<:encoding(UTF-8)',"$dir/$f")or die $!;<$fh>};
        (my $k=$f)=~s/\.(MG|mg)\.dat$//i;
        $c=~/Tiempo de vida media: ([\d.]+)/ and $map{$k}=$1+0;
    }
    closedir $dh; return %map;
}

my %comp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rev_comp { join('',reverse map{$comp{$_}} split('',$_[0])) }
sub get_tiempo {
    my($r,$t)=@_;
    return $r->{$t}           if exists $r->{$t};
    return $r->{rev_comp($t)} if exists $r->{rev_comp($t)};
    die "No encontrado: $t\n";
}

my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg_midi   = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn_midi   = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mg_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %mn_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");
my ($mg_min,$mg_max) = (list_min(values %mg_tiempo), list_max(values %mg_tiempo));
my ($mn_min,$mn_max) = (list_min(values %mn_tiempo), list_max(values %mn_tiempo));

# --- Precalcular nota soprano para cada tetranucleótido ---
my %tetra_sop_note;
for my $t (keys %mg_midi) {
    $tetra_sop_note{$t} = force_register(snap_to_d_minor($mg_midi{$t}), 69, 62, 86);
}

# --- Grafo de adyacencia: ABCD → {BCDA, BCDC, BCDG, BCDT} ---
my %successors; # suffix3 -> list of tetras
for my $t (keys %tetra_sop_note) {
    push @{$successors{substr($t,1,3)}}, $t;
}

# =================================================================
# MELODÍA OBJETIVO — Contrapunctus 1, sujeto desarrollado
# Sujeto en Re menor (D4-D6):
#   D5  A4  F4  G4  A4  Bb4 A4  G4  F4  E4  D4
#   74  69  65  67  69  70  69  67  65  64  62
# =================================================================
my @target = (
    # Sujeto 1 (Re menor, comienza en D5)
    74, 69, 65, 67, 69, 70, 69, 67, 65, 64, 62,
    # Respuesta (en La, comienza en A4)
    69, 64, 72, 74, 76, 77, 76, 74, 72, 70, 69,
    # Sujeto 2 (Re menor, comienza en D4)
    62, 69, 65, 67, 69, 70, 69, 67, 65, 64, 62,
    # Respuesta 2
    69, 64, 72, 74, 76, 77, 76, 74, 72, 70, 69,
    # Secuencia descendente
    74, 72, 70, 69, 67, 65, 64, 62, 64, 65, 67, 69, 70, 69, 67, 65,
    # Secuencia ascendente
    62, 64, 65, 67, 69, 70, 72, 74, 76, 77, 79, 77, 76, 74, 72, 70,
    # Fragmentos del sujeto
    74, 69, 65, 67, 69, 70,
    69, 64, 72, 74, 76, 77,
    # Inversión del sujeto: D E G A Bb C Bb A G F E D (espejo)
    62, 64, 67, 69, 70, 72, 70, 69, 67, 65, 64, 62,
    # Desarrollo por secuencias
    67, 65, 64, 62, 64, 65, 67, 69, 70, 72, 74, 72, 70, 69,
    # Sujeto 3 (stretta, D5)
    74, 69, 65, 67, 69, 70, 69, 67, 65, 64, 62,
    # Cadencia final
    62, 64, 65, 64, 62, 65, 69, 70, 69, 67, 65, 64, 62,
    # Coda
    69, 70, 72, 74, 72, 70, 69, 67, 65, 64, 62,
);

printf "Melodía objetivo: %d notas\n", scalar @target;

# --- Búsqueda greedy ---
# Encontrar mejor tetranucleótido inicial
my ($best_start, $best_diff) = (undef, 999);
for my $t (keys %tetra_sop_note) {
    my $diff = abs($tetra_sop_note{$t} - $target[0]);
    if ($diff < $best_diff) { $best_diff=$diff; $best_start=$t; }
}

my @sequence = ($best_start);
my @achieved = ($tetra_sop_note{$best_start});

for my $i (1..$#target) {
    my $prev = $sequence[-1];
    my $sfx3 = substr($prev, 1, 3);
    my $candidates = $successors{$sfx3} // [];

    my ($best, $bd) = ($candidates->[0]//$prev, 999);
    for my $c (@$candidates) {
        my $d = abs($tetra_sop_note{$c} - $target[$i]);
        if ($d < $bd) { $bd=$d; $best=$c; }
    }
    push @sequence, $best;
    push @achieved, $tetra_sop_note{$best};
}

# Reconstruir secuencia DNA
my $dna = $sequence[0];
$dna .= substr($_, 3, 1) for @sequence[1..$#sequence];

printf "Secuencia DNA: %d bases, %d tetranucleótidos\n", length($dna), scalar @sequence;

# Calcular error promedio
my $total_err = 0;
$total_err += abs($achieved[$_] - $target[$_]) for 0..$#target;
printf "Error promedio: %.2f semitonos\n\n", $total_err / scalar @target;

# --- Generar MIDI (mismo pipeline que prueba1) ---
my @tetras = @sequence;
my @s_raw  = map { force_register(snap_to_d_minor($mg_midi{$_}), 69, 62, 86) } @tetras;
my @s_dur  = map { ps_to_ticks_linear(get_tiempo(\%mg_tiempo,$_), $mg_min, $mg_max) } @tetras;

# Bass: minor groove
my @b_raw  = map { force_register(snap_to_d_minor($mn_midi{$_} // 62), 50, 38, 62) } @tetras;
my @b_dur  = map { ps_to_ticks_linear(get_tiempo(\%mn_tiempo,$_), $mn_min, $mn_max) } @tetras;

my @s_notes = apply_voice_leading(\@s_raw, 7, 62, 86);
my @b_notes = apply_voice_leading(\@b_raw, 7, 38, 62);

my $ticks = 480; my $tempo = 833333;

sub build_track {
    my ($notes_ref,$durs_ref,$ch,$name) = @_;
    my ($on,$off) = (0x90|$ch, 0x80|$ch);
    my $t = vlq(0)."\xFF\x03".chr(length($name)).$name;
    for my $i (0..$#$notes_ref) {
        my ($m,$d) = ($notes_ref->[$i],$durs_ref->[$i]{ticks});
        $t .= vlq(0).chr($on).chr($m).chr(85);
        $t .= vlq($d).chr($off).chr($m).chr(0);
    }
    $t .= vlq(0)."\xFF\x2F\x00"; return $t;
}

my $tempo_track = vlq(0)."\xFF\x51\x03"
    .chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF)
    .vlq(0)."\xFF\x2F\x00";

my $midi = "MThd".pack('N',6).pack('n',1).pack('n',3).pack('n',$ticks);
$midi .= midi_chunk("MTrk",$_) for (
    $tempo_track,
    build_track(\@s_notes,\@s_dur,0,'Soprano (major groove)'),
    build_track(\@b_notes,\@b_dur,1,'Bajo (minor groove)'),
);

my $midi_out = "$base/aprox5/prueba3/prueba3.mid";
open(my $fh_out,'>:raw',$midi_out) or die $!;
print $fh_out $midi; close $fh_out;
print "MIDI generado: $midi_out\n";

# --- Guardar .dat ---
my $dat_out = "$base/aprox5/prueba3/prueba3_secuencia.dat";
open(my $fh_dat,'>:encoding(UTF-8)',$dat_out) or die $!;
print $fh_dat "# Secuencia ADN diseñada para aproximar Contrapunctus 1 (J.S. Bach, BWV 1080)\n";
print $fh_dat "# Algoritmo: búsqueda greedy en espacio de tetranucleótidos solapados (paso 1)\n";
print $fh_dat "# Transformación: aprox5 — Re menor, soprano D4-D6, duración lineal aprox4\n";
print $fh_dat "#\n";
printf $fh_dat "Secuencia: %s\n", $dna;
printf $fh_dat "Longitud: %d bases\n", length($dna);
printf $fh_dat "Tetranucleotidos: %d\n", scalar @sequence;
print $fh_dat "BPM: 72\n";
print $fh_dat "Escala: Re menor natural (D E F G A Bb C)\n";
print $fh_dat "Registro soprano: D4-D6 (MIDI 62-86)\n";
printf $fh_dat "Error promedio: %.2f semitonos\n", $total_err/scalar @target;
print $fh_dat "#\n";
print $fh_dat "# Pos  Tetra  Objetivo       Generado       Error\n";
for my $i (0..$#target) {
    printf $fh_dat "# %-4d %-6s %-14s %-14s %d st\n",
        $i+1, $sequence[$i], mn($target[$i])."(".$target[$i].")",
        mn($achieved[$i])."(".$achieved[$i].")",
        abs($achieved[$i]-$target[$i]);
}
close $fh_dat;
print "DAT generado:  $dat_out\n";

# Resumen notas objetivo vs logradas
my %err_dist;
$err_dist{abs($achieved[$_]-$target[$_])}++ for 0..$#target;
print "\nDistribución de error (semitonos):\n";
printf "  %d st: %d notas\n", $_, $err_dist{$_} for sort{$a<=>$b} keys %err_dist;
