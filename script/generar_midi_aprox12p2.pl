#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# ================================================================
# aprox12/prueba1 — 3 voces triádicas
#
# Voces:
#   S (Ch 0) = surco mayor (dato, registro D4-D6)
#   T (Ch 2) = 3a nota calculada (tríada desde el bajo)
#   B (Ch 3) = surco menor (dato, registro D2-D4)
#   A silenciada — no se genera pista.
#
# Algoritmo findTriadThird:
#   Dado el bajo (B) y la soprano (S), encuentra la 3a nota que
#   completa una tríada mayor o menor:
#   - Busca entre 24 tríadas la que contiene el pc del bajo.
#   - Si también contiene el pc de la soprano (exacta): 3a = pc restante.
#   - Si no (aprox): tríada con pc del bajo que minimiza distancia a S.
#   - Octava: la que minimiza |3a - (B+S)/2|, rango D2-D6.
#   - Preferencia: fundamental > 2a inv. > 1a inv.
#
# Duraciones:
#   S → mg_ticks_log
#   T y B → mn_ticks_log (3a nota hereda figura del bajo)
#
# Instrumentos: Grand Piano (GM 0) para todas.
# ================================================================

my %note_idx=(C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
              G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);
my @NN=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');

sub vlq{my($v)=@_;return chr($v) if $v<128;my@b;push @b,$v&0x7F;$v>>=7;while($v>0){push @b,($v&0x7F)|0x80;$v>>=7;}join('',map{chr($_)}reverse @b)}
sub midi_chunk{$_[0].pack('N',length($_[1])).$_[1]}

