# Fast membership check for 1701.csv
# Assumption: first five columns are quoted simple fields without embedded commas:
# 开票日期, 购方企业ID, 购方地区, 销方企业ID, 销方地区

$base = "G:\Kuangyu_Temp\Outsource\productivity"
$csvPath = Join-Path $base "1701.csv"
$firmCityPath = Join-Path $base "firm_city.csv"
$outPath = Join-Path $base "productivity\1701_fast_sample_check_summary.txt"

$sampleIds = New-Object 'System.Collections.Generic.HashSet[string]'
Import-Csv -LiteralPath $firmCityPath -Encoding UTF8 | ForEach-Object {
    [void]$sampleIds.Add(($_.'企业ID').Trim())
}

$reader = [System.IO.StreamReader]::new($csvPath, [System.Text.Encoding]::UTF8, $true, 1048576)
$header = $reader.ReadLine()

$n = 0L
$buyerIn = 0L
$sellerIn = 0L
$eitherIn = 0L
$bothIn = 0L
$neitherIn = 0L
$badRows = 0L
$firstNeither = $null

$sampleBuyersSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$sampleSellersSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$sampleEitherSeen = New-Object 'System.Collections.Generic.HashSet[string]'

Set-Content -LiteralPath $outPath -Encoding UTF8 -Value ("started: " + (Get-Date))
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("sample_ids: " + $sampleIds.Count)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("header: " + $header)

while (($line = $reader.ReadLine()) -ne $null) {
    $n++
    $parts = $line.Split(',', 6)
    if ($parts.Length -lt 4) {
        $badRows++
        continue
    }

    $b = $parts[1].Trim('"')
    $s = $parts[3].Trim('"')

    $bin = $sampleIds.Contains($b)
    $sin = $sampleIds.Contains($s)

    if ($bin) {
        $buyerIn++
        [void]$sampleBuyersSeen.Add($b)
        [void]$sampleEitherSeen.Add($b)
    }
    if ($sin) {
        $sellerIn++
        [void]$sampleSellersSeen.Add($s)
        [void]$sampleEitherSeen.Add($s)
    }
    if ($bin -or $sin) {
        $eitherIn++
    } else {
        $neitherIn++
        if ($null -eq $firstNeither) { $firstNeither = $line }
    }
    if ($bin -and $sin) { $bothIn++ }

    if (($n % 10000000) -eq 0) {
        Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("progress rows: $n at $(Get-Date) neither: $neitherIn badRows: $badRows")
    }
}
$reader.Close()

Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("finished: " + (Get-Date))
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("total_rows: " + $n)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("sample_ids: " + $sampleIds.Count)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("buyer_in_sample_rows: " + $buyerIn)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("seller_in_sample_rows: " + $sellerIn)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("either_in_sample_rows: " + $eitherIn)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("both_in_sample_rows: " + $bothIn)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("neither_in_sample_rows: " + $neitherIn)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("bad_rows: " + $badRows)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("unique_sample_buyers_seen: " + $sampleBuyersSeen.Count)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("unique_sample_sellers_seen: " + $sampleSellersSeen.Count)
Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("unique_sample_either_seen: " + $sampleEitherSeen.Count)
if ($n -gt 0) {
    Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("share_either_in_sample: " + [Math]::Round($eitherIn / $n, 8))
    Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("share_neither_in_sample: " + [Math]::Round($neitherIn / $n, 8))
}
if ($null -ne $firstNeither) {
    Add-Content -LiteralPath $outPath -Encoding UTF8 -Value ("first_neither_line: " + $firstNeither)
}

Get-Content -LiteralPath $outPath -Tail 30
