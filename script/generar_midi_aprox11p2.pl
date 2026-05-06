#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# ================================================================
# aprox11/prueba2 - S arco (ap11) + inversion T/B (ap10) + compas 4/4
#
# VOZ S: melodia en arco (reglas aprox11 - igual que prueba1).
# INVERSION T/B (igual que aprox10):
#   T lleva mn_midi (ajustado a registro Tenor C3-G4).
#   B se genera algoritmicamente por debajo de T.
#   A se genera entre T y S (referencia armonica = T).
#   R7 aplicado a S-T en lugar de S-B.
# COMPAS 4/4: paleta {corchea, negra, blanca} + meta-evento 4/4.
# ================================================================

my %ni=(C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
        G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub vlq {
    my($v)=@_; return chr($v) if $v<128;
    my @b; push @b,$v&0x7F; $v>>=7;
    while($v>0){push @b,($v&0x7F)|0x80;$v>>=7;}
    join('',map{chr($_)}reverse @b)
}
sub midi_chunk { $_[0].pack('N',length($_[1])).$_[1] }

my @DMC=(0,2,4,5,7,9,10);  # D minor chroma

sub snap_dm {
    my($m)=@_; my $c=$m%12; my $base=$m-$c;
    my($bc,$bd)=($DMC[0],99);
    for my $x(@DMC){my $d=abs($c-$x);$d=12-$d if $d>6;if($d<$bd){$bd=$d;$bc=$x;}}
    my $n=$base+$bc; $n+=12 if($c-$bc)>6; $n-=12 if($bc-$c)>6; $n
}

sub force_reg {
    my($m,$ctr,$lo,$hi)=@_; my $c=$m%12;
    my($b,$bd)=($m,999);
    for my $o(0..9){my $n=$o*12+$c;next if $n<$lo||$n>$hi;my $d=abs($n-$ctr);if($d<$bd){$bd=$d;$b=$n;}}
    $b
}

sub vl {
    my($r,$ml,$lo,$hi)=@_; my @res=($r->[0]);
    for my $i(1..$#$r){
        my $p=$res[-1];my $c=$r->[$i];
        if(abs($c-$p)>$ml){my $a=($c>$p)?$c-12:$c+12;$c=$a if $a>=$lo&&$a<=$hi;}
        push @res,$c;
    }
    @res
}

sub dmr {
    my($lo,$hi)=@_; my @n;
    for my $o(0..9){push @n,$o*12+$_ for @DMC;}
    sort{$a<=>$b}grep{$_>=$lo&&$_<=$hi}@n
}

my @SS=dmr(62,86);  # Soprano D4-D6
my @AS=dmr(55,72);  # Alto G3-C5
my @TS=dmr(48,67);  # Tenor C3-G4
my @BS=dmr(38,62);   # Bass D2-D4
my $AC=62; my $TC=57; my $BC=50;

my %ALLOWED=(1=>1,2=>1,3=>1,4=>1,5=>1,7=>1,8=>1,9=>1,12=>1);

sub snap_sc {
    my($m,@sc)=@_; my($b,$bd)=($sc[0],999);
    for my $n(@sc){my $d=abs($n-$m);if($d<$bd){$bd=$d;$b=$n;}}
    $b
}

# ---------------------------------------------------------------
# MELODIA EN ARCO PARA S (aprox11)
# ---------------------------------------------------------------
sub gen_soprano_arch {
    my($tgt_ref,$sc_ref)=@_;
    my @tgt=@$tgt_ref; my @sc=@$sc_ref;
    my $N=scalar @tgt;
    return () unless $N;
    return (snap_sc($tgt[0],@sc)) if $N==1;

    # Climax position and note
    my $cpos=int($N*0.60+0.5);
    $cpos=2 if $cpos<2; $cpos=$N-3 if $cpos>$N-3;
    my $cidx=int(scalar(@sc)*0.75);
    $cidx=$#sc if $cidx>$#sc;
    my $climax=$sc[$cidx];

    my @mel=(snap_sc($tgt[0],@sc));
    my $prev=$mel[0];
    my($lc,$blc,$cls,$ldir,$lsz,$lwl,$cool,$cpl)=(0,0,0,0,0,0,0,0);

    my $upd=sub {
        my($note)=@_;
        my $iv=abs($note-$prev);
        my $dir=($note>$prev)?1:($note<$prev)?-1:0;
        if($iv>2){$lc++;$blc++ if $iv>5;$cls++;$lwl=1;$cool=3;}
        else{$cls=0;$lwl=0;$cool-- if $cool>0;}
        $ldir=$dir; $lsz=$iv; $prev=$note;
    };

    for my $i(1..$N-1) {
        # Force climax
        if($i==$cpos && !$cpl){
            my @reach=grep{my $iv=abs($_-$prev);$iv>0&&exists $ALLOWED{$iv}}@sc;
            my $placed=@reach?(sort{abs($a-$climax)<=>abs($b-$climax)}@reach)[0]
                             :snap_sc($climax,@sc);
            push @mel,$placed; $upd->($placed); $cpl=1; next;
        }

        my $phase=$cpl?-1:1;

        # Valid candidates
        my @cands=();
        for my $n(@sc){
            my $iv=abs($n-$prev);
            my $dir=($n>$prev)?1:($n<$prev)?-1:0;
            next if $iv==0||!exists $ALLOWED{$iv};
            next if !$cpl&&$n>$climax;
            next if  $cpl&&$n>=$climax;
            my $isl=($iv>2);
            next if $isl&&$lc>=4;
            next if $iv>5&&$blc>=2;
            next if $isl&&$cls>=2;
            next if $lwl&&$lsz>4&&$dir==$ldir;   # >M3: must change dir
            next if $lwl&&$isl&&$dir==$ldir;       # no 2 same-dir leaps
            push @cands,$n;
        }

        # Fallback: just arch constraint
        unless(@cands){
            @cands=grep{
                my $iv=abs($_-$prev);
                $iv>0&&exists $ALLOWED{$iv}&&(!$cpl?$_<=$climax:$_<$climax)
            }@sc;
        }
        unless(@cands){ push @mel,$prev; $upd->($prev); next; }

        # Score
        my $tgi=$tgt[$i];
        my($best,$bs)=(undef,1e9);
        for my $n(@cands){
            my $iv=abs($n-$prev);
            my $dir=($n>$prev)?1:-1;
            my $isl=($iv>2);
            my $s=0;
            if   ($iv<=2){$s+=0;}
            elsif($iv<=4){$s+=4;}
            elsif($iv==5){$s+=7;}
            else          {$s+=11;}
            $s-=5 if $dir==$phase;
            $s+=7 if $dir==-$phase;
            $s+=5 if $cool>0&&$isl;
            $s-=4 if $isl&&$lc<2&&$i>int($N*0.35);
            $s+=0.12*abs($n-$tgi);
            $s+=($climax-$n)*($i/$cpos)*0.08 unless $cpl;
            $s+=$n*0.05 if $cpl&&$i>int($N*0.9);
            if($s<$bs){$bs=$s;$best=$n;}
        }
        push @mel,$best; $upd->($best);
    }
    return @mel;
}

# ---------------------------------------------------------------
# WTC COST FUNCTIONS (A, T)
# ---------------------------------------------------------------
sub has_par {
    my($a,$b,$c,$d)=@_; return 0 unless defined $a&&defined $b;
    my $pi=($a-$b)%12; my $ci=($c-$d)%12;
    (($pi==7&&$ci==7)||($pi==0&&$ci==0))?1:0
}
sub chk_par_sb {
    my($ps,$pb,$s,$b)=@_; return $s unless defined $ps;
    my($pi,$ci)=(($ps-$pb)%12,($s-$b)%12);
    if(($pi==7&&$ci==7)||($pi==0&&$ci==0)){
        for my $i(0..$#SS-1){return $SS[$i+1] if $SS[$i]==$s;}
    }
    $s
}
sub wmc {
    my($p,$c)=@_; my $s=abs($c-$p);
    return 0 if $s<=2; return 4 if $s<=4;
    return 9 if $s<=5; return 15 if $s<=7; 24
}
sub whc {
    my($a,$b)=@_; my $i=abs($a-$b)%12;
    return 0 if $i==3||$i==4; return 1 if $i==8||$i==9;
    return 4 if $i==7; return 5 if $i==0; return 7 if $i==5;
    return 11 if $i==2||$i==10; return 16 if $i==1||$i==11;
    return 20 if $i==6; 6
}
sub lrc {
    my($pp,$p,$c)=@_; return 0 unless defined $pp;
    my($l1,$l2)=($p-$pp,$c-$p);
    if(abs($l1)>=5&&abs($l2)>=3){
        my $s1=$l1>0?1:($l1<0?-1:0); my $s2=$l2>0?1:($l2<0?-1:0);
        return 10 if $s1==$s2&&$s1!=0;
    }
    0
}
sub gen_alto {
    my($s,$b,$pa,$ppa,$sp,$bn,$bn2)=@_; $pa//=62;
    my($best,$bs)=(undef,1e9);
    for my $c(@AS){
        next if $c>=$s;
        my $sc=wmc($pa,$c)+2*whc($c,$b);
        $sc+=whc($c,$bn)      if defined $bn;
        $sc+=0.5*whc($c,$bn2) if defined $bn2;
        $sc+=lrc($ppa,$pa,$c);
        if(defined $sp){
            my $sd=($s>$sp)?1:($s<$sp)?-1:0;
            my $ad=($c>$pa)?1:($c<$pa)?-1:0;
            $sc-=5 if $sd!=0&&$ad!=0&&$sd!=$ad;
        }
        $sc+=20 if has_par($sp,$pa,$s,$c);
        $sc+=4  if ($s-$c)<3;
        $sc+=0.1*abs($c-$AC);
        if($sc<$bs){$bs=$sc;$best=$c;}
    }
    $best//$pa
}
# Alto: generated between T_data and S (aprox10 role swap)
sub gen_alto_ap10 {
    my($s,$t,$pa,$ppa,$sp,$tn,$tn2)=@_; $pa//=62;
    my($best,$bs)=(undef,1e9);
    for my $c(@AS){
        next if $c>=$s||$c<=$t;    # T < A < S
        my $sc=wmc($pa,$c)+2*whc($c,$t);
        $sc+=whc($c,$tn)      if defined $tn;
        $sc+=0.5*whc($c,$tn2) if defined $tn2;
        $sc+=lrc($ppa,$pa,$c);
        if(defined $sp){
            my $sd=($s>$sp)?1:($s<$sp)?-1:0;
            my $ad=($c>$pa)?1:($c<$pa)?-1:0;
            $sc-=5 if $sd!=0&&$ad!=0&&$sd!=$ad;
        }
        $sc+=20 if has_par($sp,$pa,$s,$c);
        $sc+=4  if ($s-$c)<3;
        $sc+=0.1*abs($c-$AC);
        if($sc<$bs){$bs=$sc;$best=$c;}
    }
    $best//$pa
}

# Bass: generated below T_data (aprox10 role swap)
sub gen_bass_ap10 {
    my($t,$a,$pb,$ppb,$tp,$tn,$tn2)=@_; $pb//=$BC;
    my($best,$bs)=(undef,1e9);
    for my $c(@BS){
        next if $c>=$t;    # B < T
        my $sc=wmc($pb,$c)+1.5*whc($c,$t)+0.5*whc($c,$a);
        $sc+=whc($c,$tn)      if defined $tn;
        $sc+=0.5*whc($c,$tn2) if defined $tn2;
        $sc+=lrc($ppb,$pb,$c);
        if(defined $tp){
            my $td=($t>$tp)?1:($t<$tp)?-1:0;
            my $bd=($c>$pb)?1:($c<$pb)?-1:0;
            $sc-=4 if $td!=0&&$bd!=0&&$td!=$bd;
        }
        $sc+=0.1*abs($c-$BC);
        if($sc<$bs){$bs=$sc;$best=$c;}
    }
    unless(defined $best){
        my $mid=int(($t+38)/2);
        ($best)=sort{abs($a-$mid)<=>abs($b-$mid)}grep{$_>=38&&$_<$t}@BS;
        $best//=38;
    }
    $best
}

# ---------------------------------------------------------------
# DATA LOADING
# ---------------------------------------------------------------
sub load_csv {
    my($p)=@_; my %m;
    open(my $f,'<:encoding(UTF-8)',$p) or die "Cannot open $p: $!";
    <$f>;
    while(<$f>){
        chomp; my @x=split(',',$_);
        $x[4]=~/^([A-G]#?)(\d)$/ and $m{$x[0]}=12*($2+1)+$ni{$1};
    }
    close $f; %m
}
sub load_dat {
    my($d)=@_; my %m;
    opendir(my $dh,$d) or die $!;
    while(my $f=readdir($dh)){
        next unless $f=~/\.dat$/i;
        my $c=do{local $/;open(my $fh,'<:encoding(UTF-8)',"$d/$f")or die $!;<$fh>};
        (my $k=$f)=~s/\.(MG|mg)\.dat$//i;
        $c=~/Tiempo de vida media: ([\d.]+)/ and $m{$k}=$1+0;
    }
    closedir $dh; %m
}
my %cp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rvc { join('',reverse map{$cp{$_}}split('',$_[0])) }
sub gtm {
    my($r,$t)=@_;
    return $r->{$t}     if exists $r->{$t};
    return $r->{rvc($t)} if exists $r->{rvc($t)};
    die "Not found: $t\n"
}
sub lmin { my $m=$_[0]; $m=$_<$m?$_:$m for @_; $m }
sub lmax { my $m=$_[0]; $m=$_>$m?$_:$m for @_; $m }
my @FIGS=(240,480,960); # 4/4 palette
sub ptl {
    my($ps,$mn,$mx)=@_;
    my $n=scalar @FIGS;
    my $idx=floor((log($ps)-log($mn))/(log($mx)-log($mn))*$n);
    $idx=0 if $idx<0; $idx=$n-1 if $idx>=$n;
    {ticks=>$FIGS[$idx]}
}

# ---------------------------------------------------------------
# PIPELINE
# ---------------------------------------------------------------
my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg  = load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn  = load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mgt = load_dat("$base/source/MUSIC.majorgroove");
my %mnt = load_dat("$base/source/MUSIC.minorgroove");
my($mgmn,$mgmx)=(lmin(values %mgt),lmax(values %mgt));
my($mnmn,$mnmx)=(lmin(values %mnt),lmax(values %mnt));

my $seq='GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC';
my @tetras;
for(my$i=0;$i+4<=length($seq);$i++){push@tetras,substr($seq,$i,4);}

my(@sr,@tr_raw,@sd,@td);
for my $t(@tetras){
    push @sr,     force_reg(snap_dm($mg{$t}),69,62,86);
    push @sd,     ptl(gtm(\%mgt,$t),$mgmn,$mgmx);
    push @tr_raw, force_reg(snap_dm($mn{$t}),57,48,67);  # T register
    push @td,     ptl(gtm(\%mnt,$t),$mnmn,$mnmx);
}

# S arch melody (aprox11 rules)
my @sarch = gen_soprano_arch(\@sr,\@SS);

# T from mn_midi data (T register), B will be generated fix
my @tvl = vl(\@tr_raw,7,48,67);

# R7 equivalent: anti-parallel S-T (T is now the data voice)
sub chk_par_st {
    my($ps,$pt,$s,$t)=@_; return $s unless defined $ps;
    my($pi,$ci)=(($ps-$pt)%12,($s-$t)%12);
    if(($pi==7&&$ci==7)||($pi==0&&$ci==0)){
        for my $i(0..$#SS-1){return $SS[$i+1] if $SS[$i]==$s;}
    }
    $s
}
for my $i(1..$#sarch){
    $sarch[$i]=chk_par_st($sarch[$i-1],$tvl[$i-1],$sarch[$i],$tvl[$i]);
}

# A between T and S; B generated below T
my(@an,@bn); my($pa,$pb)=(62,$BC); my($ppa,$ppb)=(undef,undef);
for my $i(0..$#tetras){
    my($s,$t)=($sarch[$i],$tvl[$i]);
    my $sp=$i>0?$sarch[$i-1]:undef;
    my $tp=$i>0?$tvl[$i-1]:undef;
    my $tn=$i<$#tetras?$tvl[$i+1]:undef;
    my $tn2=$i<$#tetras-1?$tvl[$i+2]:undef;
    my $a=gen_alto_ap10($s,$t,$pa,$ppa,$sp,$tn,$tn2);
    my $b=gen_bass_ap10($t,$a,$pb,$ppb,$tp,$tn,$tn2);
    push @an,$a; push @bn,$b;
    ($ppa,$ppb)=($pa,$pb); ($pa,$pb)=($a,$b);
}

# ---------------------------------------------------------------
# MIDI
# ---------------------------------------------------------------
my($ticks,$tempo)=(480,833333);  # 72 BPM

sub btrk {
    my($nr,$dr,$ch,$pg,$nm)=@_;
    my($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);
    my $t=vlq(0)."\xFF\x03".chr(length($nm)).$nm;
    $t.=vlq(0).chr($pc).chr($pg);
    for my $i(0..$#$nr){
        my($m,$d)=($nr->[$i],$dr->[$i]{ticks});
        $t.=vlq(0).chr($on).chr($m).chr(85);
        $t.=vlq($d).chr($off).chr($m).chr(0);
    }
    $t.=vlq(0)."\xFF\x2F\x00"; $t
}

my $tt=vlq(0)."\xFF\x03\x05Tempo"
      .vlq(0)."\xFF\x58\x04\x04\x02\x18\x08"
      .vlq(0)."\xFF\x51\x03"
      .chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF)
      .vlq(0)."\xFF\x2F\x00";

my $midi="MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for (
    $tt,
    btrk(\@sarch,\@sd,0, 0,'Soprano-arch'),
    btrk(\@an,   \@sd,1, 0,'Alto-Fix'),
    btrk(\@tvl,  \@td,2, 0,'Tenor-mn-dato'),
    btrk(\@bn,   \@td,3,43,'Bajo-Fix'),
);

my $out="$base/aprox11/prueba2/prueba2.mid";
open(my $fo,'>:raw',$out) or die "Cannot write $out: $!";
print $fo $midi; close $fo;

# ---------------------------------------------------------------
# STATISTICS
# ---------------------------------------------------------------
my @NN=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn2 { $NN[$_[0]%12].int($_[0]/12-1) }

my($leap_c,$big_c,$step_c)=(0,0,0);
for my $i(1..$#sarch){
    my $iv=abs($sarch[$i]-$sarch[$i-1]);
    if($iv<=2){$step_c++;}else{$leap_c++;$big_c++ if $iv>5;}
}
my(@CONSONANT)=(0,3,4,7,8,9);
sub isco{my $i=($_[0]-$_[1])%12;scalar grep{$_==$i}@CONSONANT}
my($dis_at,$dis_bt)=(0,0);
for my $i(0..$#an){
    $dis_at++ unless isco($an[$i],$tvl[$i]);
    $dis_bt++ unless isco($bn[$i],$tvl[$i]);
}
my $cn=$SS[int(scalar(@SS)*0.75)];
my $cp=int(scalar(@tetras)*0.60+0.5);
my($cmax,$cpf)=(0,-1);
for my $i(0..$#sarch){if($sarch[$i]>$cmax){$cmax=$sarch[$i];$cpf=$i;}}

my $N=scalar @tetras;
print "Generado: $out\n";
printf "Tetranucleotidos: %d | Tempo: 72 BPM\n",$N;
printf "Punto algido planificado: %s MIDI=%d pos=%d\n",mn2($cn),$cn,$cp;
printf "Nota mas alta generada:   %s MIDI=%d pos=%d\n",mn2($cmax),$cmax,$cpf;
printf "Roles: S=mg-arco  A=Fix  T=mn-dato  B=Fix  | Compas: 4/4\n";
printf "Saltos S totales: %d (esperado 2-4) | Saltos > P4: %d (max 2)\n",$leap_c,$big_c;
printf "Grado conjunto S: %d/%d (%.1f%%)\n",$step_c,$N-1,($N>1?100*$step_c/($N-1):0);
printf "Disonancias A-T: %d/%d | B-T: %d/%d\n",$dis_at,$N,$dis_bt,$N;
print "\nMuestra primeras 8 notas (SATB):\n";
printf "%-6s  S:%-5s  A:%-5s  T:%-5s  B:%-5s\n",
    $tetras[$_],mn2($sarch[$_]),mn2($an[$_]),mn2($tvl[$_]),mn2($bn[$_])
    for 0..7;
printf "\nNotas S alrededor del punto algido (pos %d):\n",$cp;
for my $i(($cp-2)..($cp+2)){
    printf "  pos %3d  S=%s\n",$i,mn2($sarch[$i]) if $i>=0 && $i<$N;
}
