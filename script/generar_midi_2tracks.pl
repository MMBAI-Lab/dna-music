#!/usr/bin/perl
use strict;
use warnings;

# Chromatic index for note names
my %note_idx = (C=>0,'C#'=>1,D=>2,'D#'=>3,E=>4,F=>5,'F#'=>6,G=>7,'G#'=>8,A=>9,'A#'=>10,B=>11);

sub note_to_midi {
    my ($name) = @_;
    if ($name =~ /^([A-G]#?)(\d)$/) {
        return 12 * ($2 + 1) + $note_idx{$1};
    }
    die "Nota desconocida: $name\n";
}

# Variable-length quantity encoding (MIDI delta times)
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

# Load CSV mapping for a given groove
sub load_csv {
    my ($path) = @_;
    my %map;
    open(my $fh, '<:encoding(UTF-8)', $path) or die "No se puede abrir $path: $!";
    <$fh>; # skip header
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

# DNA sequence
my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

# Extract non-overlapping tetranucleotides
my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i += 4) {
    push @tetras, substr($seq, $i, 4);
}

# MIDI parameters
my $ticks  = 480;    # ticks per quarter note
my $tempo  = 500000; # microseconds/beat = 120 BPM
my $vel_on = 100;

# Build a note track for a given groove map and MIDI channel (0-based)
sub build_track {
    my ($groove_ref, $ch, $tetras_ref) = @_;
    my $note_on  = 0x90 | $ch;
    my $note_off = 0x80 | $ch;
    my $track = '';
    for my $tetra (@$tetras_ref) {
        my $note_name = $groove_ref->{$tetra} or die "Tetranucleotido no encontrado: $tetra\n";
        my $m = note_to_midi($note_name);
        $track .= vlq(0)      . chr($note_on)  . chr($m) . chr($vel_on);
        $track .= vlq($ticks) . chr($note_off) . chr($m) . chr(0);
    }
    $track .= vlq(0) . "\xFF\x2F\x00"; # end of track
    return $track;
}

# Track 0: tempo only
my $tempo_track = vlq(0) . "\xFF\x51\x03"
    . chr(($tempo >> 16) & 0xFF)
    . chr(($tempo >>  8) & 0xFF)
    . chr( $tempo        & 0xFF)
    . vlq(0) . "\xFF\x2F\x00";

my $track_major = build_track(\%major, 0, \@tetras);  # channel 1
my $track_minor = build_track(\%minor, 1, \@tetras);  # channel 2

# Assemble MIDI format 1 (3 tracks: tempo + major + minor)
sub midi_chunk {
    my ($tag, $data) = @_;
    return $tag . pack('N', length($data)) . $data;
}

my $midi = "MThd" . pack('N', 6) . pack('n', 1) . pack('n', 3) . pack('n', $ticks);
$midi .= midi_chunk("MTrk", $tempo_track);
$midi .= midi_chunk("MTrk", $track_major);
$midi .= midi_chunk("MTrk", $track_minor);

# Write output
my $out = "$base/aprox1/prueba2/prueba2.mid";
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Tetranucleotidos: " . scalar(@tetras) . "\n";
print "\nTetra        Major      Minor\n";
print "-" x 35 . "\n";
for my $t (@tetras) {
    printf "%-6s  ->  %-6s     %-6s\n", $t, $major{$t}, $minor{$t};
}
