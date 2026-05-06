#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# ================================================================
# aprox11/prueba3
# A y B en modo mayor SIN disonancias en el conjunto de 4 voces
#
# Base: aprox11 (A y B como melodias en arco)
#
# CAMBIOS vs prueba1/2:
#   1. A y B usan ESCALA DE RE MAYOR (D E F# G A B C#)
#      en lugar de Re menor.
#   2. Filtro de consonancia ESTRICTO:
#      - A debe ser consonante con T (obligatorio)
#        y consonante con S (obligatorio; si no hay candidato,
#        se relaja primero S, luego cualquier D mayor).
#      - B debe ser consonante con T y con A (obligatorio;
#        misma relajacion progresiva si no hay candidato).
#   3. S y T NO cambian (datos del surco mayor/menor).
#      A y B se adaptan para no producir disonancias adicionales.
#
# ESCALA D MAYOR: D E F# G A B C#
#   pc = {2, 4, 6, 7, 9, 11, 1}
#
# CONSONANCIAS: P1(0) m3(3) M3(4) P5(7) m6(8) M6(9) P8(12)
#
# REGLAS DE ARCO (igual que prueba1):
#   Intervalos: m2 M2 m3 M3 P4 P5 m6 M6 P8
#   Punto algido ~60%, percentil 80 de notas factibles.
#   Saltos 2-4; > P4 max 2; cambio de sentido tras > M3.
#
# COMPAS: libre (5 figuras).
# DURACION: normalizacion logaritmica.
# ================================================================

