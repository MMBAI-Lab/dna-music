#!/usr/bin/perl
use strict;
use warnings;

# =================================================================
# aprox6/prueba1 — 4 voces SATB estilo blues/jazz
#
# Basada en aprox5/prueba2, con los siguientes cambios:
#
# ESCALA: La Dorian (A, B, C, D, E, F#, G)
#   Cromas: 9, 11, 0, 2, 4, 6, 7
#   Muy característica del jazz/blues moderno y modal jazz
#   (Miles Davis "So What", John Coltrane, etc.)
#
# REGISTROS (centrados en La en vez de Re):
#   Soprano  major groove  A4–A6  [MIDI 69–93]  centro E5 (76)
#   Alto     corrección    D4–G5  [MIDI 62–79]  centro A4 (69)
#   Tenor    corrección    G3–D5  [MIDI 55–74]  centro D4 (62)
#   Bajo     minor groove  A2–A4  [MIDI 45–69]  centro E3 (52)
#
# TEMPO: 108 BPM (medium swing)
#
# SWING: las corcheas (240 ticks) se ejecutan en ratio 2:1
#   → pares de corcheas consecutivas: larga (320t) + corta (160t)
#   → notas más largas (≥ negra) no se swingean
#   Produce el "lilt" característico del jazz
#
# DURACIONES: misma normalización lineal que aprox4/5
#
# REGLAS DE CORRECCIÓN ARMÓNICA: idénticas a aprox5/prueba2 (R4–R9)
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

# ---- Escala La Dorian ----
# A=9, B=11, C=0, D=2, E=4, F#=6, G=7
my @A_DORIAN = (0, 2, 4, 6, 7, 9, 11);

sub snap_to_scale {
    my ($midi, $scale_ref) = @_;
    my $chroma = $midi % 12;
    my $base   = $midi - $chroma;
    my ($best_c, $best_diff) = ($scale_ref->[0], 99);
    for my $c (@$scale_ref) {
        my $d = abs($chroma - $c);
        $d = 12 - $d if $d > 6;
        if ($d < $best_diff) { $best_diff = $d; $best_c = $c; }
    }
    my $n = $base + $best_c;
    $n += 12 if ($chroma - $best_c) > 6;
    $n -= 12 if ($best_c - $chroma) > 6;
    return $n;
}

sub force_register {
    my ($midi, $center, $lo, $hi) = @_;
    my $chroma = $midi % 12;
    my ($best, $bd) = ($midi, 999);
    for my $oct (0..9) {
        my $c = $oct*12+$chroma; next if $c<$lo||$c>$hi;
        my $d = abs($c-$center);
        if ($d<$bd) { $bd=$d; $best=$c; }
    }
    return $best;
}

sub apply_voice_leading {
    my ($notes_ref, $max_leap, $lo, $hi) = @_;
    my @r = ($notes_ref->[0]);
    for my $i (1..$#$notes_ref) {
        my ($prev, $curr) = ($r[-1], $notes_ref->[$i]);
        if (abs($curr-$prev) > $max_leap) {
            my $adj = ($curr>$prev) ? $curr-12 : $curr+12;
            $curr = $adj if $adj>=$lo && $adj<=$hi;
        }
        push @r, $curr;
    }
    return @r;
}

# ---- Escalas de corrección por registro ----
sub scale_in_range {
    my ($scale_ref, $lo, $hi) = @_;
    my @n;
    for my $oct (0..9) { push @n, $oct*12+$_ for @$scale_ref; }
    return sort{$a<=>$b} grep{$_>=$lo&&$_<=$hi} @n;
}

my @S_SCALE = scale_in_range(\@A_DORIAN, 69, 93);   # Soprano A4-A6
my @A_SCALE = scale_in_range(\@A_DORIAN, 62, 79);   # Alto D4-G5
my @T_SCALE = scale_in_range(\@A_DORIAN, 55, 74);   # Tenor G3-D5

# Consonancias permitidas (mismas que aprox5)
my @CONSONANT = (0, 3, 4, 7, 8, 9);
sub is_consonant { my $i=($_[0]-$_[1])%12; scalar grep{$_==$i} @CONSONANT }

sub generate_alto {
    my ($s, $b, $prev_a) = @_;
    $prev_a //= 69;
    my ($best, $bs) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;
        my $sc = abs($c-$prev_a) + (is_consonant($c,$b)?0:15) + ($s-$c<3?5:0);
        if ($sc<$bs) { $bs=$sc; $best=$c; }
    }
    return $best // 69;
}

