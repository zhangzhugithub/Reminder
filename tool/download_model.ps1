# Download offline ASR model (Mandarin streaming, int8, ~159MB)
# Tries GitHub Release -> HuggingFace -> hf-mirror (China mirror)
# Extracts to assets/models/ (gitignored, bundled with the app)
# Usage: powershell -ExecutionPolicy Bypass -File tool\download_model.ps1

$ErrorActionPreference = 'Stop'
$MODEL = 'sherpa-onnx-streaming-zipformer-zh-int8-2025-06-30'
$FILE = "$MODEL.tar.bz2"
$URLS = @(
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$FILE",
  "https://huggingface.co/csukuangfj/$MODEL/resolve/main/$FILE",
  "https://hf-mirror.com/csukuangfj/$MODEL/resolve/main/$FILE"
)

$root = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $root 'assets\models'
$tmp = Join-Path $root 'tmp_model'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$ok = $false
foreach ($url in $URLS) {
  Write-Host "Attempting: $url"
  try {
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp $FILE) -TimeoutSec 60 -UseBasicParsing
    $ok = $true
    break
  } catch {
    Write-Host "Source failed, trying next..."
  }
}

if (-not $ok) {
  Write-Host 'ERROR: all download sources failed.' -ForegroundColor Red
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  exit 1
}

Write-Host 'Extracting...'
tar -xjf (Join-Path $tmp $FILE) -C $tmp

$modelDir = Join-Path $tmp $MODEL
if (Test-Path $modelDir) {
  Copy-Item (Join-Path $modelDir '*') -Destination $assets -Force
} else {
  Copy-Item (Join-Path $tmp '*') -Destination $assets -Force -Exclude $FILE
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Write-Host 'Done. assets/models/:'
Get-ChildItem $assets | ForEach-Object { Write-Host ("  {0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB)) }
