# Genera notas_256_GROOVE_aprox6.csv
# Extiende aprox3_4 añadiendo columna aprox6_figura con normalización logarítmica

$base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla'

$figures = @(
    @{ ticks=240; name='corchea'           },
    @{ ticks=360; name='corchea con punto' },
    @{ ticks=480; name='negra'             },
    @{ ticks=720; name='negra con punto'   },
    @{ ticks=960; name='blanca'            }
)

function Get-FigureLog($ps, $logMin, $logMax) {
    $n    = $figures.Count
    $idx  = [int](([math]::Log($ps) - $logMin) / ($logMax - $logMin) * $n)
    if ($idx -lt 0)    { $idx = 0 }
    if ($idx -ge $n)   { $idx = $n - 1 }
    return $figures[$idx]
}

$comp = @{ 'A'='T'; 'T'='A'; 'C'='G'; 'G'='C' }
function RevComp($seq) {
    $rev = -join ($seq.ToCharArray() | ForEach-Object { $comp[$_.ToString()] })
    return -join $rev.ToCharArray()[-1..-4]
}

foreach ($groove in @('majorgroove','minorgroove')) {
    # Load tiempos
    $tiempos = @{}
    Get-ChildItem "$base/source/MUSIC.$groove/*.dat" | ForEach-Object {
        $key = $_.BaseName -replace '\.(MG|mg)$', ''
        $c = [System.IO.File]::ReadAllText($_.FullName)
        if ($c -match 'Tiempo de vida media: ([\d.]+)') { $tiempos[$key] = [double]$Matches[1] }
    }
    $allPs  = $tiempos.Values
    $psMin  = ($allPs | Measure-Object -Minimum).Minimum
    $psMax  = ($allPs | Measure-Object -Maximum).Maximum
    $logMin = [math]::Log($psMin)
    $logMax = [math]::Log($psMax)
    Write-Host "${groove}: ps_min=$($psMin.ToString('F4'))  ps_max=$($psMax.ToString('F4'))  log_min=$($logMin.ToString('F4'))  log_max=$($logMax.ToString('F4'))"

    # Read aprox3_4 CSV and add aprox6 column
    $lines  = Get-Content "$base/data/notas_256_${groove}_aprox3_4.csv"
    $result = @($lines[0] + ',aprox6_figura')

    foreach ($line in $lines[1..($lines.Length-1)]) {
        $f     = $line -split ','
        $canon = $f[1]
        $rc    = RevComp $canon
        $ps    = if ($tiempos.ContainsKey($canon))  { $tiempos[$canon] }
                 elseif ($tiempos.ContainsKey($rc))  { $tiempos[$rc]   }
                 else { throw "No tiempo para $canon" }
        $fig6  = Get-FigureLog $ps $logMin $logMax
        $result += "$line,$($fig6.name)"
    }

    $outFile = "$base/data/notas_256_${groove}_aprox3_6.csv"
    $result -join "`n" | Set-Content -NoNewline $outFile -Encoding UTF8
    Write-Host "Guardado: $outFile ($($result.Count - 1) filas)"
}
