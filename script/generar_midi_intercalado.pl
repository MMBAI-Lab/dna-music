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

my $base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla';
my %major = load_csv("$base/data/notas_256_majorgroove_aprox1_2.csv");
my %minor = load_csv("$base/data/notas_256_minorgroove_aprox1_2.csv");

my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

# Overlapping tetranucleotides, step 1
my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i++) {
    push @tetras, substr($seq, $i, 4);
}

my $ticks  = 480;
my $tempo  = 500000; # 120 BPM

# Single track: interleave major[i], minor[i], major[i+1], minor[i+1], ...
my $note_on  = 0x90;  # channel 1
my $note_off = 0x80;

my $track = '';
for my $tetra (@tetras) {
    for my $groove_ref (\%major, \%minor) {
        my $note_name = $groove_ref->{$tetra} or die "Tetranucleotido no encontrado: $tetra\n";
        my $m = note_to_midi($note_name);
        $track .= vlq(0)      . chr($note_on)  . chr($m) . chr(100);
        $track .= vlq($ticks) . chr($note_off) . chr($m) . chr(0);
    }
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

my $midi = "MThd" . pack('N', 6) . pack('n', 1) . pack('n', 2) . pack('n', $ticks);
$midi .= midi_chunk("MTrk", $tempo_track);
$midi .= midi_chunk("MTrk", $track);

my $out = "$base/aprox2/prueba2/prueba2.mid";
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

my $total = scalar(@tetras) * 2;
print "Generado: $out\n";
print "Tetranucleotidos: " . scalar(@tetras) . " × 2 surcos = $total notas\n";
print "Duración aprox: " . int($total / 2 + 0.5) . " s a 120 BPM\n";
