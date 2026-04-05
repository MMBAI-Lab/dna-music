# Genera app/tables.json desde los CSV de aprox3_6
# Resultado: 256 entradas { "XXXX": {mg_midi, mg_ticks, mn_midi, mn_ticks} }
#   mg_midi / mn_midi : nota MIDI raw (pre-snap, escala cromatica C1-C7)
#   mg_ticks / mn_ticks: duracion en ticks MIDI (PPQ=480, normalizacion logaritmica)

$base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla'

$noteIdx = @{
    'C'=0; 'C#'=1; 'D'=2; 'D#'=3; 'E'=4; 'F'=5; 'F#'=6
    'G'=7; 'G#'=8; 'A'=9; 'A#'=10; 'B'=11
}
$figTicks = @{
    'corchea'=240; 'corchea con punto'=360
    'negra'=480; 'negra con punto'=720; 'blanca'=960
}

function Note-ToMidi([string]$note) {
    if ($note -match '^([A-G]#?)(-?\d+)$') {
        return 12 * ([int]$Matches[2] + 1) + $noteIdx[$Matches[1]]
    }
    throw "Nota invalida: '$note'"
}

$table = @{}

foreach ($groove in @('majorgroove', 'minorgroove')) {
    $key = if ($groove -eq 'majorgroove') { 'mg' } else { 'mn' }
    $csv = Get-Content "$base/data/notas_256_${groove}_aprox3_6.csv"
    foreach ($line in $csv[1..($csv.Length - 1)]) {
        $f     = $line -split ','
        $tetra = $f[0].Trim()
        $midi  = Note-ToMidi $f[4].Trim()
        $ticks = $figTicks[$f[10].Trim()]
        if ($null -eq $ticks) { throw "Figura desconocida: '$($f[10].Trim())' en $tetra" }
        if (-not $table.ContainsKey($tetra)) {
            $table[$tetra] = @{ mg_midi=0; mg_ticks=0; mn_midi=0; mn_ticks=0 }
        }
        $table[$tetra]["${key}_midi"]  = $midi
        $table[$tetra]["${key}_ticks"] = $ticks
    }
}

# Construir JSON manualmente (formato compacto, ordenado alfabeticamente)
$sortedKeys = $table.Keys | Sort-Object
$lines = @('{')
for ($i = 0; $i -lt $sortedKeys.Count; $i++) {
    $k     = $sortedKeys[$i]
    $v     = $table[$k]
    $comma = if ($i -lt $sortedKeys.Count - 1) { ',' } else { '' }
    $lines += "  `"$k`":{`"mg_midi`":$($v.mg_midi),`"mg_ticks`":$($v.mg_ticks),`"mn_midi`":$($v.mn_midi),`"mn_ticks`":$($v.mn_ticks)}$comma"
}
$lines += '}'
$json = $lines -join "`n"

$out = "$base/app/tables.json"
[System.IO.File]::WriteAllText($out, $json, [System.Text.Encoding]::UTF8)
$kb = [int]($json.Length / 1024)
Write-Host "Generado: $out  ($($table.Count) tetranucleotidos, ${kb} KB)"
