#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# =================================================================
# aprox9/prueba2 — Compás de 4/4 explícito
#
# Idéntico a aprox9/prueba1 en conducción de voces (WTC/Bach) y
# normalización rítmica (applyWTCRhythm), con los siguientes cambios:
#
#   1. META-EVENTO DE COMPÁS 4/4:
#      FF 58 04 04 02 18 08 — escrito en la pista de tempo.
#      Hace que los editores de partituras (MuseScore, Sibelius, etc.)
#      y los DAW muestren las barras de compás correctamente.
#
#   2. PALETA DE FIGURAS RESTRINGIDA {corchea, negra, blanca}:
#      Solo se usan figuras que dividen exactamente 4 tiempos (1920 ticks):
#        corchea (240 t) = 1/2 tiempo
#        negra   (480 t) = 1  tiempo
#        blanca  (960 t) = 2  tiempos
#      Las figuras punteadas (360 = 3/4 tiempo; 720 = 1.5 tiempos) se
#      excluyen porque no encajan en la cuadrícula de 4/4.
#      → applyMeterQuantize aplica esta paleta DESPUÉS de applyWTCRhythm.
#
#   3. TOPE 2:1 en la paleta de 4/4:
#      Con {240, 480, 960}, el salto máximo entre figuras no adyacentes
#      es 4:1 (240→960). Se recorta a la figura válida más cercana
#      dentro del límite 2:1 (corchea→negra o negra→blanca).
#
# El resto del algoritmo (conducción de voces, R1–R9, duración
# logarítmica, instrumentos) es idéntico a aprox9/prueba1.
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
    return (($pi==7&&$ci==7)||($pi==0&&$ci==0)) ? 1 : 0;
}

sub check_parallel_sb {
    my ($ps, $pb, $s, $b) = @_;
    return $s unless defined $ps;
    my ($pi, $ci) = (($ps-$pb)%12, ($s-$b)%12);
    if (($pi==7&&$ci==7)||($pi==0&&$ci==0)) {
        for my $i (0 .. $#S_SCALE-1) {
            return $S_SCALE[$i+1] if $S_SCALE[$i] == $s;
        }
    }
    return $s;
}

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
        my $s1 = $l1>0?1:($l1<0?-1:0);
        my $s2 = $l2>0?1:($l2<0?-1:0);
        return 10 if $s1==$s2 && $s1!=0;
    }
    return 0;
}