my @DMC=(0,2,4,5,7,9,10);
sub snap_dm{my($m)=@_;my $c=$m%12;my $base=$m-$c;my($bc,$bd)=($DMC[0],99);for my $x(@DMC){my $d=abs($c-$x);$d=12-$d if $d>6;if($d<$bd){$bd=$d;$bc=$x;}}my $n=$base+$bc;$n+=12 if($c-$bc)>6;$n-=12 if($bc-$c)>6;$n}
sub force_reg{my($m,$ctr,$lo,$hi)=@_;my $c=$m%12;my($b,$bd)=($m,999);for my $o(0..9){my $n=$o*12+$c;next if $n<$lo||$n>$hi;my $d=abs($n-$ctr);if($d<$bd){$bd=$d;$b=$n;}}$b}
sub vl{my($r,$ml,$lo,$hi)=@_;my @res=($r->[0]);for my $i(1..$#$r){my $p=$res[-1];my $c=$r->[$i];if(abs($c-$p)>$ml){my $a=($c>$p)?$c-12:$c+12;$c=$a if $a>=$lo&&$a<=$hi;}push @res,$c;}@res}

# Build all 24 triads: [root, type(M/m), [pc0,pc1,pc2]]
my @TRIADS;
for my $r(0..11){
    push @TRIADS,{root=>$r,type=>'M',pcs=>[$r,($r+4)%12,($r+7)%12]};
    push @TRIADS,{root=>$r,type=>'m',pcs=>[$r,($r+3)%12,($r+7)%12]};
}

sub cdist{my($a,$b)=@_;my $d=abs($a-$b)%12;$d<12-$d?$d:12-$d}

sub find_triad_third {
    my($midi_low,$midi_high)=@_;
    my $pc_l=$midi_low%12; my $pc_h=$midi_high%12;
    my $mid=int(($midi_low+$midi_high)/2);

    my($best_pc,$best_score,$best_stab)=(-1,999,3);
    for my $t(@TRIADS){
        my @pcs=@{$t->{pcs}};
        my $has_l=grep{$_==$pc_l}@pcs; next unless $has_l;
        my $has_h=($pc_l!=$pc_h && grep{$_==$pc_h}@pcs);
        my $score=$has_h ? 0 : (sort{$a<=>$b}map{cdist($pc_h,$_)}@pcs)[0];
        my $stab=$t->{root}==$pc_l ? 0 : (($t->{root}+7)%12==$pc_l ? 1 : 2);
        # Third pc: not pc_l; if exact, also not pc_h
        my @others=grep{$_!=$pc_l}@pcs;
        my $third_pc;
        if($has_h){
            ($third_pc)=grep{$_!=$pc_h}@others;
            $third_pc//=$others[0];
        } else {
            # furthest from pc_h
            ($third_pc)=sort{cdist($pc_h,$b)<=>cdist($pc_h,$a)}@others;
        }
        if($score<$best_score || ($score==$best_score && $stab<$best_stab)){
            $best_score=$score; $best_stab=$stab; $best_pc=$third_pc;
        }
    }
    return $mid if $best_pc<0;

    # Best octave: closest to mid, range D2-D6
    my($best_m,$best_d)=($mid,9999);
    for my $o(0..9){
        my $c=$o*12+$best_pc;
        if($c>=38&&$c<=86){ my $d=abs($c-$mid); if($d<$best_d){$best_d=$d;$best_m=$c;} }
    }
    return $best_m;
}

# Load data
sub load_csv{my($p)=@_;my%m;open(my$f,'<:encoding(UTF-8)',$p)or die$!;<$f>;while(<$f>){chomp;my@x=split(',',$_);$x[4]=~/^([A-G]#?)(\d)$/and$m{$x[0]}=12*($2+1)+$note_idx{$1};}close$f;%m}
sub load_dat{my($d)=@_;my%m;opendir(my$dh,$d)or die$!;while(my$f=readdir($dh)){next unless$f=~/\.dat$/i;my$c=do{local $/;open(my$fh,'<:encoding(UTF-8)',"$d/$f")or die$!;<$fh>};(my$k=$f)=~s/\.(MG|mg)\.dat$//i;$c=~/Tiempo de vida media: ([\d.]+)/and$m{$k}=$1+0;}closedir$dh;%m}
my %cp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rvc{join('',reverse map{$cp{$_}}split('',$_[0]))}
sub gtm{my($r,$t)=@_;return$r->{$t} if exists$r->{$t};return$r->{rvc($t)} if exists$r->{rvc($t)};die"NF:$t\n"}
sub lmin{my$m=$_[0];$m=$_<$m?$_:$m for@_;$m}sub lmax{my$m=$_[0];$m=$_>$m?$_:$m for@_;$m}
my @FIGS=(240,480,960); # 4/4
sub ptl{my($ps,$mn,$mx)=@_;my$n=scalar@FIGS;my$idx=floor((log($ps)-log($mn))/(log($mx)-log($mn))*$n);$idx=0 if$idx<0;$idx=$n-1 if$idx>=$n;{ticks=>$FIGS[$idx]}}

my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg=load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn=load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mgt=load_dat("$base/source/MUSIC.majorgroove");
my %mnt=load_dat("$base/source/MUSIC.minorgroove");
my($mgmn,$mgmx)=(lmin(values%mgt),lmax(values%mgt));
my($mnmn,$mnmx)=(lmin(values%mnt),lmax(values%mnt));

my $seq='GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC';
my @tetras; for(my$i=0;$i+4<=length($seq);$i++){push@tetras,substr($seq,$i,4);}

my(@sr,@br,@sd,@bd);
for my $t(@tetras){
    push @sr,force_reg(snap_dm($mg{$t}),69,62,86); push @sd,ptl(gtm(\%mgt,$t),$mgmn,$mgmx);
    push @br,force_reg(snap_dm($mn{$t}),50,38,62); push @bd,ptl(gtm(\%mnt,$t),$mnmn,$mnmx);
}
my @sn=vl(\@sr,7,62,86);
my @bn=vl(\@br,7,38,62);

# Tenor = 3rd triad note
my @tn=map{find_triad_third($bn[$_],$sn[$_])}0..$#tetras;

# MIDI
my($ticks,$tempo)=(480,833333);
sub btrk{my($nr,$dr,$ch,$pg,$nm)=@_;my($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);my$t=vlq(0)."\xFF\x03".chr(length($nm)).$nm;$t.=vlq(0).chr($pc).chr($pg);for my$i(0..$#$nr){my($m,$d)=($nr->[$i],$dr->[$i]{ticks});$t.=vlq(0).chr($on).chr($m).chr(85);$t.=vlq($d).chr($off).chr($m).chr(0);}$t.=vlq(0)."\xFF\x2F\x00";$t}

my$tt=vlq(0)."\xFF\x03\x07Aprox12".vlq(0)."\xFF\x51\x03".chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF).vlq(0)."\xFF\x2F\x00";
my$midi="MThd".pack('N',6).pack('n',1).pack('n',4).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for(
    $tt,
    btrk(\@sn,\@sd,0,0,'Soprano-mg'),
    btrk(\@tn,\@bd,2,0,'Tenor-3rd'),
    btrk(\@bn,\@bd,3,0,'Bajo-mn'),
);

my$out="$base/aprox12/prueba2/prueba2.mid";
open(my$fo,'>:raw',$out)or die$!;print$fo$midi;close$fo;

sub mn2{$NN[$_[0]%12].int($_[0]/12-1)}
my $N=scalar@tetras;
print "Generado: $out\n";
printf "Tetranucleotidos: %d | Tempo: 72 BPM | Voces: S T B (A silenciada)\n",$N;
print "Muestra primeras 8 notas:\n";
printf "%-6s  S:%-5s  T:%-5s  B:%-5s\n",$tetras[$_],mn2($sn[$_]),mn2($tn[$_]),mn2($bn[$_]) for 0..7;
