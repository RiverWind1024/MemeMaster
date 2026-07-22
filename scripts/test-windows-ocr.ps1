# test-windows-ocr.ps1
# Tests Windows.Media.Ocr on the CI runner

param(
    [string]$ImagePath = ""
)

$ErrorActionPreference = "Continue"

Write-Host "=== Windows OCR CI Test ==="
Write-Host "Windows: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId)"
Write-Host "dotnet: $(dotnet --version 2>$null)"

# Create temp project for OCR test
$TempDir = "$env:TEMP\ocr_test_$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# Write csproj
@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
"@ | Out-File -FilePath "$TempDir\test.csproj" -Encoding UTF8

# Write C# code
@"
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using System.Diagnostics;

var engine = OcrEngine.TryCreateFromUserProfileLanguages();
if (engine == null) {
    Console.WriteLine("RESULT: FAIL - Cannot create OCR engine");
    Environment.Exit(1);
}
Console.WriteLine("RESULT: OK - OCR engine created");

if (string.IsNullOrEmpty(args[0])) {
    Console.WriteLine("No image path - engine test only");
    Environment.Exit(0);
}

var sw = Stopwatch.StartNew();
var file = await StorageFile.GetFileFromPathAsync(args[0]);
var stream = await file.OpenAsync(FileAccessMode.Read);
var decoder = await BitmapDecoder.CreateAsync(stream);
var bitmap = await decoder.GetSoftwareBitmapAsync();
var result = await engine.RecognizeAsync(bitmap);
sw.Stop();

Console.WriteLine($"RESULT: OK - {result.Text.Length} chars in {sw.ElapsedMilliseconds}ms");
Console.WriteLine($"TEXT: {result.Text}");
Environment.Exit(0);
"@ | Out-File -FilePath "$TempDir\Program.cs" -Encoding UTF8

Write-Host "Building OCR test project..."
Push-Location $TempDir
try {
    $build = dotnet build -c Release 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "BUILD FAILED:"
        Write-Host $build
        Pop-Location
        exit 1
    }
    Write-Host "Build succeeded"

    if (-not [string]::IsNullOrEmpty($ImagePath)) {
        Write-Host "Running OCR on: $ImagePath"
        $run = dotnet run --no-build -c Release -- "$ImagePath" 2>&1
        Write-Host $run
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            exit 1
        }
    }
} finally {
    Pop-Location
}

# Cleanup
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue

Write-Host "=== Test Complete ==="
exit 0
