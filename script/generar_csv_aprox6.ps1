# Genera notas_256_GROOVE_aprox6.csv
# Pitch quantizado a La Dorian, registros soprano/bajo de aprox6

$base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla'

# La Dorian: A=9, B=11, C=0, D=2, E=4, F#=6, G=7
$aDorian = @(0, 2, 4, 6, 7, 9, 11)
$noteNames = @('C','C#','D','D#','E','F','F#','G','G#','A','A#','B')

function Snap-ToScale($midi, $scale) {
    $chroma = $midi % 12
    $base_m = $midi - $chroma
    $bestC = $scale[0]; $bestD = 99
    foreach ($c in $scale) {
        $d = [math]::Abs($chroma - $c)
        if ($d -gt 6) { $d = 12 - $d }
        if ($d -lt $bestD) { $bestD = $d; $bestC = $c }
    }
    $n = $base_m + $bestC
    if (($chroma - $bestC) -gt 6) { $n += 12 }
    if (($bestC - $chroma) -gt 6) { $n -= 12 }
    return $n
}

function Force-Register($midi, $center, $lo, $hi) {
    $chroma = $midi % 12
    $best = $midi; $bestD = 999
    for ($oct = 0; $oct -le 9; $oct++) {
        $c = $oct * 12 + $chroma
        if ($c -lt $lo -or $c -gt $hi) { continue }
        $d = [math]::Abs($c - $center)
        if ($d -lt $bestD) { $bestD = $d; $best = $c }
    }
    return $best
}

function Midi-ToName($midi) {
    return $noteNames[$midi % 12] + [int]($midi / 12 - 1)
}

foreach ($groove in @('majorgroove','minorgroove')) {
    if ($groove -eq 'majorgroove') { $lo=69; $hi=93; $center=76; $voice='soprano' }
    else                           { $lo=45; $hi=69; $center=52; $voice='bajo'    }

    $lines = Get-Content "$base/data/notas_256_${groove}_aprox1_2.csv"
    $result = @('tetranucleotide,canonico,nota_original,nota_aprox6,midi_aprox6,voz')

    $noteMap = @{C=0;'C#'=1;D=2;'D#'=3;E=4;F=5;'F#'=6;G=7;'G#'=8;A=9;'A#'=10;B=11}

    foreach ($line in $lines[1..($lines.Length-1)]) {
        $f = $line -split ','
        $tetra = $f[0]; $canon = $f[1]; $nota_orig = $f[4]
        if ($nota_orig -match '^([A-G]#?)(\d)$') {
            $midi_orig    = 12 * ([int]$Matches[2] + 1) + $noteMap[$Matches[1]]
            $midi_snapped = Snap-ToScale $midi_orig $aDorian
            $midi_final   = Force-Register $midi_snapped $center $lo $hi
            $nota_final   = Midi-ToName $midi_final
            $result += "$tetra,$canon,$nota_orig,$nota_final,$midi_final,$voice"
        }
    }

    $outFile = "$base/data/notas_256_${groove}_aprox6.csv"
    $result -join "`n" | Set-Content -NoNewline $outFile -Encoding UTF8
    Write-Host "Guardado: $outFile ($($result.Count - 1) filas)"
}
