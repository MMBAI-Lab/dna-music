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

# Map tiempo de vida media (ps) to ticks
# Negra = 480 ticks = 6 ps  →  80 ticks/ps
# Figures: corchea(3ps), corchea con punto(4.5ps), negra(6ps), negra con punto(9ps), blanca(12ps)
my @DURATION_MAP = (
    { ps => 3,  ticks => 240, name => 'corchea'           },
    { ps => 4.5,ticks => 360, name => 'corchea con punto' },
    { ps => 6,  ticks => 480, name => 'negra'             },
    { ps => 9,  ticks => 720, name => 'negra con punto'   },
    { ps => 12, ticks => 960, name => 'blanca'            },
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

# Load note mapping from CSV (ocupacion -> pitch)
sub load_csv {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>;
    while (<$fh>) {
        chomp;
        my @f = split(',', $_);
        $map{$f[0]} = $f[4];  # tetranucleotide -> note name
    }
    close $fh;
    return %map;
}

# Load tiempo de vida media from .dat files, keyed by canonical tetranucleotide
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

# Reverse complement
my %comp = (A=>'T', T=>'A', C=>'G', G=>'C');
sub rev_comp {
    my ($s) = @_;
    return join('', reverse map { $comp{$_} } split('', $s));
}

my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';

my %major_note  = load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %minor_note  = load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");
my %major_tiempo = load_dat_tiempo("$base/source/MUSIC.majorgroove");
my %minor_tiempo = load_dat_tiempo("$base/source/MUSIC.minorgroove");

# Resolve tiempo for any tetranucleotide (use canonical or rev_comp)
sub get_tiempo {
    my ($map_ref, $tetra) = @_;
    return $map_ref->{$tetra} if exists $map_ref->{$tetra};
    my $rc = rev_comp($tetra);
    return $map_ref->{$rc} if exists $map_ref->{$rc};
    die "Tetranucleotido no encontrado en datos: $tetra\n";
}

# DNA sequence
my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

# Overlapping tetranucleotides, step 1
my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i++) {
    push @tetras, substr($seq, $i, 4);
}

my $ticks_per_beat = 480;
my $tempo = 500000; # 120 BPM

# Build a track: each note uses its own duration from tiempo de vida media
sub build_track {
    my ($note_ref, $tiempo_ref, $ch, $tetras_ref) = @_;
    my $note_on  = 0x90 | $ch;
    my $note_off = 0x80 | $ch;
    my $track = '';
    my %fig_count;
    for my $tetra (@$tetras_ref) {
        my $note_name = $note_ref->{$tetra} or die "Nota no encontrada: $tetra\n";
        my $ps        = get_tiempo($tiempo_ref, $tetra);
        my $dur       = ps_to_ticks($ps);
        $fig_count{$dur->{name}}++;
        my $m = note_to_midi($note_name);
        $track .= vlq(0)            . chr($note_on)  . chr($m) . chr(100);
        $track .= vlq($dur->{ticks}). chr($note_off) . chr($m) . chr(0);
    }
    $track .= vlq(0) . "\xFF\x2F\x00";
    return ($track, %fig_count);
}

my $tempo_track = vlq(0) . "\xFF\x51\x03"
    . chr(($tempo >> 16) & 0xFF)
    . chr(($tempo >>  8) & 0xFF)
    . chr( $tempo        & 0xFF)
    . vlq(0) . "\xFF\x2F\x00";

my ($track_major, %fig_major) = build_track(\%major_note, \%major_tiempo, 0, \@tetras);
my ($track_minor, %fig_minor) = build_track(\%minor_note, \%minor_tiempo, 1, \@tetras);

sub midi_chunk {
    my ($tag, $data) = @_;
    return $tag . pack('N', length($data)) . $data;
}

my $midi = "MThd" . pack('N', 6) . pack('n', 1) . pack('n', 3) . pack('n', $ticks_per_beat);
$midi .= midi_chunk("MTrk", $tempo_track);
$midi .= midi_chunk("MTrk", $track_major);
$midi .= midi_chunk("MTrk", $track_minor);

my $out = "$base/aprox3/prueba1/prueba1.mid";
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Tetranucleotidos: " . scalar(@tetras) . "\n\n";

print "Distribución de figuras - Major groove:\n";
for my $fig (sort keys %fig_major) {
    printf "  %-22s %d notas\n", $fig, $fig_major{$fig};
}
print "\nDistribución de figuras - Minor groove:\n";
for my $fig (sort keys %fig_minor) {
    printf "  %-22s %d notas\n", $fig, $fig_minor{$fig};
}