my %ni=(C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
        G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub vlq{my($v)=@_;return chr($v) if $v<128;my@b;push @b,$v&0x7F;$v>>=7;while($v>0){push @b,($v&0x7F)|0x80;$v>>=7;}join('',map{chr($_)}reverse @b)}
sub midi_chunk{$_[0].pack('N',length($_[1])).$_[1]}

# D minor (for S and T snapping)
my @DMC=(0,2,4,5,7,9,10);
# D major (for A and B)
my @DMJ=(0,2,4,6,7,9,11);

sub snap_dm{my($m)=@_;my $c=$m%12;my $base=$m-$c;my($bc,$bd)=($DMC[0],99);for my $x(@DMC){my $d=abs($c-$x);$d=12-$d if $d>6;if($d<$bd){$bd=$d;$bc=$x;}}my $n=$base+$bc;$n+=12 if($c-$bc)>6;$n-=12 if($bc-$c)>6;$n}
sub force_reg{my($m,$ctr,$lo,$hi)=@_;my $c=$m%12;my($b,$bd)=($m,999);for my $o(0..9){my $n=$o*12+$c;next if $n<$lo||$n>$hi;my $d=abs($n-$ctr);if($d<$bd){$bd=$d;$b=$n;}}$b}
sub vl{my($r,$ml,$lo,$hi)=@_;my @res=($r->[0]);for my $i(1..$#$r){my $p=$res[-1];my $c=$r->[$i];if(abs($c-$p)>$ml){my $a=($c>$p)?$c-12:$c+12;$c=$a if $a>=$lo&&$a<=$hi;}push @res,$c;}@res}

sub dmr{  # notes from given chroma in range
    my($lo,$hi,@chroma)=@_;my @n;
    for my $o(0..9){push @n,$o*12+$_ for @chroma;}
    sort{$a<=>$b}grep{$_>=$lo&&$_<=$hi}@n
}

my @SS  = dmr(62,86,@DMC);  # Soprano: D minor (data stays in D minor)
my @AS  = dmr(55,72,@DMJ);  # Alto:    D MAJOR
my @BS  = dmr(38,62,@DMJ);  # Bajo:    D MAJOR
my($AC,$BC)=(62,50);

# Anti-parallel S-T
sub chk_par_st{my($ps,$pt,$s,$t)=@_;return $s unless defined $ps;my($pi,$ci)=(($ps-$pt)%12,($s-$t)%12);if(($pi==7&&$ci==7)||($pi==0&&$ci==0)){for my $i(0..$#SS-1){return $SS[$i+1] if $SS[$i]==$s;}}$s}

# Consonances and WTC cost
my %CO_SET=(0=>1,3=>1,4=>1,7=>1,8=>1,9=>1,12=>1);
sub isco{my $i=abs($_[0]-$_[1])%12; exists $CO_SET{$i}}

sub whc{my($a,$b)=@_;my $i=abs($a-$b)%12;return 0 if $i==3||$i==4;return 1 if $i==8||$i==9;return 4 if $i==7;return 5 if $i==0;return 7 if $i==5;return 11 if $i==2||$i==10;return 16 if $i==1||$i==11;return 20 if $i==6;6}

my %ALLOWED=(1=>1,2=>1,3=>1,4=>1,5=>1,7=>1,8=>1,9=>1,12=>1);

# ================================================================
# ARCH VOICE GENERATOR — prueba3 variant
#
# Extra parameters:
#   cons_with_ref: true  -> candidates filtered to be consonant with ref
#   cons_with_aux: ref to array of 2nd consonance check (A notes for B)
# ================================================================
sub gen_arch_cons {
    my($upper_r,$lower_r,$ref_r,$above_r,$scale_r,$reg_center,$init,$cons_aux_r)=@_;
    my @upper=@$upper_r; my @lower=@$lower_r; my @ref=@$ref_r;
    my @above=@$above_r; my @sc=@$scale_r;
    my $N=scalar @upper;
    return () unless $N;

    my $cpos=int($N*0.60+0.5); $cpos=2 if $cpos<2; $cpos=$N-3 if $cpos>$N-3;
    my @feas=grep{$_>$lower[$cpos]&&$_<$upper[$cpos]}@sc;
    my $cidx=int(scalar(@feas)*0.80); $cidx=$#feas if $cidx>$#feas;
    my $climax=@feas?$feas[$cidx]:$sc[int(scalar(@sc)*0.75)];

    my @ini_feas=grep{$_>$lower[0]&&$_<$upper[0]}@sc;
    my $prev=@ini_feas?(sort{abs($a-$init)<=>abs($b-$init)}@ini_feas)[0]:$sc[0];
    my @mel=($prev);
    my($lc,$blc,$cls,$ldir,$lsz,$lwl,$cool,$cpl)=(0,0,0,0,0,0,0,0);

    my $upd=sub{
        my($note)=@_; my $iv=abs($note-$prev);
        my $dir=($note>$prev)?1:($note<$prev)?-1:0;
        if($iv>2){$lc++;$blc++ if $iv>5;$cls++;$lwl=1;$cool=3;}
        else{$cls=0;$lwl=0;$cool-- if $cool>0;}
        $ldir=$dir;$lsz=$iv;$prev=$note;
    };

    # Base filter: arch + interval rules (no consonance yet)
    my $base_filter=sub{
        my($n,$i)=@_;
        my $iv=abs($n-$prev); my $dir=($n>$prev)?1:($n<$prev)?-1:0;
        return 0 if $iv==0||!exists $ALLOWED{$iv};
        return 0 if $n<=$lower[$i]||$n>=$upper[$i];
        return 0 if !$cpl&&$n>$climax; return 0 if $cpl&&$n>=$climax;
        my $isl=($iv>2);
        return 0 if $isl&&$lc>=4; return 0 if $iv>5&&$blc>=2;
        return 0 if $isl&&$cls>=2;
        return 0 if $lwl&&$lsz>4&&$dir==$ldir;
        return 0 if $lwl&&$isl&&$dir==$ldir;
        1
    };

    for my $i(1..$N-1){
        if($i==$cpos&&!$cpl){
            my @reach=grep{$base_filter->($_,$i)}@sc;
            my $placed=@reach?(sort{abs($a-$climax)<=>abs($b-$climax)}@reach)[0]:($feas[0]//$prev);
            push @mel,$placed;$upd->($placed);$cpl=1;next;
        }
        my $phase=$cpl?-1:1;

        # Build candidate pool with progressive consonance relaxation:
        # Level 1: consonant with ref (T) AND aux (S or A) — strictest
        # Level 2: consonant with ref (T) only
        # Level 3: any arch-valid note in scale
        my $aux_note = defined $cons_aux_r ? $cons_aux_r->[$i] : undef;

        my @pool;
        for my $level(1,2,3){
            @pool=grep{
                my $n=$_;
                if(!$base_filter->($n,$i)){0}
                elsif($level==1){ isco($n,$ref[$i]) && (!defined $aux_note || isco($n,$aux_note)) }
                elsif($level==2){ isco($n,$ref[$i]) }
                else            { 1 }
            }@sc;
            last if @pool;
        }
        unless(@pool){push @mel,$prev;$upd->($prev);next;}

        my $rn =$i<$N-1?$ref[$i+1]:undef;
        my $rn2=$i<$N-2?$ref[$i+2]:undef;
        my $abv_p=$i>0?$above[$i-1]:undef;

        my($best,$bs)=(undef,1e9);
        for my $n(@pool){
            my $iv=abs($n-$prev); my $dir=($n>$prev)?1:-1; my $isl=($iv>2);
            my $s=0;
            if($iv<=2){$s+=0}elsif($iv<=4){$s+=4}elsif($iv==5){$s+=7}else{$s+=11}
            $s-=5 if $dir==$phase; $s+=7 if $dir==-$phase;
            $s+=5 if $cool>0&&$isl;
            $s-=4 if $isl&&$lc<2&&$i>int($N*0.35);

            # Harmonic cost: WTC cost with T (ref) + bonus for being consonant
            $s+=whc($n,$ref[$i])*1.5;
            $s+=whc($n,$rn)       if defined $rn;
            $s+=0.5*whc($n,$rn2)  if defined $rn2;

            # Also check consonance with S (via above array)
            $s+=whc($n,$above[$i])*0.8;

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

# ================================================================
# DATA LOADING
# ================================================================
sub load_csv{my($p)=@_;my%m;open(my$f,'<:encoding(UTF-8)',$p)or die$!;<$f>;while(<$f>){chomp;my@x=split(',',$_);$x[4]=~/^([A-G]#?)(\d)$/and$m{$x[0]}=12*($2+1)+$ni{$1};}close$f;%m}
sub load_dat{my($d)=@_;my%m;opendir(my$dh,$d)or die$!;while(my$f=readdir($dh)){next unless$f=~/\.dat$/i;my$c=do{local $/;open(my$fh,'<:encoding(UTF-8)',"$d/$f")or die$!;<$fh>};(my$k=$f)=~s/\.(MG|mg)\.dat$//i;$c=~/Tiempo de vida media: ([\d.]+)/and$m{$k}=$1+0;}closedir$dh;%m}
my %cp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rvc{join('',reverse map{$cp{$_}}split('',$_[0]))}
sub gtm{my($r,$t)=@_;return$r->{$t} if exists$r->{$t};return$r->{rvc($t)} if exists$r->{rvc($t)};die"NF:$t\n"}
sub lmin{my$m=$_[0];$m=$_<$m?$_:$m for@_;$m}sub lmax{my$m=$_[0];$m=$_>$m?$_:$m for@_;$m}
my @FIGS=(240,360,480,720,960);
sub ptl{my($ps,$mn,$mx)=@_;my$n=scalar@FIGS;my$idx=floor((log($ps)-log($mn))/(log($mx)-log($mn))*$n);$idx=0 if$idx<0;$idx=$n-1 if$idx>=$n;{ticks=>$FIGS[$idx]}}

# ================================================================
# PIPELINE
# ================================================================
my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg=load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn=load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mgt=load_dat("$base/source/MUSIC.majorgroove");
my %mnt=load_dat("$base/source/MUSIC.minorgroove");
my($mgmn,$mgmx)=(lmin(values%mgt),lmax(values%mgt));
my($mnmn,$mnmx)=(lmin(values%mnt),lmax(values%mnt));

my $seq='GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC';
my @tetras; for(my$i=0;$i+4<=length($seq);$i++){push@tetras,substr($seq,$i,4);}

# S (mg, D minor snap) and T (mn, D minor snap → T register)
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

# A: arch + consonant with T and S, D MAJOR scale, T < A < S
my @lbA=map{$tvl[$_]}0..$N-1;
my @ubA=map{$svl[$_]}0..$N-1;
my $initA=do{my@f=grep{$_>$lbA[0]&&$_<$ubA[0]&&isco($_,$tvl[0])}@AS;@f?(sort{abs($a-62)<=>abs($b-62)}@f)[0]:($AS[int($#AS*0.5)])};
# consonance aux for A = S notes (A must also be consonant with S)
my @an=gen_arch_cons(\@ubA,\@lbA,\@tvl,\@svl,\@AS,$AC,$initA,\@svl);

# B: arch + consonant with T and A, D MAJOR scale, B < T
my @lbB=(-1)x$N;
my @ubB=map{$tvl[$_]}0..$N-1;
my $initB=do{my@f=grep{$_<$ubB[0]&&isco($_,$tvl[0])&&isco($_,$an[0])}@BS;@f?(sort{abs($a-50)<=>abs($b-50)}@f)[0]:($BS[int($#BS*0.3)])};
# consonance aux for B = A notes
my @bn=gen_arch_cons(\@ubB,\@lbB,\@tvl,\@tvl,\@BS,$BC,$initB,\@an);

# ================================================================
# MIDI
# ================================================================
my($ticks,$tempo)=(480,833333);  # 72 BPM
sub btrk{my($nr,$dr,$ch,$pg,$nm)=@_;my($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);my$t=vlq(0)."\xFF\x03".chr(length($nm)).$nm;$t.=vlq(0).chr($pc).chr($pg);for my$i(0..$#$nr){my($m,$d)=($nr->[$i],$dr->[$i]{ticks});$t.=vlq(0).chr($on).chr($m).chr(85);$t.=vlq($d).chr($off).chr($m).chr(0);}$t.=vlq(0)."\xFF\x2F\x00";$t}

my$tt=vlq(0)."\xFF\x03\x05Tempo".vlq(0)."\xFF\x51\x03".chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF).vlq(0)."\xFF\x2F\x00";
my$midi="MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for($tt,
    btrk(\@svl,\@sd,0, 0,'Soprano-mg-Dm'),
    btrk(\@an, \@sd,1, 0,'Alto-arco-DM'),
    btrk(\@tvl,\@td,2, 0,'Tenor-mn-Dm'),
    btrk(\@bn, \@td,3,43,'Bajo-arco-DM'),
);

my$out="$base/aprox11/prueba3/prueba3.mid";
open(my$fo,'>:raw',$out)or die$!;print$fo$midi;close$fo;

# ================================================================
# STATISTICS
# ================================================================
my @NN=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn2{$NN[$_[0]%12].int($_[0]/12-1)}

# Dissonance counts for all voice pairs
my(%dis);
$dis{$_}=0 for qw(ST SA AT AB BT);
for my $i(0..$N-1){
    $dis{ST}++ unless isco($svl[$i],$tvl[$i]);
    $dis{SA}++ unless isco($svl[$i],$an[$i]);
    $dis{AT}++ unless isco($an[$i],$tvl[$i]);
    $dis{AB}++ unless isco($an[$i],$bn[$i]);
    $dis{BT}++ unless isco($bn[$i],$tvl[$i]);
}

# Leap stats
sub lp{my @m=@_;my($lc,$blc,$sc)=(0,0,0);for my $i(1..$#m){my $iv=abs($m[$i]-$m[$i-1]);$iv<=2?$sc++:($lc++,$blc++ if $iv>5);}($lc,$blc,$sc)}
my($alc,$ablc,$asc)=lp(@an);
my($blc_,$bblc,$bsc)=lp(@bn);

print "Generado: $out\n";
printf "Tetranucleotidos: %d | Tempo: 72 BPM\n",$N;
print "\n=== Disonancias entre voces ===\n";
printf "S-T: %3d/%d  S-A: %3d/%d  A-T: %3d/%d  A-B: %3d/%d  B-T: %3d/%d\n",
    $dis{ST},$N,$dis{SA},$N,$dis{AT},$N,$dis{AB},$N,$dis{BT},$N;
print "(S-T son datos; S-A, A-T, A-B, B-T son las disonancias que controlamos)\n";
printf "\n=== Alto (arco, Re mayor) ===\n";
printf "Saltos: %d (2-4) | > P4: %d (max 2) | Grado conj: %d/%d (%.1f%%)\n",
    $alc,$ablc,$asc,$N-1,($N>1?100*$asc/($N-1):0);
printf "\n=== Bajo (arco, Re mayor) ===\n";
printf "Saltos: %d (2-4) | > P4: %d (max 2) | Grado conj: %d/%d (%.1f%%)\n",
    $blc_,$bblc,$bsc,$N-1,($N>1?100*$bsc/($N-1):0);
print "\nMuestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-5s  A:%-5s  T:%-5s  B:%-5s\n",
    $tetras[$_],mn2($svl[$_]),mn2($an[$_]),mn2($tvl[$_]),mn2($bn[$_]) for 0..7;
