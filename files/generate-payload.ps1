# generate-payload.ps1
# Usage: .\generate-payload.ps1 -Path .\yourfile.bin [-OutFile payload.txt] [-Clipboard]
#
# Produces a gzip-compressed, base64-encoded string to paste into the
# FILE_B64_GZ constant in worker.js.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [string]$OutFile,

    [switch]$Clipboard
)

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))

# Gzip compress (best compression)
$ms = New-Object System.IO.MemoryStream
$gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionLevel]::SmallestSize)
$gz.Write($bytes, 0, $bytes.Length)
$gz.Close()
$compressed = $ms.ToArray()
$ms.Close()

$b64 = [System.Convert]::ToBase64String($compressed)

$origKB = [math]::Round($bytes.Length / 1KB, 2)
$gzKB   = [math]::Round($compressed.Length / 1KB, 2)
$b64KB  = [math]::Round($b64.Length / 1KB, 2)

Write-Host ("File:       {0}" -f $Path)
Write-Host ("Original:   {0} bytes ({1} KB)" -f $bytes.Length, $origKB)
Write-Host ("Gzipped:    {0} bytes ({1} KB)" -f $compressed.Length, $gzKB)
Write-Host ("Base64:     {0} chars ({1} KB)" -f $b64.Length, $b64KB)

# Worker script size limits (compressed): 1 MiB free, 10 MiB paid.
# The base64 string itself sits in the script, so warn if it's getting big.
if ($b64.Length -gt 900KB) {
    Write-Warning "Payload is approaching the 1 MiB Workers free-tier limit."
}

if ($OutFile) {
    Set-Content -LiteralPath $OutFile -Value $b64 -NoNewline -Encoding ascii
    Write-Host "Wrote payload to $OutFile"
}

if ($Clipboard) {
    $b64 | Set-Clipboard
    Write-Host "Payload copied to clipboard."
}

if (-not $OutFile -and -not $Clipboard) {
    $b64
}
