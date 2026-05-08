# generate-payloads.ps1
# Usage: .\generate-payloads.ps1 [-Dir .\files] [-OutFile payloads.txt] [-Clipboard]
#
# Scans the directory for files named 'exp-linux-<arch>' (e.g. exp-linux-x86_64),
# gzip-compresses each one, base64-encodes it, and emits a JavaScript object
# literal you can paste directly over the PAYLOADS = { ... } block in worker.js.
#
# Recognised archs: x86_64, aarch64, armv7, i386

[CmdletBinding()]
param(
    [string]$Dir = ".\files",
    [string]$OutFile,
    [switch]$Clipboard
)

if (-not (Test-Path -LiteralPath $Dir)) {
    Write-Error "Directory not found: $Dir"
    exit 1
}

$archs = @("x86_64", "aarch64", "armv7", "i386")

function Compress-Base64 {
    param([byte[]]$Bytes)
    $ms = New-Object System.IO.MemoryStream
    $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionLevel]::SmallestSize)
    $gz.Write($Bytes, 0, $Bytes.Length)
    $gz.Close()
    $compressed = $ms.ToArray()
    $ms.Close()
    return @{
        B64        = [System.Convert]::ToBase64String($compressed)
        Compressed = $compressed.Length
    }
}

$results = @{}
$totalOrig = 0
$totalGz   = 0
$totalB64  = 0

foreach ($arch in $archs) {
    $path = Join-Path $Dir "exp-linux-$arch"
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Warning "Missing: $path  (skipping)"
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
    $r = Compress-Base64 -Bytes $bytes

    $results[$arch] = $r.B64

    $totalOrig += $bytes.Length
    $totalGz   += $r.Compressed
    $totalB64  += $r.B64.Length

    "{0,-8}  orig {1,8} B   gz {2,8} B   b64 {3,8} chars" -f `
        $arch, $bytes.Length, $r.Compressed, $r.B64.Length | Write-Host
}

if ($results.Count -eq 0) {
    Write-Error "No binaries found in $Dir"
    exit 1
}

# Build the JS literal
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("const PAYLOADS = {")
foreach ($arch in $archs) {
    if ($results.ContainsKey($arch)) {
        [void]$sb.AppendLine(("  {0,-7}: `"{1}`"," -f $arch, $results[$arch]))
    } else {
        [void]$sb.AppendLine(("  {0,-7}: `"`"," -f $arch))
    }
}
[void]$sb.AppendLine("};")
$js = $sb.ToString()

Write-Host ""
Write-Host ("TOTAL    orig {0} B   gz {1} B   b64 {2} chars" -f $totalOrig, $totalGz, $totalB64)

# Workers script size limits (compressed): 1 MiB free, 10 MiB paid.
if ($totalB64 -gt 900KB) {
    Write-Warning "Total payload size is approaching the 1 MiB Workers free-tier limit."
}

if ($OutFile) {
    Set-Content -LiteralPath $OutFile -Value $js -Encoding ascii
    Write-Host "Wrote JS block to $OutFile"
}

if ($Clipboard) {
    $js | Set-Clipboard
    Write-Host "JS block copied to clipboard."
}

if (-not $OutFile -and -not $Clipboard) {
    Write-Host ""
    Write-Host "----- paste this over the PAYLOADS = {...} block in worker.js -----"
    Write-Host $js
}
