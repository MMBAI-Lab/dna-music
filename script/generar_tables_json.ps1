# Genera interface/public/tables.json desde los CSV de aprox3_6.
# Resultado: 256 entradas { "XXXX": {mg_midi, mg_ticks_lin, mg_ticks_log,
#                                    mn_midi, mn_ticks_lin, mn_ticks_log} }
#   *_midi      : nota MIDI raw (pre-snap, escala cromatica C1-C7)
#   *_ticks_lin : ticks MIDI con normalizacion lineal (aprox4/aprox5)
#   *_ticks_log : ticks MIDI con normalizacion logaritmica (aprox6/aprox7)

$root = Resolve-Path "$PSScriptRoot\.."
$base = $root.Path

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
        $f         = $line -split ','
        $tetra     = $f[0].Trim()
        $midi      = Note-ToMidi $f[4].Trim()
        $ticksLin  = $figTicks[$f[9].Trim()]    # aprox4_figura (linear)
        $ticksLog  = $figTicks[$f[10].Trim()]   # aprox6_figura (logarithmic)
        if ($null -eq $ticksLin) { throw "Figura lineal desconocida: '$($f[9].Trim())' en $tetra" }
        if ($null -eq $ticksLog) { throw "Figura log desconocida: '$($f[10].Trim())' en $tetra" }
        if (-not $table.ContainsKey($tetra)) {
            $table[$tetra] = @{ mg_midi=0; mg_ticks_lin=0; mg_ticks_log=0; mn_midi=0; mn_ticks_lin=0; mn_ticks_log=0 }
        }
        $table[$tetra]["${key}_midi"]      = $midi
        $table[$tetra]["${key}_ticks_lin"] = $ticksLin
        $table[$tetra]["${key}_ticks_log"] = $ticksLog
    }
}

# Construir JSON manualmente (formato compacto, ordenado alfabeticamente)
$sortedKeys = $table.Keys | Sort-Object
$lines = @('{')
for ($i = 0; $i -lt $sortedKeys.Count; $i++) {
    $k     = $sortedKeys[$i]
    $v     = $table[$k]
    $comma = if ($i -lt $sortedKeys.Count - 1) { ',' } else { '' }
    $lines += "  `"$k`":{`"mg_midi`":$($v.mg_midi),`"mg_ticks_lin`":$($v.mg_ticks_lin),`"mg_ticks_log`":$($v.mg_ticks_log),`"mn_midi`":$($v.mn_midi),`"mn_ticks_lin`":$($v.mn_ticks_lin),`"mn_ticks_log`":$($v.mn_ticks_log)}$comma"
}
$lines += '}'
$json = $lines -join "`n"

$out = "$base/interface/public/tables.json"
[System.IO.File]::WriteAllText($out, $json, [System.Text.Encoding]::UTF8)
$kb = [int]($json.Length / 1024)
Write-Host "Generado: $out  ($($table.Count) tetranucleotidos, ${kb} KB)"
