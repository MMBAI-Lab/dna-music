#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(floor);

# aprox10/prueba2 — T=mn_dato, B=Fix, compas 4/4
# S=mg(dato) A=Fix T=mn(dato) B=Fix
# Conduccion WTC (aprox8). Duracion logaritmica directa.

my %note_idx=(C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,
              G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub vlq{my($v)=@_;return chr($v) if $v<128;my @b;push @b,$v&0x7F;$v>>=7;while($v>0){push @b,($v&0x7F)|0x80;$v>>=7;}join('',map{chr($_)}reverse @b)}
sub midi_chunk{$_[0].pack('N',length($_[1])).$_[1]}

my @DMC=(0,2,4,5,7,9,10);
sub snap_dm{my($m)=@_;my $c=$m%12;my $base=$m-$c;my($bc,$bd)=($DMC[0],99);for my $x(@DMC){my $d=abs($c-$x);$d=12-$d if $d>6;if($d<$bd){$bd=$d;$bc=$x;}}my $n=$base+$bc;$n+=12 if($c-$bc)>6;$n-=12 if($bc-$c)>6;$n}
sub force_reg{my($m,$ctr,$lo,$hi)=@_;my $c=$m%12;my($b,$bd)=($m,999);for my $o(0..9){my $n=$o*12+$c;next if $n<$lo||$n>$hi;my $d=abs($n-$ctr);if($d<$bd){$bd=$d;$b=$n;}}$b}
sub vl{my($r,$ml,$lo,$hi)=@_;my @res=($r->[0]);for my $i(1..$#$r){my $p=$res[-1];my $c=$r->[$i];if(abs($c-$p)>$ml){my $a=($c>$p)?$c-12:$c+12;$c=$a if $a>=$lo&&$a<=$hi;}push @res,$c;}@res}
sub dmr{my($lo,$hi)=@_;my @n;for my $o(0..9){push @n,$o*12+$_ for @DMC;}sort{$a<=>$b}grep{$_>=$lo&&$_<=$hi}@n}

my @SS=dmr(62,86);my @AS=dmr(55,72);my @BS=dmr(38,62);
my($AC,$BC)=(62,50);

sub has_par{my($v1p,$v2p,$v1c,$v2c)=@_;return 0 unless defined $v1p&&defined $v2p;my $pi=($v1p-$v2p)%12;my $ci=($v1c-$v2c)%12;(($pi==7&&$ci==7)||($pi==0&&$ci==0))?1:0}
sub chk_par_st{my($ps,$pt,$s,$t)=@_;return $s unless defined $ps;my($pi,$ci)=(($ps-$pt)%12,($s-$t)%12);if(($pi==7&&$ci==7)||($pi==0&&$ci==0)){for my $i(0..$#SS-1){return $SS[$i+1] if $SS[$i]==$s;}}$s}

sub wmc{my($p,$c)=@_;my $s=abs($c-$p);return 0 if $s<=2;return 4 if $s<=4;return 9 if $s<=5;return 15 if $s<=7;24}
sub whc{my($a,$b)=@_;my $i=abs($a-$b)%12;return 0 if $i==3||$i==4;return 1 if $i==8||$i==9;return 4 if $i==7;return 5 if $i==0;return 7 if $i==5;return 11 if $i==2||$i==10;return 16 if $i==1||$i==11;return 20 if $i==6;6}
sub lrc{my($pp,$p,$c)=@_;return 0 unless defined $pp;my($l1,$l2)=($p-$pp,$c-$p);if(abs($l1)>=5&&abs($l2)>=3){my $s1=$l1>0?1:($l1<0?-1:0);my $s2=$l2>0?1:($l2<0?-1:0);return 10 if $s1==$s2&&$s1!=0;}0}

sub gen_alto{
    my($s,$t,$pa,$ppa,$sp,$tn,$tn2)=@_;$pa//=62;
    my($best,$bs)=(undef,1e9);
    for my $c(@AS){
        next if $c>=$s||$c<=$t;
        my $score=wmc($pa,$c)+2*whc($c,$t);
        $score+=whc($c,$tn) if defined $tn;$score+=0.5*whc($c,$tn2) if defined $tn2;
        $score+=lrc($ppa,$pa,$c);
        if(defined $sp){my $sd=($s>$sp)?1:($s<$sp)?-1:0;my $ad=($c>$pa)?1:($c<$pa)?-1:0;$score-=5 if $sd!=0&&$ad!=0&&$sd!=$ad;}
        $score+=20 if has_par($sp,$pa,$s,$c);$score+=4 if($s-$c)<3;
        $score+=0.1*abs($c-$AC);
        if($score<$bs){$bs=$score;$best=$c;}
    }
    $best//$pa
}

sub gen_bass{
    my($t,$a,$pb,$ppb,$tp,$tn,$tn2)=@_;$pb//=50;
    my($best,$bs)=(undef,1e9);
    for my $c(@BS){
        next if $c>=$t;
        my $score=wmc($pb,$c)+1.5*whc($c,$t)+0.5*whc($c,$a);
        $score+=whc($c,$tn) if defined $tn;$score+=0.5*whc($c,$tn2) if defined $tn2;
        $score+=lrc($ppb,$pb,$c);
        if(defined $tp){my $td=($t>$tp)?1:($t<$tp)?-1:0;my $bd=($c>$pb)?1:($c<$pb)?-1:0;$score-=4 if $td!=0&&$bd!=0&&$td!=$bd;}
        $score+=0.1*abs($c-$BC);
        if($score<$bs){$bs=$score;$best=$c;}
    }
    unless(defined $best){my $mid=int(($t+38)/2);($best)=sort{abs($a-$mid)<=>abs($b-$mid)}grep{$_>=38&&$_<$t}@BS;$best//=38;}
    $best
}

sub load_csv{my($p)=@_;my %m;open(my $f,'<:encoding(UTF-8)',$p)or die $!;<$f>;while(<$f>){chomp;my @x=split(',',$_);$x[4]=~/^([A-G]#?)(\d)$/and$m{$x[0]}=12*($2+1)+$note_idx{$1};}close $f;%m}
sub load_dat{my($d)=@_;my %m;opendir(my $dh,$d)or die $!;while(my $f=readdir($dh)){next unless $f=~/\.dat$/i;my $c=do{local $/;open(my $fh,'<:encoding(UTF-8)',"$d/$f")or die $!;<$fh>};(my $k=$f)=~s/\.(MG|mg)\.dat$//i;$c=~/Tiempo de vida media: ([\d.]+)/and$m{$k}=$1+0;}closedir $dh;%m}
my %cp=(A=>'T',T=>'A',C=>'G',G=>'C');
sub rvc{join('',reverse map{$cp{$_}}split('',$_[0]))}
sub gtm{my($r,$t)=@_;return $r->{$t} if exists $r->{$t};return $r->{rvc($t)} if exists $r->{rvc($t)};die "No encontrado: $t\n"}
sub lmin{my $m=$_[0];$m=$_<$m?$_:$m for @_;$m}
sub lmax{my $m=$_[0];$m=$_>$m?$_:$m for @_;$m}
my @FIGS=(240,480,960); # 4/4 palette
sub ptl{my($ps,$mn,$mx)=@_;my $n=scalar @FIGS;my $idx=floor((log($ps)-log($mn))/(log($mx)-log($mn))*$n);$idx=0 if $idx<0;$idx=$n-1 if $idx>=$n;{ticks=>$FIGS[$idx]}}

my $base='e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %mg=load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %mn=load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %mgt=load_dat("$base/source/MUSIC.majorgroove");
my %mnt=load_dat("$base/source/MUSIC.minorgroove");
my($mgmn,$mgmx)=(lmin(values %mgt),lmax(values %mgt));
my($mnmn,$mnmx)=(lmin(values %mnt),lmax(values %mnt));

my $seq="GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";
my @tetras; for(my $i=0;$i+4<=length($seq);$i++){push @tetras,substr($seq,$i,4);}

my(@sr,@tr,@sd,@td);
for my $t(@tetras){
    push @sr,force_reg(snap_dm($mg{$t}),69,62,86);push @sd,ptl(gtm(\%mgt,$t),$mgmn,$mgmx);
    push @tr,force_reg(snap_dm($mn{$t}),57,48,67);push @td,ptl(gtm(\%mnt,$t),$mnmn,$mnmx);
}
my @sn=vl(\@sr,7,62,86);my @tn=vl(\@tr,7,48,67);
for my $i(1..$#sn){$sn[$i]=chk_par_st($sn[$i-1],$tn[$i-1],$sn[$i],$tn[$i]);}

my(@an,@bn);my($pa,$pb)=(62,50);my($ppa,$ppb)=(undef,undef);
for my $i(0..$#tetras){
    my($s,$t)=($sn[$i],$tn[$i]);
    my $sp=$i>0?$sn[$i-1]:undef;my $tp=$i>0?$tn[$i-1]:undef;
    my $tnx=$i<$#tetras?$tn[$i+1]:undef;my $tn2=$i<$#tetras-1?$tn[$i+2]:undef;
    my $a=gen_alto($s,$t,$pa,$ppa,$sp,$tnx,$tn2);
    my $b=gen_bass($t,$a,$pb,$ppb,$tp,$tnx,$tn2);
    push @an,$a;push @bn,$b;($ppa,$ppb)=($pa,$pb);($pa,$pb)=($a,$b);
}

my($ticks,$tempo)=(480,833333);
sub btrk{my($nr,$dr,$ch,$pg,$nm)=@_;my($on,$off,$pc)=(0x90|$ch,0x80|$ch,0xC0|$ch);my $t=vlq(0)."\xFF\x03".chr(length($nm)).$nm;$t.=vlq(0).chr($pc).chr($pg);for my $i(0..$#$nr){my($m,$d)=($nr->[$i],$dr->[$i]{ticks});$t.=vlq(0).chr($on).chr($m).chr(85);$t.=vlq($d).chr($off).chr($m).chr(0);}$t.=vlq(0)."\xFF\x2F\x00";$t}

my $tt=vlq(0)."\xFF\x03\x05Tempo".vlq(0)."\xFF\x58\x04\x04\x02\x18\x08".vlq(0)."\xFF\x51\x03".chr(($tempo>>16)&0xFF).chr(($tempo>>8)&0xFF).chr($tempo&0xFF).vlq(0)."\xFF\x2F\x00";
my $midi="MThd".pack('N',6).pack('n',1).pack('n',5).pack('n',$ticks);
$midi.=midi_chunk("MTrk",$_) for($tt,btrk(\@sn,\@sd,0,0,'Soprano-mg'),btrk(\@an,\@sd,1,0,'Alto-Fix'),btrk(\@tn,\@td,2,0,'Tenor-mn'),btrk(\@bn,\@td,3,43,'Bajo-Fix'));

my $out="$base/aprox10/prueba2/prueba2.mid";
open(my $fo,'>:raw',$out)or die $!;print $fo $midi;close $fo;

my @NN=('C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
sub mn2{$NN[$_[0]%12].int($_[0]/12-1)}
my @CO=(0,3,4,7,8,9);sub isco{my $i=($_[0]-$_[1])%12;scalar grep{$_==$i}@CO}
my($dat,$dbt)=(0,0);for my $i(0..$#an){$dat++ unless isco($an[$i],$tn[$i]);$dbt++ unless isco($bn[$i],$tn[$i]);}
my $n=scalar @tetras;
print "Generado: $out\n";
printf "Voces: S=mg-dato A=Fix T=mn-dato B=Fix | Tempo:72BPM | N:%d\n",$n;
printf "Disonancias A-T:%d/%d  B-T:%d/%d\n",$dat,$n,$dbt,$n;
print "Muestra 8:\n";printf "%-6s S:%-4s A:%-4s T:%-4s B:%-4s\n",$tetras[$_],mn2($sn[$_]),mn2($an[$_]),mn2($tn[$_]),mn2($bn[$_]) for 0..7;
