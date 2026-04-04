#!/usr/bin/perl
use strict;
use warnings;

my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub note_to_midi {
    my ($name) = @_;
    if ($name =~ /^([A-G]#?)(\d)$/) {
        return 12 * ($2 + 1) + $note_idx{$1};
    }
    die "Nota desconocida: $name\n";
}

sub vlq {
    my ($val) = @_;
    return chr($val) if $val < 128;
    my @bytes;
    push @bytes, $val & 0x7F;
    $val >>= 7;
    while ($val > 0) {
        push @bytes, ($val & 0x7F) | 0x80;
        $val >>= 7;
    }
    return join('', map { chr($_) } reverse @bytes);
}

my @DURATION_MAP = (
    { ps => 3,   ticks => 240, name => 'corchea'           },
    { ps => 4.5, ticks => 360, name => 'corchea con punto' },
    { ps => 6,   ticks => 480, name => 'negra'             },
    { ps => 9,   ticks => 720, name => 'negra con punto'   },
    { ps => 12,  ticks => 960, name => 'blanca'            },
);

sub ps_to_ticks {
    my ($ps) = @_;
    my $best = $DURATION_MAP[0];
    my $best_diff = abs($ps - $DURATION_MAP[0]{ps});
    for my $d (@DURATION_MAP) {
        my $diff = abs($ps - $d->{ps});
        if ($diff < $best_diff) { $best_diff = $diff; $best = $d; }
    }
    return $best;
}

sub load_csv {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>;
    while (<$fh>) {
        chomp;
        my @f = split(',', $_);
        $map{$f[0]} = $f[4];
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
        my $path = "$dir/$f";
        my $content = do { local $/; open(my $fh, '<:encoding(UTF-8)', $path) or die $!; <$fh> };
        (my $key = $f) =~ s/\.(MG|mg)\.dat$//i;
        if ($content =~ /Tiempo de vida media: ([\d.]+)/) {
            $map{$key} = $1 + 0;
        }
    }
    closedir $dh;
    return %map;
}

my %comp = (A=>'T', T=>'A', C=>'G', G=>'C');
sub rev_comp {
    my ($s) = @_;
    return join('', reverse map { $comp{$_} } split('', $s));
}

sub get_tiempo {
    my ($map_ref, $tetra) = @_;
    return $map_ref->{$tetra} if exists $map_ref->{$tetra};
    my $rc = rev_comp($tetra);
    return $map_ref->{$rc} if exists $map_ref->{$rc};
    die "Tetranucleotido no encontrado: $tetra\n";
}

my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %major_note   = load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %minor_note   = load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %major_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %minor_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");

my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i++) {
    push @tetras, substr($seq, $i, 4);
}

my $ticks_per_beat = 480;
my $tempo = 500000; # 120 BPM

# Single track: chords — major and minor note simultaneously
# Duration = average of the two tiempos, mapped to nearest figure
my $track = '';
my %fig_count;

for my $tetra (@tetras) {
    my $m_note = note_to_midi($major_note{$tetra} or die "Major nota no encontrada: $tetra\n");
    my $n_note = note_to_midi($minor_note{$tetra} or die "Minor nota no encontrada: $tetra\n");
    my $ps_maj = get_tiempo(\%major_tiempo, $tetra);
    my $ps_min = get_tiempo(\%minor_tiempo, $tetra);
    my $ps_avg = ($ps_maj + $ps_min) / 2;
    my $dur    = ps_to_ticks($ps_avg);
    $fig_count{$dur->{name}}++;

    # Both note_on at delta=0
    $track .= vlq(0) . chr(0x90) . chr($m_note) . chr(100);  # major, ch1
    $track .= vlq(0) . chr(0x91) . chr($n_note) . chr(100);  # minor, ch2
    # Both note_off after duration
    $track .= vlq($dur->{ticks}) . chr(0x80) . chr($m_note) . chr(0);
    $track .= vlq(0)             . chr(0x81) . chr($n_note) . chr(0);
}
$track .= vlq(0) . "\xFF\x2F\x00";

my $tempo_track = vlq(0) . "\xFF\x51\x03"
    . chr(($tempo >> 16) & 0xFF)
    . chr(($tempo >>  8) & 0xFF)
    . chr( $tempo        & 0xFF)
    . vlq(0) . "\xFF\x2F\x00";

sub midi_chunk {
    my ($tag, $data) = @_;
    return $tag . pack('N', length($data)) . $data;
}

my $midi = "MThd" . pack('N', 6) . pack('n', 1) . pack('n', 2) . pack('n', $ticks_per_beat);
$midi .= midi_chunk("MTrk", $tempo_track);
$midi .= midi_chunk("MTrk", $track);

my $out = "$base/aprox3/prueba2/prueba2.mid";
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Tetranucleotidos: " . scalar(@tetras) . "\n\n";
print "Distribución de figuras (duración promedio de ambos surcos):\n";
for my $fig (map { $_->{name} } @DURATION_MAP) {
    printf "  %-22s %d notas\n", $fig, ($fig_count{$fig} // 0);
}