sub generate_alto_wtc {
    my ($s, $b, $prev_a, $pp_a, $s_prev, $b_next, $b_next2) = @_;
    $prev_a //= 62;
    my ($best, $bscore) = (undef, 1e9);
    for my $c (@A_SCALE) {
        next if $c >= $s;
        my $score = wtc_melodic_cost($prev_a, $c);
        $score += 2 * wtc_harmonic_cost($c, $b);
        $score += wtc_harmonic_cost($c, $b_next)        if defined $b_next;
        $score += 0.5 * wtc_harmonic_cost($c, $b_next2) if defined $b_next2;
        $score += leap_resolution_cost($pp_a, $prev_a, $c);
        if (defined $s_prev) {
            my $sd = ($s>$s_prev)?1:($s<$s_prev)?-1:0;
            my $ad = ($c>$prev_a)?1:($c<$prev_a)?-1:0;
            $score -= 5 if $sd!=0 && $ad!=0 && $sd!=$ad;
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
        my $score = wtc_melodic_cost($prev_t, $c);
        $score += 1.5 * wtc_harmonic_cost($c, $b);
        $score += 0.8 * wtc_harmonic_cost($c, $a);
        $score += wtc_harmonic_cost($c, $b_next)        if defined $b_next;
        $score += 0.5 * wtc_harmonic_cost($c, $b_next2) if defined $b_next2;
        $score += leap_resolution_cost($pp_t, $prev_t, $c);
        if (defined $b_prev) {
            my $bd = ($b>$b_prev)?1:($b<$b_prev)?-1:0;
            my $td = ($c>$prev_t)?1:($c<$prev_t)?-1:0;
            $score -= 4 if $bd!=0 && $td!=0 && $bd!=$td;
        }
        $score += 20 if has_parallel($s_prev, $prev_t, $s, $c);
        $score += 20 if has_parallel($b_prev, $prev_t, $b, $c);
        $score += 0.1 * abs($c - $T_CENTER);
        if ($score < $bscore) { $bscore = $score; $best = $c; }
    }
    unless (defined $best) {
        my $mid = int(($a + $b) / 2);
        ($best) = sort { abs($a-$mid)<=>abs($b-$mid) }
                  grep { $_>$b && $_<$a } @T_SCALE;
        $best //= 52;
    }
    return $best;
}

# =============================================================
# PALETAS Y FUNCIONES DE DURACIÓN
# =============================================================

# Paleta completa WTC (5 figuras, para applyWTCRhythm)
my @WTC_FIGS = (240, 360, 480, 720, 960);

# Paleta de 4/4 (3 figuras: corchea, negra, blanca)
my @METER_4_4_FIGS = (240, 480, 960);

my %fig_names_full = (240=>'corchea', 360=>'corchea con punto',
                      480=>'negra', 720=>'negra con punto', 960=>'blanca');
my %fig_names_44   = (240=>'corchea', 480=>'negra', 960=>'blanca');

sub snap_to_pal {
    my ($ticks, @pal) = @_;
    my ($best, $bd) = ($pal[0], 1e9);
    for my $f (@pal) { my $d=abs($f-$ticks); if ($d<$bd){$bd=$d;$best=$f;} }
    return $best;
}

sub fig_idx_in { my ($f, @pal)=@_; for my $i(0..$#pal){return $i if $pal[$i]==$f;} return -1; }

# WTC run-homogenisation + 2:1 cap (5-figure palette)
sub apply_wtc_rhythm {
    my (@durs) = @_;
    return () unless @durs;
    my @s = map { snap_to_pal($_, @WTC_FIGS) } @durs;
    for my $i (0 .. $#s-1) {
        my $ai = fig_idx_in($s[$i], @WTC_FIGS);
        my $bi = fig_idx_in($s[$i+1], @WTC_FIGS);
        if (abs($ai-$bi)==1) { my $l=$s[$i]>$s[$i+1]?$s[$i]:$s[$i+1]; $s[$i+1]=$l; }
    }
    my @result = ($s[0]);
    for my $i (1..$#s) {
        my $p=$result[-1]; my $c=$s[$i];
        if ($c > $p*2) { my $b=$p; for my $f(@WTC_FIGS){$b=$f if $f<=$p*2;} push @result,$b; }
        elsif ($c*2 < $p) { my $b=$p; for my $f(@WTC_FIGS){$b=$f;last if $f>=$p/2;} push @result,$b; }
        else { push @result,$c; }
    }
    return @result;
}

# 4/4 quantize (3-figure palette, 2:1 cap, no merging)
sub apply_meter_44 {
    my (@durs) = @_;
    return () unless @durs;
    my @s = map { snap_to_pal($_, @METER_4_4_FIGS) } @durs;
    my @result = ($s[0]);
    for my $i (1..$#s) {
        my $p=$result[-1]; my $c=$s[$i];
        if ($c > $p*2) {
            my $b=$p; for my $f(@METER_4_4_FIGS){$b=$f if $f<=$p*2;} push @result,$b;
        } elsif ($c*2 < $p) {
            my $b=$p; for my $f(@METER_4_4_FIGS){$b=$f;last if $f>=$p/2;} push @result,$b;
        } else { push @result,$c; }
    }
    return @result;
}

sub list_min { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub list_max { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }

sub ps_to_ticks_log {
    my ($ps, $min, $max) = @_;
    my $n   = scalar @WTC_FIGS;
    my $idx = floor((log($ps)-log($min))/(log($max)-log($min))*$n);
    $idx=0 if $idx<0; $idx=$n-1 if $idx>=$n;
    return $WTC_FIGS[$idx];
}

# =============================================================
# CARGA DE DATOS
# =============================================================
sub load_csv_midi {
    my ($path) = @_;
    my %map;
    open(my $fh,'<:encoding(UTF-8)',$path) or die $!; <$fh>;
    while(<$fh>){chomp;my@f=split(',',$_);$f[4]=~/^([A-G]#?)(\d)$/and$map{$f[0]}=12*($2+1)+$note_idx{$1};}
    close $fh; return %map;
}

sub load_dat_tiempo {
    my ($dir) = @_;
    my %map;
    opendir(my $dh,$dir) or die $!;
    while(my $f=readdir($dh)){
        next unless $f=~/\.dat$/i;
        my $c=do{local $/;open(my $fh,'<:encoding(UTF-8)',"$dir/$f")or die $!;<$fh>};
        (my $k=$f)=~s/\.(MG|mg)\.dat$//i;
        $c=~/Tiempo de vida media: ([\d.]+)/ and $map{$k}=$1+0;
    }
    closedir $dh; return %map;
}

my %comp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rev_comp{join('',reverse map{$comp{$_}}split('',$_[0]))}
sub get_tiempo{
    my($r,$t)=@_;
    return $r->{$t} if exists $r->{$t};
    return $r->{rev_comp($t)} if exists $r->{rev_comp($t)};
    die "No encontrado: $t\n";
}

# =============================================================
# PIPELINE PRINCIPAL
# =============================================================
my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg_midi   = load_csv_midi("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn_midi   = load_csv_midi("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mg_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %mn_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");
my ($mg_min,$mg_max)=(list_min(values %mg_tiempo),list_max(values %mg_tiempo));
my ($mn_min,$mn_max)=(list_min(values %mn_tiempo),list_max(values %mn_tiempo));

my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for(my $i=0;$i+4<=length($seq);$i++){push @tetras,substr($seq,$i,4);}

# Notas + duraciones logarítmicas brutas
my (@s_raw,@b_raw,@s_dur_raw,@b_dur_raw);
for my $t (@tetras) {
    push @s_raw,     force_register(snap_to_d_minor($mg_midi{$t}),69,62,86);
    push @s_dur_raw, ps_to_ticks_log(get_tiempo(\%mg_tiempo,$t),$mg_min,$mg_max);
    push @b_raw,     force_register(snap_to_d_minor($mn_midi{$t}),50,38,62);
    push @b_dur_raw, ps_to_ticks_log(get_tiempo(\%mn_tiempo,$t),$mn_min,$mn_max);
}

# Paso 1: WTC rhythm (homogeneización de runs, tope 2:1, paleta 5)
my @s_wtc = apply_wtc_rhythm(@s_dur_raw);
my @b_wtc = apply_wtc_rhythm(@b_dur_raw);

# Paso 2: 4/4 quantize (paleta {240,480,960}, tope 2:1)
my @s_dur_ticks = apply_meter_44(@s_wtc);
my @b_dur_ticks = apply_meter_44(@b_wtc);

my @s_dur = map { {ticks=>$_} } @s_dur_ticks;
my @b_dur = map { {ticks=>$_} } @b_dur_ticks;

my @s_notes = apply_voice_leading(\@s_raw,7,62,86);
my @b_notes = apply_voice_leading(\@b_raw,7,38,62);

for my $i (1..$#s_notes) {
    $s_notes[$i]=check_parallel_sb($s_notes[$i-1],$b_notes[$i-1],$s_notes[$i],$b_notes[$i]);
}

my (@a_notes,@t_notes);
my ($prev_a,$prev_t)=(62,52);
my ($pp_a,$pp_t)=(undef,undef);

for my $i (0..$#tetras) {
    my $s=$s_notes[$i]; my $b=$b_notes[$i];
    my $sp=$i>0?$s_notes[$i-1]:undef;
    my $bp=$i>0?$b_notes[$i-1]:undef;
    my $bn=$i<$#tetras?$b_notes[$i+1]:undef;
    my $bn2=$i<$#tetras-1?$b_notes[$i+2]:undef;
    my $a=generate_alto_wtc($s,$b,$prev_a,$pp_a,$sp,$bn,$bn2);
    my $t=generate_tenor_wtc($s,$b,$a,$prev_t,$pp_t,$sp,$bp,$bn,$bn2);
    push @a_notes,$a; push @t_notes,$t;
    ($pp_a,$pp_t)=($prev_a,$prev_t);
    ($prev_a,$prev_t)=($a,$t);
}

# =============================================================
# MIDI CON META-EVENTO 4/4
# =============================================================
my $ticks = 480;
my $tempo = 833333; # 72 BPM

# Time signature meta event: FF 58 04 04 02 18 08
# nn=4, dd=2 (2^2=4), cc=24 MIDI clocks, bb=8 32nds per quarter
my $timesig_meta = "\xFF\x58\x04\x04\x02\x18\x08";

sub build_track {
    my ($notes_ref,$durs_ref,$ch,$program,$name) = @_;
    my ($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);
    my $track=vlq(0)."\xFF\x03".chr(length($name)).$name;
    $track.=vlq(0).chr($pc).chr($program);
    for my $i (0..$#$notes_ref) {
        my($m,$dur)=($notes_ref->[$i],$durs_ref->[$i]{ticks});
        $track.=vlq(0).chr($on).chr($m).chr(85);
        $track.=vlq($dur).chr($off).chr($m).chr(0);
    }
    $track.=vlq(0)."\xFF\x2F\x00";
    return $track;
}

my $tempo_track = vlq(0)."\xFF\x03\x05Tempo"
    .vlq(0).$timesig_meta
    .vlq(0)."\xFF\x51\x03"
    .chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF)
    .vlq(0)."\xFF\x2F\x00";

my $t_sop=build_track(\@s_notes,\@s_dur,0, 0,'Soprano - Grand Piano');
my $t_alt=build_track(\@a_notes,\@s_dur,1, 0,'Alto - Grand Piano');
my $t_ten=build_track(\@t_notes,\@b_dur,2, 0,'Tenor - Grand Piano');
my $t_bas=build_track(\@b_notes,\@b_dur,3,43,'Bajo - Contrabajo');

my $midi="MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for ($tempo_track,$t_sop,$t_alt,$t_ten,$t_bas);

my $out="$base/aprox9/prueba2/prueba2.mid";
open(my $fh_out,'>:raw',$out) or die $!;
print $fh_out $midi;
close $fh_out;

# =============================================================
# ESTADÍSTICAS
# =============================================================
my @NOTE_NAMES=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn{$NOTE_NAMES[$_[0]%12].int($_[0]/12-1)}
my @CONSONANT=(0,3,4,7,8,9);
sub is_consonant{my $i=($_[0]-$_[1])%12;scalar grep{$_==$i}@CONSONANT}

my ($same_s,$same_b)=(0,0);
for my $i (1..$#s_dur_ticks){
    $same_s++ if $s_dur_ticks[$i]==$s_dur_ticks[$i-1];
    $same_b++ if $b_dur_ticks[$i]==$b_dur_ticks[$i-1];
}
my $n=scalar @tetras;

my ($dis_ab,$dis_tb)=(0,0);
for my $i (0..$#a_notes){
    $dis_ab++ unless is_consonant($a_notes[$i],$b_notes[$i]);
    $dis_tb++ unless is_consonant($t_notes[$i],$b_notes[$i]);
}

my %dist_s; my %dist_b;
$dist_s{$_}++ for @s_dur_ticks;
$dist_b{$_}++ for @b_dur_ticks;

print "Generado: $out\n";
print "Compás: 4/4 | Tempo: 72 BPM | Tetranucleotidos: $n\n\n";

printf "Transiciones 1:1 — S: %d/%d (%.1f%%)  B: %d/%d (%.1f%%)\n",
    $same_s,$n-1,($n>1?100*$same_s/($n-1):0),
    $same_b,$n-1,($n>1?100*$same_b/($n-1):0);

printf "Disonancias A-B: %d/%d  |  T-B: %d/%d\n\n",$dis_ab,$n,$dis_tb,$n;

print "Distribución figuras (Soprano, 4/4):\n";
for my $f (sort{$a<=>$b} keys %dist_s){
    printf "  %-8s %d (%.1f%%)\n",$fig_names_44{$f},$dist_s{$f},100*$dist_s{$f}/$n;
}
print "\nDistribución figuras (Bajo, 4/4):\n";
for my $f (sort{$a<=>$b} keys %dist_b){
    printf "  %-8s %d (%.1f%%)\n",$fig_names_44{$f},$dist_b{$f},100*$dist_b{$f}/$n;
}

print "\nMuestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-4s  A:%-4s  T:%-4s  B:%-4s  dur:%dt\n",
    $tetras[$_],mn($s_notes[$_]),mn($a_notes[$_]),mn($t_notes[$_]),mn($b_notes[$_]),$s_dur_ticks[$_]
    for 0..7;
