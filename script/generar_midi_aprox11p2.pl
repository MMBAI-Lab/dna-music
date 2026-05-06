#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# ================================================================
# aprox11/prueba2
# Voces internas A y B como melodias en arco — textura bachiana
#
# Asignacion de voces (igual que aprox10):
#   S = surco mayor (dato, registro D4-D6)
#   A = Fix con arco (reglas ap11, entre T y S)
#   T = surco menor (dato, registro C3-G4)
#   B = Fix con arco (reglas ap11, por debajo de T)
#
# Intervalos permitidos (A y B):
#   m2(1) M2(2) m3(3) M3(4) P4(5) P5(7) m6(8) M6(9) P8(12)
#
# Reglas de arco (A y B coordinados al ~60%):
#   Punto algido: percentil 80 de notas factibles en climaxPos.
#   Saltos 2-4 totales; saltos > P4 max 2.
#   Tras salto > M3: cambio de sentido obligatorio (pref. grado).
#   Tras 3ra: puede continuar mismo sentido.
#   Sin 2 saltos consecutivos misma direccion; max 2 consecutivos.
#
# Puntuacion: coste de intervalo + fase + WTC armonico (con T) +
#             movimiento contrario + atraccion al centro.
#
# DURACION: normalizacion logaritmica (5 figuras).
# ================================================================

