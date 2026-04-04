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

# Load CSV mapping
my %tetra_note;
my $csv = 'e:/Documentos/2026/PROYECTO - ABC musica Molla/data/notas_256_majorgroove_aprox1_2.csv';
open(my $fh, '<:encoding(UTF-8)', $csv) or die "No se puede abrir $csv: $!";
<$fh>; # skip header
while (<$fh>) {
    chomp;
    my @f = split(',', $_);
    $tetra_note{$f[0]} = $f[4];
}
close $fh;

# DNA sequence
my $seq = "GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGGCGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAATGTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAGAGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC";

# Extract non-overlapping tetranucleotides and map to MIDI notes
my @midi_notes;
my @tetras;
for (my $i = 0; $i + 4 <= length($seq); $i += 4) {
    my $tetra = substr($seq, $i, 4);
    push @tetras, $tetra;
    if (exists $tetra_note{$tetra}) {
        push @midi_notes, { midi => note_to_midi($tetra_note{$tetra}), note => $tetra_note{$tetra}, tetra => $tetra };
    } else {
        warn "Tetranucleotido no encontrado: $tetra\n";
    }
}

# MIDI parameters
my $ticks   = 480;    # ticks per quarter note
my $tempo   = 500000; # microseconds/beat = 120 BPM
my $vel_on  = 100;
my $channel = 0x90;   # channel 1, note on
my $ch_off  = 0x80;   # channel 1, note off

# Build track data
my $track = '';

# Set tempo (delta=0)
$track .= vlq(0) . "\xFF\x51\x03"
        . chr(($tempo >> 16) & 0xFF)
        . chr(($tempo >>  8) & 0xFF)
        . chr( $tempo        & 0xFF);

# One quarter note per tetranucleotide
for my $n (@midi_notes) {
    my $m = $n->{midi};
    $track .= vlq(0)      . chr($channel) . chr($m) . chr($vel_on); # note on
    $track .= vlq($ticks) . chr($ch_off)  . chr($m) . chr(0);       # note off
}

# End of track
$track .= vlq(0) . "\xFF\x2F\x00";

# Assemble MIDI file
my $midi = "MThd" . pack('N',6) . pack('n',0) . pack('n',1) . pack('n',$ticks);
$midi   .= "MTrk" . pack('N', length($track)) . $track;

# Write output
my $out = 'e:/Documentos/2026/PROYECTO - ABC musica Molla/aprox1/prueba1/prueba1.mid';
open(my $fh_out, '>:raw', $out) or die "No se puede escribir $out: $!";
print $fh_out $midi;
close $fh_out;

print "Generado: $out\n";
print "Tetranucleotidos: " . scalar(@tetras) . " (bases restantes: " . (length($seq) % 4) . ")\n";
print "Notas generadas:  " . scalar(@midi_notes) . "\n";
print "\nSecuencia de notas:\n";
for my $n (@midi_notes) {
    printf "  %s -> %s (MIDI %d)\n", $n->{tetra}, $n->{note}, $n->{midi};
}
