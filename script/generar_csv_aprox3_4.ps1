# Genera notas_256_GROOVE_aprox3_4.csv:
# - Columnas aprox3: figura más cercana al valor absoluto de ps
# - Columnas aprox4: figura por normalización lineal del rango real del surco
# Lee desde notas_256_GROOVE_aprox1_2.csv

$comp = @{ 'A'='T'; 'T'='A'; 'C'='G'; 'G'='C' }
function RevComp($seq) {
    $rev = -join ($seq.ToCharArray() | ForEach-Object { $comp[$_.ToString()] })
    return -join $rev.ToCharArray()[-1..-4]
}

$durMap = @(
    @{ ps=3;   name='corchea'           },
    @{ ps=4.5; name='corchea con punto' },
    @{ ps=6;   name='negra'             },
    @{ ps=9;   name='negra con punto'   },
    @{ ps=12;  name='blanca'            }
)
$figures = @(
    @{ ticks=240; name='corchea'           },
    @{ ticks=360; name='corchea con punto' },
    @{ ticks=480; name='negra'             },
    @{ ticks=720; name='negra con punto'   },
    @{ ticks=960; name='blanca'            }
)

function Get-FigureNearest($ps) {
    $best = $durMap[0]; $bestDiff = [math]::Abs($ps - $durMap[0].ps)
    foreach ($d in $durMap) {
        $diff = [math]::Abs($ps - $d.ps)
        if ($diff -lt $bestDiff) { $bestDiff = $diff; $best = $d }
    }
    return $best
}

function Get-FigureLinear($ps, $min, $max) {
    $n = $figures.Count
    $idx = [int](($ps - $min) / ($max - $min) * $n)
    if ($idx -lt 0)      { $idx = 0 }
    if ($idx -ge $n)     { $idx = $n - 1 }
    return $figures[$idx]
}

$base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla'

foreach ($groove in @('majorgroove','minorgroove')) {
    # Load tiempo de vida media
    $tiempos = @{}
    Get-ChildItem "$base/source/MUSIC.$groove/*.dat" | ForEach-Object {
        $key = $_.BaseName -replace '\.(MG|mg)$', ''
        $c = [System.IO.File]::ReadAllText($_.FullName)
        if ($c -match 'Tiempo de vida media: ([\d.]+)') { $tiempos[$key] = [double]$Matches[1] }
    }

    # Compute min/max for linear normalization
    $allPs = $tiempos.Values
    $psMin = ($allPs | Measure-Object -Minimum).Minimum
    $psMax = ($allPs | Measure-Object -Maximum).Maximum
    Write-Host "${groove}: ps_min=$psMin  ps_max=$psMax"

    # Read aprox1_2 CSV
    $lines = Get-Content "$base/data/notas_256_${groove}_aprox1_2.csv"
    $result = @($lines[0] + ',tiempo_vida_media_ps,aprox3_figura_ps,aprox3_figura,aprox4_figura')

    foreach ($line in $lines[1..($lines.Length-1)]) {
        $f = $line -split ','
        $canon = $f[1]
        # Resolve canonical tiempo
        $ps = if ($tiempos.ContainsKey($canon))            { $tiempos[$canon] }
              elseif ($tiempos.ContainsKey((RevComp $canon))) { $tiempos[(RevComp $canon)] }
              else { throw "No tiempo para $canon" }

        $fig3 = Get-FigureNearest $ps
        $fig4 = Get-FigureLinear  $ps $psMin $psMax

        $result += "$line,$($ps.ToString('F6')),$($fig3.ps),$($fig3.name),$($fig4.name)"
    }

    $outFile = "$base/data/notas_256_${groove}_aprox3_4.csv"
    $result -join "`n" | Set-Content -NoNewline $outFile -Encoding UTF8
    Write-Host "Guardado: $outFile ($($result.Count - 1) filas)"
}
