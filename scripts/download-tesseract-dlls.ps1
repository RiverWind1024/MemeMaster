# download-tesseract-dlls.ps1
# Downloads pre-built Tesseract DLLs from simonflueckiger/tesserocr-windows_build releases
# These DLLs include tesseract, leptonica, and all dependencies (libpng, libjpeg, libtiff, zlib)

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

# Find the 64-bit Windows zip asset
# Asset name format: tesseract-<version>-win64.zip
$VERSION = $TAG_NAME.TrimStart('v')
$ASSET_NAME = "tesseract-${VERSION}-win64.zip"

Write-Host "Looking for asset: $ASSET_NAME"

$asset = $response.assets | Where-Object { $_.name -eq $ASSET_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Host "ERROR: Asset '$ASSET_NAME' not found in release $TAG_NAME"
    Write-Host "Available assets:"
    $response.assets | ForEach-Object { Write-Host "  - $($_.name)" }
    exit 1
}

$DOWNLOAD_URL = $asset.browser_download_url
$EXPECTED_SIZE_MB = [math]::Round($asset.size / 1MB, 1)
Write-Host "Found: $($asset.name) ($EXPECTED_SIZE_MB MB)"

# Download the zip
$ZIP_PATH = Join-Path $env:TEMP $ASSET_NAME
Write-Host "Downloading to $ZIP_PATH..."

$success = Get-RetryWebRequest -Url $DOWNLOAD_URL -OutputPath $ZIP_PATH
if (-not $success) {
    Write-Host "ERROR: Failed to download after $MaxRetries attempts"
    exit 1
}

$actualSizeMB = [math]::Round((Get-Item $ZIP_PATH).Length / 1MB, 1)
Write-Host "Downloaded: $actualSizeMB MB"

# Extract DLLs to output directory
Write-Host "Extracting to $OUT_DIR_ABS..."
try {
    Expand-Archive -Path $ZIP_PATH -DestinationPath $OUT_DIR_ABS -Force
    Write-Host "Extraction complete"
} catch {
    Write-Host "ERROR: Failed to extract archive"
    Write-Host "Error: $_"
    Remove-Item $ZIP_PATH -Force -ErrorAction SilentlyContinue
    exit 1
}

# Clean up zip
Remove-Item $ZIP_PATH -Force -ErrorAction SilentlyContinue

# Verify DLLs exist
Write-Host "Verifying DLLs..."
$DLL_PATTERNS = @("tesseract*.dll", "leptonica*.dll", "libpng*.dll", "libjpeg*.dll", "libtiff*.dll", "zlib*.dll")
$foundDlls = @()
foreach ($pattern in $DLL_PATTERNS) {
    $matches = Get-ChildItem -Path $OUT_DIR_ABS -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($dll in $matches) {
        $foundDlls += $dll.Name
        $sizeKB = [math]::Round($dll.Length / 1KB, 1)
        Write-Host "  Found: $($dll.Name) ($sizeKB KB)"
    }
}

if ($foundDlls.Count -eq 0) {
    Write-Host "ERROR: No Tesseract DLLs found after extraction!"
    exit 1
}

Write-Host ""
Write-Host "=== Success: $($foundDlls.Count) DLLs extracted to $OUT_DIR_ABS ==="
Write-Host "Total DLLs:"
$foundDlls | ForEach-Object { Write-Host "  - $_" }