my %ni=(C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
        G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub vlq{my($v)=@_;return chr($v) if $v<128;my@b;push @b,$v&0x7F;$v>>=7;while($v>0){push @b,($v&0x7F)|0x80;$v>>=7;}join('',map{chr($_)}reverse @b)}
sub midi_chunk{$_[0].pack('N',length($_[1])).$_[1]}

my @DMC=(0,2,4,5,7,9,10);
sub snap_dm{my($m)=@_;my $c=$m%12;my $base=$m-$c;my($bc,$bd)=($DMC[0],99);for my $x(@DMC){my $d=abs($c-$x);$d=12-$d if $d>6;if($d<$bd){$bd=$d;$bc=$x;}}my $n=$base+$bc;$n+=12 if($c-$bc)>6;$n-=12 if($bc-$c)>6;$n}
sub force_reg{my($m,$ctr,$lo,$hi)=@_;my $c=$m%12;my($b,$bd)=($m,999);for my $o(0..9){my $n=$o*12+$c;next if $n<$lo||$n>$hi;my $d=abs($n-$ctr);if($d<$bd){$bd=$d;$b=$n;}}$b}
sub vl{my($r,$ml,$lo,$hi)=@_;my @res=($r->[0]);for my $i(1..$#$r){my $p=$res[-1];my $c=$r->[$i];if(abs($c-$p)>$ml){my $a=($c>$p)?$c-12:$c+12;$c=$a if $a>=$lo&&$a<=$hi;}push @res,$c;}@res}
sub dmr{my($lo,$hi)=@_;my @n;for my $o(0..9){push @n,$o*12+$_ for @DMC;}sort{$a<=>$b}grep{$_>=$lo&&$_<=$hi}@n}

my @SS=dmr(62,86); my @AS=dmr(55,72); my @BS=dmr(38,62);
my($AC,$BC)=(62,50);

# Anti-parallel S-T check (R7 adapted for S-T pair)
sub chk_par_st{my($ps,$pt,$s,$t)=@_;return $s unless defined $ps;my($pi,$ci)=(($ps-$pt)%12,($s-$t)%12);if(($pi==7&&$ci==7)||($pi==0&&$ci==0)){for my $i(0..$#SS-1){return $SS[$i+1] if $SS[$i]==$s;}}$s}

# WTC harmonic cost
sub whc{my($a,$b)=@_;my $i=abs($a-$b)%12;return 0 if $i==3||$i==4;return 1 if $i==8||$i==9;return 4 if $i==7;return 5 if $i==0;return 7 if $i==5;return 11 if $i==2||$i==10;return 16 if $i==1||$i==11;return 20 if $i==6;6}

my %ALLOWED=(1=>1,2=>1,3=>1,4=>1,5=>1,7=>1,8=>1,9=>1,12=>1);

# =============================================================
# ARCH VOICE GENERATOR (A or B)
#
# upper_ref: arrayref — voice must stay strictly below this at each step
# lower_ref: arrayref — voice must stay strictly above this at each step
#            (use [(-1) x N] for no lower bound)
# ref_ref:   arrayref — T notes for harmonic cost
# above_ref: arrayref — voice above for contrary motion bonus
# scale_ref: arrayref — available notes in register
# reg_center: register center MIDI value
# init_note:  starting note
# =============================================================
sub gen_arch_voice {
    my($upper_ref,$lower_ref,$ref_ref,$above_ref,$scale_ref,$reg_center,$init_note)=@_;
    my @upper  = @$upper_ref;
    my @lower  = @$lower_ref;
    my @refv   = @$ref_ref;
    my @above  = @$above_ref;
    my @sc     = @$scale_ref;
    my $N      = scalar @upper;
    return () unless $N;

    # Climax position (~60%) and note (80th percentile of feasible notes there)
    my $cpos = int($N*0.60+0.5); $cpos=2 if $cpos<2; $cpos=$N-3 if $cpos>$N-3;
    my @feas = grep { $_>$lower[$cpos] && $_<$upper[$cpos] } @sc;
    my $cidx = int(scalar(@feas)*0.80); $cidx=$#feas if $cidx>$#feas;
    my $climax = @feas ? $feas[$cidx] : $sc[int(scalar(@sc)*0.75)];

    # Snap initial note to feasible range
    my @ini_feas = grep { $_>$lower[0] && $_<$upper[0] } @sc;
    my $prev = @ini_feas
        ? (sort{abs($a-$init_note)<=>abs($b-$init_note)}@ini_feas)[0]
        : $sc[0];

    my @mel=($prev);
    my($lc,$blc,$cls,$ldir,$lsz,$lwl,$cool,$cpl)=(0,0,0,0,0,0,0,0);

    my $upd=sub{
        my($note)=@_; my $iv=abs($note-$prev);
        my $dir=($note>$prev)?1:($note<$prev)?-1:0;
        if($iv>2){$lc++;$blc++ if $iv>5;$cls++;$lwl=1;$cool=3;}
        else{$cls=0;$lwl=0;$cool-- if $cool>0;}
        $ldir=$dir;$lsz=$iv;$prev=$note;
    };

    for my $i(1..$N-1){
        # Force climax
        if($i==$cpos&&!$cpl){
            my @reach=grep{my $iv=abs($_-$prev);$iv>0&&exists $ALLOWED{$iv}&&$_>$lower[$i]&&$_<$upper[$i]}@sc;
            my $placed=@reach?(sort{abs($a-$climax)<=>abs($b-$climax)}@reach)[0]:($feas[0]//$prev);
            push @mel,$placed;$upd->($placed);$cpl=1;next;
        }
        my $phase=$cpl?-1:1;

        # Valid candidates
        my @cands=();
        for my $n(@sc){
            my $iv=abs($n-$prev);
            my $dir=($n>$prev)?1:($n<$prev)?-1:0;
            next if $iv==0||!exists $ALLOWED{$iv};
            next if $n<=$lower[$i]||$n>=$upper[$i];
            next if !$cpl&&$n>$climax; next if $cpl&&$n>=$climax;
            my $isl=($iv>2);
            next if $isl&&$lc>=4; next if $iv>5&&$blc>=2; next if $isl&&$cls>=2;
            next if $lwl&&$lsz>4&&$dir==$ldir;
            next if $lwl&&$isl&&$dir==$ldir;
            push @cands,$n;
        }
        unless(@cands){
            @cands=grep{my $iv=abs($_-$prev);$iv>0&&exists $ALLOWED{$iv}&&$_>$lower[$i]&&$_<$upper[$i]&&(!$cpl?$_<=$climax:$_<$climax)}@sc;
        }
        unless(@cands){push @mel,$prev;$upd->($prev);next;}

        my $rn  = $i<$N-1 ? $refv[$i+1] : undef;
        my $rn2 = $i<$N-2 ? $refv[$i+2] : undef;
        my $abv_p = $i>0 ? $above[$i-1] : undef;

        my($best,$bs)=(undef,1e9);
        for my $n(@cands){
            my $iv=abs($n-$prev); my $dir=($n>$prev)?1:-1; my $isl=($iv>2);
            my $s=0;
            if   ($iv<=2){$s+=0;}elsif($iv<=4){$s+=4;}elsif($iv==5){$s+=7;}else{$s+=11;}
            $s-=5 if $dir==$phase; $s+=7 if $dir==-$phase;
            $s+=5 if $cool>0&&$isl;
            $s-=4 if $isl&&$lc<2&&$i>int($N*0.35);
            $s+=1.5*whc($n,$refv[$i]);
            $s+=whc($n,$rn)       if defined $rn;
            $s+=0.5*whc($n,$rn2)  if defined $rn2;
            # Contrary motion vs voice above
            if(defined $abv_p){
                my $abd=($above[$i]>$abv_p)?1:($above[$i]<$abv_p)?-1:0;
                $s-=4 if $abd!=0&&$dir!=0&&$abd!=$dir;
            }
            $s+=0.07*abs($n-$reg_center);
            $s+=($climax-$n)*($i/$cpos)*0.06 unless $cpl;
            $s+=$n*0.04 if $cpl&&$i>int($N*0.9);
            if($s<$bs){$bs=$s;$best=$n;}
        }
        push @mel,$best;$upd->($best);
    }
    return @mel;
}

# =============================================================
# DATA LOADING
# =============================================================
sub load_csv{my($p)=@_;my%m;open(my$f,'<:encoding(UTF-8)',$p)or die$!;<$f>;while(<$f>){chomp;my@x=split(',',$_);$x[4]=~/^([A-G]#?)(\d)$/and$m{$x[0]}=12*($2+1)+$ni{$1};}close$f;%m}
sub load_dat{my($d)=@_;my%m;opendir(my$dh,$d)or die$!;while(my$f=readdir($dh)){next unless$f=~/\.dat$/i;my$c=do{local $/;open(my$fh,'<:encoding(UTF-8)',"$d/$f")or die$!;<$fh>};(my$k=$f)=~s/\.(MG|mg)\.dat$//i;$c=~/Tiempo de vida media: ([\d.]+)/and$m{$k}=$1+0;}closedir$dh;%m}
my %cp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rvc{join('',reverse map{$cp{$_}}split('',$_[0]))}
sub gtm{my($r,$t)=@_;return$r->{$t} if exists$r->{$t};return$r->{rvc($t)} if exists$r->{rvc($t)};die"NF:$t\n"}
sub lmin{my$m=$_[0];$m=$_<$m?$_:$m for@_;$m}sub lmax{my$m=$_[0];$m=$_>$m?$_:$m for@_;$m}
my @FIGS=(240,480,960); # 4/4 palette
sub ptl{my($ps,$mn,$mx)=@_;my$n=scalar@FIGS;my$idx=floor((log($ps)-log($mn))/(log($mx)-log($mn))*$n);$idx=0 if$idx<0;$idx=$n-1 if$idx>=$n;{ticks=>$FIGS[$idx]}}

# =============================================================
# PIPELINE
# =============================================================
my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg=load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn=load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mgt=load_dat("$base/source/MUSIC.majorgroove");
my %mnt=load_dat("$base/source/MUSIC.minorgroove");
my($mgmn,$mgmx)=(lmin(values%mgt),lmax(values%mgt));
my($mnmn,$mnmx)=(lmin(values%mnt),lmax(values%mnt));

my $seq='GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC';
my @tetras; for(my$i=0;$i+4<=length($seq);$i++){push@tetras,substr($seq,$i,4);}

# S (mg data, S register) and T (mn data, T register)
my(@sr,@tr,@sd,@td);
for my $t(@tetras){
    push @sr,force_reg(snap_dm($mg{$t}),69,62,86); push @sd,ptl(gtm(\%mgt,$t),$mgmn,$mgmx);
    push @tr,force_reg(snap_dm($mn{$t}),57,48,67); push @td,ptl(gtm(\%mnt,$t),$mnmn,$mnmx);
}
my @svl=vl(\@sr,7,62,86);
my @tvl=vl(\@tr,7,48,67);

# R7 adapted to S-T pair
for my $i(1..$#svl){$svl[$i]=chk_par_st($svl[$i-1],$tvl[$i-1],$svl[$i],$tvl[$i]);}

my $N=scalar@tetras;

# A: arch fix, T < A < S
my @lbA=map{$tvl[$_]}0..$N-1;      # lower bound for A = T notes
my @ubA=map{$svl[$_]}0..$N-1;      # upper bound for A = S notes
my $initA=do{ my @f=grep{$_>$lbA[0]&&$_<$ubA[0]}@AS; @f?(sort{abs($a-62)<=>abs($b-62)}@f)[0]:62; };
my @an=gen_arch_voice(\@ubA,\@lbA,\@tvl,\@svl,\@AS,$AC,$initA);

# B: arch fix, B < T
my @lbB=(-1)x$N;                   # no effective lower bound (B register handles it)
my @ubB=map{$tvl[$_]}0..$N-1;      # upper bound for B = T notes
my $initB=do{ my @f=grep{$_>0&&$_<$ubB[0]}@BS; @f?(sort{abs($a-50)<=>abs($b-50)}@f)[0]:50; };
my @bn=gen_arch_voice(\@ubB,\@lbB,\@tvl,\@tvl,\@BS,$BC,$initB);

# =============================================================
# MIDI
# =============================================================
my($ticks,$tempo)=(480,833333);  # 72 BPM
sub btrk{my($nr,$dr,$ch,$pg,$nm)=@_;my($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);my$t=vlq(0)."\xFF\x03".chr(length($nm)).$nm;$t.=vlq(0).chr($pc).chr($pg);for my$i(0..$#$nr){my($m,$d)=($nr->[$i],$dr->[$i]{ticks});$t.=vlq(0).chr($on).chr($m).chr(85);$t.=vlq($d).chr($off).chr($m).chr(0);}$t.=vlq(0)."\xFF\x2F\x00";$t}

my$tt=vlq(0)."\xFF\x03\x05Tempo".vlq(0)."\xFF\x58\x04\x04\x02\x18\x08".vlq(0)."\xFF\x51\x03".chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF).vlq(0)."\xFF\x2F\x00";
my$midi="MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for($tt,
    btrk(\@svl,\@sd,0, 0,'Soprano-mg'),
    btrk(\@an, \@sd,1, 0,'Alto-arco'),
    btrk(\@tvl,\@td,2, 0,'Tenor-mn'),
    btrk(\@bn, \@td,3,43,'Bajo-arco'),
);

my$out="$base/aprox11/prueba2/prueba2.mid";
open(my$fo,'>:raw',$out)or die$!;print$fo$midi;close$fo;

# =============================================================
# STATISTICS
# =============================================================
my @NN=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn2{$NN[$_[0]%12].int($_[0]/12-1)}

sub leap_stats {
    my @m=@_; my($lc,$blc,$sc)=(0,0,0);
    for my $i(1..$#m){my $iv=abs($m[$i]-$m[$i-1]);if($iv<=2){$sc++;}else{$lc++;$blc++ if $iv>5;}}
    return($lc,$blc,$sc);
}
my($alc,$ablc,$asc)=leap_stats(@an);
my($blc_,$bblc,$bsc_)=leap_stats(@bn);

my @CO=(0,3,4,7,8,9);sub isco{my $i=($_[0]-$_[1])%12;scalar grep{$_==$i}@CO}
my($dis_at,$dis_bt)=(0,0);
for my $i(0..$#an){$dis_at++ unless isco($an[$i],$tvl[$i]);$dis_bt++ unless isco($bn[$i],$tvl[$i]);}

# Find climax positions
my $cpos=int($N*0.60+0.5);
my($amx,$apf,$bmx,$bpf)=(0,-1,0,-1);
for my $i(0..$#an){if($an[$i]>$amx){$amx=$an[$i];$apf=$i;}}
for my $i(0..$#bn){if($bn[$i]>$bmx){$bmx=$bn[$i];$bpf=$i;}}

print "Generado: $out\n";
printf "Tetranucleotidos: %d | Tempo: 72 BPM | Compas: libre\n",$N;
printf "\n=== ALTO (arco ap11) ===\n";
printf "Nota mas alta: %s (pos %d) | Climax planificado en pos %d\n",mn2($amx),$apf,$cpos;
printf "Saltos: %d (2-4) | Saltos > P4: %d (max 2) | Grado conj: %d/%d (%.1f%%)\n",$alc,$ablc,$asc,$N-1,($N>1?100*$asc/($N-1):0);
printf "Disonancias A-T: %d/%d\n",$dis_at,$N;
printf "\n=== BAJO (arco ap11) ===\n";
printf "Nota mas alta: %s (pos %d)\n",mn2($bmx),$bpf;
printf "Saltos: %d (2-4) | Saltos > P4: %d (max 2) | Grado conj: %d/%d (%.1f%%)\n",$blc_,$bblc,$bsc_,$N-1,($N>1?100*$bsc_/($N-1):0);
printf "Disonancias B-T: %d/%d\n",$dis_bt,$N;
print "\nMuestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-5s  A:%-5s  T:%-5s  B:%-5s\n",$tetras[$_],mn2($svl[$_]),mn2($an[$_]),mn2($tvl[$_]),mn2($bn[$_]) for 0..7;
