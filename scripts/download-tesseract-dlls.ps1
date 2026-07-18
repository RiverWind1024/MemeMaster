# download-tesseract-dlls.ps1
# Downloads pre-built Tesseract DLLs from simonflueckiger/tesserocr-windows_build releases
# The releases contain Python wheel files (.whl) which are zip archives containing DLLs

$REPO = "simonflueckiger/tesserocr-windows_build"
$API_URL = "https://api.github.com/repos/$REPO/releases/latest"
$OUT_DIR = "third_party/tesseract-dlls"

function Get-RetryWebRequest {
    param (
        [string]$Url,
        [string]$OutputPath,
        [int]$MaxRetries = 3,
        [int]$TimeoutSec = 120
    )
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            Write-Host "Attempt $attempt/$MaxRetries: Downloading from $Url"
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -TimeoutSec $TimeoutSec -UseBasicParsing
            return $true
        } catch {
            Write-Host "Attempt $attempt failed: $_"
            if ($attempt -lt $MaxRetries) {
                $waitSec = 5 * $attempt
                Write-Host "Waiting ${waitSec}s before retry..."
                Start-Sleep -Seconds $waitSec
            }
        }
    }
    return $false
}

# Main script
Write-Host "=== Downloading Tesseract DLLs ==="
Write-Host "Repository: $REPO"
Write-Host "Output directory: $OUT_DIR"

# Create output directory
$OUT_DIR_ABS = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OUT_DIR)
if (-not (Test-Path $OUT_DIR_ABS)) {
    New-Item -ItemType Directory -Path $OUT_DIR_ABS -Force | Out-Null
    Write-Host "Created directory: $OUT_DIR_ABS"
}

# Fetch latest release info
Write-Host "Fetching latest release info..."
try {
    $response = Invoke-RestMethod -Uri $API_URL -TimeoutSec 30 -UseBasicParsing
} catch {
    Write-Host "ERROR: Failed to fetch release info from $API_URL"
    Write-Host "Error: $_"
    exit 1
}

$TAG_NAME = $response.tag_name
Write-Host "Latest release: $TAG_NAME"

# Find the 64-bit Windows wheel asset (win_amd64)
# Asset name format: tesserocr-<version>-cp<pyver>-cp<pyver>-win_amd64.whl
$asset = $response.assets | Where-Object {
    $_.name -match "win_amd64\.whl$"
} | Select-Object -First 1

if (-not $asset) {
    Write-Host "ERROR: No win_amd64 wheel found in release $TAG_NAME"
    Write-Host "Available assets:"
    $response.assets | ForEach-Object { Write-Host "  - $($_.name)" }
    exit 1
}

Write-Host "Found wheel: $($asset.name)"

$DOWNLOAD_URL = $asset.browser_download_url
$WHL_PATH = Join-Path $env:TEMP $asset.name
Write-Host "Downloading to $WHL_PATH..."

$success = Get-RetryWebRequest -Url $DOWNLOAD_URL -OutputPath $WHL_PATH
if (-not $success) {
    Write-Host "ERROR: Failed to download after $MaxRetries attempts"
    exit 1
}

$actualSizeMB = [math]::Round((Get-Item $WHL_PATH).Length / 1MB, 1)
Write-Host "Downloaded: $actualSizeMB MB"

# Extract wheel (it's a zip file) to output directory
Write-Host "Extracting wheel to $OUT_DIR_ABS..."
try {
    Expand-Archive -Path $WHL_PATH -DestinationPath $OUT_DIR_ABS -Force
    Write-Host "Extraction complete"
} catch {
    Write-Host "ERROR: Failed to extract archive"
    Write-Host "Error: $_"
    Remove-Item $WHL_PATH -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up wheel file
Remove-Item $WHL_PATH -Force -ErrorAction SilentlyContinue

# Find DLLs in tesseract subdirectory
Write-Host "Finding DLLs..."
$TESSERACT_DIR = Join-Path $OUT_DIR_ABS "tesseract"
if (Test-Path $TESSERACT_DIR) {
    $foundDlls = Get-ChildItem -Path $TESSERACT_DIR -Filter "*.dll" -ErrorAction SilentlyContinue
    if ($foundDlls) {
        Write-Host "Found DLLs in tesseract directory:"
        foreach ($dll in $foundDlls) {
            $sizeKB = [math]::Round($dll.Length / 1KB, 1)
            Write-Host "  $($dll.Name) ($sizeKB KB)"
        }
    }
}

# Also check root directory
$rootDlls = Get-ChildItem -Path $OUT_DIR_ABS -Filter "*.dll" -ErrorAction SilentlyContinue
if ($rootDlls) {
    Write-Host "Found DLLs in root directory:"
    foreach ($dll in $rootDlls) {
        $sizeKB = [math]::Round($dll.Length / 1KB, 1)
        Write-Host "  $($dll.Name) ($sizeKB KB)"
    }
}

$allDlls = Get-ChildItem -Path $OUT_DIR_ABS -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue
if ($allDlls.Count -eq 0) {
    Write-Host "WARNING: No DLLs found after extraction!"
} else {
    Write-Host ""
    Write-Host "=== Success: $($allDlls.Count) DLLs extracted to $OUT_DIR_ABS ==="
}
