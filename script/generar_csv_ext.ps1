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
function Get-Figure($ps) {
    $best = $durMap[0]; $bestDiff = [math]::Abs($ps - $durMap[0].ps)
    foreach ($d in $durMap) {
        $diff = [math]::Abs($ps - $d.ps)
        if ($diff -lt $bestDiff) { $bestDiff = $diff; $best = $d }
    }
    return $best
}

$base = 'e:/Documentos/2026/PROYECTO - ABC musica Molla'

foreach ($groove in @('majorgroove','minorgroove')) {
    $tiempos = @{}
    Get-ChildItem "$base/source/MUSIC.$groove/*.dat" | ForEach-Object {
        $key = $_.BaseName -replace '\.(MG|mg)$', ''
        $c = [System.IO.File]::ReadAllText($_.FullName)
        if ($c -match 'Tiempo de vida media: ([\d.]+)') { $tiempos[$key] = [double]$Matches[1] }
    }

    $lines = Get-Content "$base/data/notas_256_$groove.csv"
    $result = @('tetranucleotide,canonico,ocupacion_pct,ocupacion_x10,nota,frecuencia_hz,tiempo_vida_media_ps,figura_ps,figura')

    foreach ($line in $lines[1..($lines.Length-1)]) {
        $f = $line -split ','
        $canon = $f[1]
        $rc = RevComp $canon
        $ps = if ($tiempos.ContainsKey($canon)) { $tiempos[$canon] }
              elseif ($tiempos.ContainsKey($rc))  { $tiempos[$rc]   }
              else { throw "No tiempo para $canon" }
        $fig = Get-Figure $ps
        $result += "$line,$($ps.ToString('F6')),$($fig.ps),$($fig.name)"
    }

    $outFile = "$base/data/notas_256_${groove}_ext.csv"
    $result -join "`n" | Set-Content -NoNewline $outFile -Encoding UTF8
    Write-Host "Guardado: $outFile ($($result.Count - 1) filas)"
}