sub generate_tenor {
    my ($s, $b, $a, $prev_t) = @_;
    $prev_t //= 62;
    my ($best, $bs) = (undef, 1e9);
    for my $c (@T_SCALE) {
        next if $c>=$a || $c<=$b;
        my $sc = abs($c-$prev_t) + (is_consonant($c,$b)?0:15);
        if ($sc<$bs) { $bs=$sc; $best=$c; }
    }
    unless (defined $best) {
        my $mid = int(($a+$b)/2);
        $best = (sort{abs($a-$mid)<=>abs($b-$mid)} @T_SCALE)[0] // 62;
    }
    return $best;
}

sub check_parallel_sb {
    my ($ps,$pb,$s,$b) = @_;
    return $s unless defined $ps;
    my ($pi,$ci) = (($ps-$pb)%12, ($s-$b)%12);
    if (($pi==7&&$ci==7)||($pi==0&&$ci==0)) {
        for my $i (0..$#S_SCALE-1) { return $S_SCALE[$i+1] if $S_SCALE[$i]==$s; }
    }
    return $s;
}

sub check_parallel_sa {
    my ($ps,$pa,$s,$a) = @_;
    return $a unless defined $ps;
    my ($pi,$ci) = (($ps-$pa)%12, ($s-$a)%12);
    if (($pi==7&&$ci==7)||($pi==0&&$ci==0)) {
        for my $i (1..$#A_SCALE) {
            return $A_SCALE[$i-1] if $A_SCALE[$i]==$a && $A_SCALE[$i-1]<$s;
        }
    }
    return $a;
}

# ---- Carga de datos ----
sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh,'<:encoding(UTF-8)',$path) or die "No se puede abrir $path: $!";
    <$fh>;
    while (my $line=<$fh>) {
        chomp $line; my @f=split(',',$line);
        if ($f[4]=~/^([A-G]#?)(\d)$/) { $map{$f[0]}=12*($2+1)+$note_idx{$1}; }
    }
    close $fh; return %map;
}

sub load_dat_tiempo {
    my ($dir) = @_;
    my %map;
    opendir(my $dh,$dir) or die "No se puede abrir $dir: $!";
    while (my $f=readdir($dh)) {
        next unless $f=~/\.dat$/i;
        my $content=do{local $/;open(my $fh,'<:encoding(UTF-8)',"$dir/$f")or die $!;<$fh>};
        (my $key=$f)=~s/\.(MG|mg)\.dat$//i;
        $content=~/Tiempo de vida media: ([\d.]+)/ and $map{$key}=$1+0;
    }
    closedir $dh; return %map;
}

my %comp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rev_comp { join('',reverse map{$comp{$_}} split('',$_[0])) }
sub get_tiempo {
    my ($r,$t)=@_;
    return $r->{$t}           if exists $r->{$t};
    return $r->{rev_comp($t)} if exists $r->{rev_comp($t)};
    die "No encontrado: $t\n";
}

# ---- Figuras (normalización lineal aprox4) ----
my @FIGURES = (
    {ticks=>240, name=>'corchea'},
    {ticks=>360, name=>'corchea con punto'},
    {ticks=>480, name=>'negra'},
    {ticks=>720, name=>'negra con punto'},
    {ticks=>960, name=>'blanca'},
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

# ---- SWING ----
# Par de corcheas consecutivas: 320t (larga) + 160t (corta)  [ratio 2:1]
# Notas de negra o más largas: sin swing
# Estado: alterna largo/corto dentro de cada par de corcheas
sub apply_swing {
    my (@durs) = @_;
    my @result;
    my $swing_state = 0;  # 0=larga, 1=corta
    for my $d (@durs) {
        if ($d == 240) {
            push @result, $swing_state==0 ? 320 : 160;
            $swing_state = 1 - $swing_state;
        } else {
            push @result, $d;
            $swing_state = 0;  # reset al romper la cadena de corcheas
        }
    }
    return @result;
}

# ---- Cargar datos ----
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

# ---- Procesar voces ----
my (@s_raw,@b_raw,@s_fig,@b_fig);
for my $t (@tetras) {
    push @s_raw, force_register(snap_to_scale($mg_midi{$t},\@A_DORIAN), 76, 69, 93);
    push @s_fig, ps_to_ticks_linear(get_tiempo(\%mg_tiempo,$t),$mg_min,$mg_max);
    push @b_raw, force_register(snap_to_scale($mn_midi{$t},\@A_DORIAN), 52, 45, 69);
    push @b_fig, ps_to_ticks_linear(get_tiempo(\%mn_tiempo,$t),$mn_min,$mn_max);
}
my @s_notes = apply_voice_leading(\@s_raw, 7, 69, 93);
my @b_notes = apply_voice_leading(\@b_raw, 7, 45, 69);

for my $i (1..$#s_notes) {
    $s_notes[$i] = check_parallel_sb($s_notes[$i-1],$b_notes[$i-1],$s_notes[$i],$b_notes[$i]);
}

my (@a_notes,@t_notes);
my ($prev_a,$prev_t) = (69,62);
for my $i (0..$#tetras) {
    my ($s,$b) = ($s_notes[$i],$b_notes[$i]);
    my $a = generate_alto($s,$b,$prev_a);
    $a = check_parallel_sa($i>0?$s_notes[$i-1]:undef,$i>0?$a_notes[-1]:undef,$s,$a);
    my $t = generate_tenor($s,$b,$a,$prev_t);
    push @a_notes,$a; push @t_notes,$t;
    ($prev_a,$prev_t) = ($a,$t);
}

# ---- Aplicar swing ----
my @s_ticks = apply_swing(map{$_->{ticks}} @s_fig);
my @b_ticks = apply_swing(map{$_->{ticks}} @b_fig);
# Alto hereda swing de soprano, tenor hereda swing de bajo
my @a_ticks = @s_ticks;
my @t_ticks = @b_ticks;

# ---- Construir pistas MIDI ----
my $ticks_per_beat = 480;
my $tempo = int(60_000_000 / 108);  # 108 BPM = 555555 µs

sub build_track {
    my ($notes_ref,$ticks_ref,$ch,$name) = @_;
    my ($on,$off) = (0x90|$ch, 0x80|$ch);
    my $track = vlq(0)."\xFF\x03".chr(length($name)).$name;
    my %fig_count;
    for my $i (0..$#$notes_ref) {
        my ($m,$d) = ($notes_ref->[$i], $ticks_ref->[$i]);
        $fig_count{$d}++;
        $track .= vlq(0).chr($on).chr($m).chr(90);
        $track .= vlq($d).chr($off).chr($m).chr(0);
    }
    $track .= vlq(0)."\xFF\x2F\x00";
    return ($track, %fig_count);
}

my $tempo_track = vlq(0)."\xFF\x03\x05Tempo"
    .vlq(0)."\xFF\x51\x03"
    .chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF)
    .vlq(0)."\xFF\x2F\x00";

my ($t_sop, %fc_sop) = build_track(\@s_notes,\@s_ticks,0,'Soprano (major groove)');
my ($t_alt, %fc_alt) = build_track(\@a_notes,\@a_ticks,1,'Alto (correccion)');
my ($t_ten, %fc_ten) = build_track(\@t_notes,\@t_ticks,2,'Tenor (correccion)');
my ($t_bas, %fc_bas) = build_track(\@b_notes,\@b_ticks,3,'Bajo (minor groove)');

my $midi = "MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks_per_beat);
$midi .= midi_chunk("MTrk",$_) for ($tempo_track,$t_sop,$t_alt,$t_ten,$t_bas);

my $out = "$base/aprox6/prueba1/prueba1.mid";
open(my $fh_out,'>:raw',$out) or die $!;
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Escala: La Dorian (A B C D E F# G)\n";
print "Tempo: 108 BPM | Swing: corcheas 2:1\n";
print "Tetranucleotidos: ".scalar(@tetras)."\n\n";

print "Distribución de duraciones — Soprano (tras swing):\n";
my %names = (160=>'corchea corta (swing)',240=>'corchea',320=>'corchea larga (swing)',360=>'corchea c/punto',480=>'negra',720=>'negra c/punto',960=>'blanca');
for my $t (sort{$a<=>$b} keys %fc_sop) {
    printf "  %-28s %d notas\n", $names{$t}//"$t ticks", $fc_sop{$t};
}
print "\nMuestra primeras 10 notas (SATB):\n";
printf "%-6s  S:%-5s  A:%-5s  T:%-5s  B:%-5s  dur_s:%s\n",
    $tetras[$_], mn($s_notes[$_]), mn($a_notes[$_]),
    mn($t_notes[$_]), mn($b_notes[$_]), $names{$s_ticks[$_]}//"$s_ticks[$_]t"
    for 0..9;
