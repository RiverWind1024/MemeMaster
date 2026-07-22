// TestWindowsOcr.csproj
// <Project Sdk="Microsoft.NET.Sdk">
//   <PropertyGroup>
//     <OutputType>Exe</OutputType>
//     <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
//     <ImplicitUsings>enable</ImplicitUsings>
//     <Nullable>enable</Nullable>
//   </PropertyGroup>
// </Project>

using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using System.Diagnostics;

class Program
{
    static async Task Main(string[] args)
    {
        Console.WriteLine("=== Windows OCR Test ===");
        Console.WriteLine($"OS: {Environment.OSVersion}");
        Console.WriteLine($".NET: {Environment.Version}");

        // Check available languages
        Console.WriteLine("\n=== Available OCR Languages ===");
        foreach (var lang in OcrEngine.AvailableRecognizerLanguages)
        {
            Console.WriteLine($"  {lang.LanguageTag} - {lang.DisplayName}");
        }

        // Create OCR engine
        Console.WriteLine("\n=== Creating OCR Engine ===");
        var engine = OcrEngine.TryCreateFromUserProfileLanguages();
        if (engine == null)
        {
            Console.WriteLine("ERROR: Failed to create OCR engine");
            Environment.Exit(1);
        }
        Console.WriteLine($"Engine created successfully");

        // If no args, just verify engine creation
        if (args.Length == 0)
        {
            Console.WriteLine("\nNo image path provided, exiting after engine test.");
            Environment.Exit(0);
        }

        string imagePath = args[0];
        Console.WriteLine($"\n=== Recognizing: {imagePath} ===");

        try
        {
            var stopwatch = Stopwatch.StartNew();

            // Load image
            var storageFile = await StorageFile.GetFileFromPathAsync(imagePath);
            using var stream = await storageFile.OpenAsync(FileAccessMode.Read);
            var decoder = await BitmapDecoder.CreateAsync(stream);
            var softwareBitmap = await decoder.GetSoftwareBitmapAsync();

            Console.WriteLine($"Image loaded: {decoder.PixelWidth}x{decoder.PixelHeight}");

            // Perform OCR
            var result = await engine.RecognizeAsync(softwareBitmap);
            stopwatch.Stop();

            Console.WriteLine($"\n=== Results ({stopwatch.ElapsedMilliseconds}ms) ===");
            Console.WriteLine($"Raw text:\n{result.Text}");
            Console.WriteLine($"\nLines: {result.Lines.Count}");
            foreach (var line in result.Lines)
            {
                Console.WriteLine($"  [{line.Text}]");
            }

            // Check if we got meaningful results
            if (string.IsNullOrWhiteSpace(result.Text))
            {
                Console.WriteLine("\nWARNING: No text detected in image");
                Environment.Exit(2);
            }

            Console.WriteLine($"\nSUCCESS: Detected {result.Text.Length} characters");
            Environment.Exit(0);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"\nERROR: {ex.Message}");
            Console.WriteLine(ex.StackTrace);
            Environment.Exit(1);
        }
    }
}
