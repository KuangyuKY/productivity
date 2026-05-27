# 1701.csv sample membership check helper
# This script checks dispersed chunks of the huge CSV without loading the full file.

Add-Type -AssemblyName Microsoft.VisualBasic

$base = "G:\Kuangyu_Temp\Outsource\productivity"
$csvPath = Join-Path $base "1701.csv"
$firmCityPath = Join-Path $base "firm_city.csv"
$outPath = Join-Path $base "productivity\1701_chunk_sample_check.txt"

$sampleIds = New-Object 'System.Collections.Generic.HashSet[string]'
Import-Csv -LiteralPath $firmCityPath -Encoding UTF8 | ForEach-Object {
    [void]$sampleIds.Add(($_.'企业ID').Trim())
}

$file = Get-Item -LiteralPath $csvPath
$positions = @(
    0,
    [int64]($file.Length * 0.10),
    [int64]($file.Length * 0.25),
    [int64]($file.Length * 0.50),
    [int64]($file.Length * 0.75),
    [int64]($file.Length * 0.90)
)

$chunkSize = 20MB
$encoding = [System.Text.Encoding]::UTF8
$results = @()

foreach ($pos in $positions) {
    $fs = [System.IO.File]::OpenRead($csvPath)
    $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
    $buf = New-Object byte[] $chunkSize
    $nbytes = $fs.Read($buf, 0, $buf.Length)
    $fs.Close()

    $text = $encoding.GetString($buf, 0, $nbytes)
    $lines = $text -split "`r?`n"

    if ($pos -eq 0) {
        $headerLine = $lines[0]
        $dataLines = $lines[1..($lines.Count-2)]
    } else {
        $headerLine = '"开票日期","购方企业ID","购方地区","销方企业ID","销方地区","项目代码","项目","开票金额","单位","数量","单价","税额"'
        $dataLines = $lines[1..($lines.Count-2)]
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -LiteralPath $tmp -Encoding UTF8 -Value $headerLine
    Add-Content -LiteralPath $tmp -Encoding UTF8 -Value $dataLines

    $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($tmp, [System.Text.Encoding]::UTF8)
    $parser.SetDelimiters(',')
    $parser.HasFieldsEnclosedInQuotes = $true
    $header = $parser.ReadFields()
    $idxBuyer = [Array]::IndexOf($header, '购方企业ID')
    $idxSeller = [Array]::IndexOf($header, '销方企业ID')

    $rows = 0
    $buyerIn = 0
    $sellerIn = 0
    $eitherIn = 0
    $bothIn = 0
    $neitherIn = 0

    while (!$parser.EndOfData) {
        try {
            $fields = $parser.ReadFields()
            if ($fields.Length -lt 12) { continue }
            $rows++
            $b = $fields[$idxBuyer].Trim()
            $s = $fields[$idxSeller].Trim()
            $bin = $sampleIds.Contains($b)
            $sin = $sampleIds.Contains($s)
            if ($bin) { $buyerIn++ }
            if ($sin) { $sellerIn++ }
            if ($bin -or $sin) { $eitherIn++ } else { $neitherIn++ }
            if ($bin -and $sin) { $bothIn++ }
        } catch {
            continue
        }
    }
    $parser.Close()
    Remove-Item -LiteralPath $tmp -Force

    $results += [pscustomobject]@{
        position_bytes = $pos
        position_share = [Math]::Round($pos / $file.Length, 4)
        rows_checked = $rows
        buyer_in_sample_rows = $buyerIn
        seller_in_sample_rows = $sellerIn
        either_in_sample_rows = $eitherIn
        both_in_sample_rows = $bothIn
        neither_in_sample_rows = $neitherIn
        share_either = if ($rows -gt 0) { [Math]::Round($eitherIn / $rows, 6) } else { $null }
        share_neither = if ($rows -gt 0) { [Math]::Round($neitherIn / $rows, 6) } else { $null }
    }
}

$results | Format-Table -AutoSize | Out-String | Set-Content -LiteralPath $outPath -Encoding UTF8
Get-Content -LiteralPath $outPath
