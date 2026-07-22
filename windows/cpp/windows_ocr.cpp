#include "windows_ocr.h"

#ifdef _WIN32

#include <windows.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <string>
#include <vector>
#include <memory>
#include <stdexcept>

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Graphics::Imaging;
using namespace Windows::Media::Ocr;
using namespace Windows::Storage;
using namespace Windows::Storage::Streams;

namespace {

std::wstring to_wstring(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), nullptr, 0);
    std::wstring wstr(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), wstr.data(), size_needed);
    return wstr;
}

std::string to_utf8(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), nullptr, 0, nullptr, nullptr);
    std::string str(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), str.data(), size_needed, nullptr, nullptr);
    return str;
}

void escape_json_string(const std::wstring& input, std::wstring& output) {
    output.reserve(input.size() + 16);
    for (wchar_t c : input) {
        switch (c) {
            case L'"':  output += L"\\\""; break;
            case L'\\': output += L"\\\\"; break;
            case L'\n': output += L"\\n"; break;
            case L'\r': output += L"\\r"; break;
            case L'\t': output += L"\\t"; break;
            default: output += c; break;
        }
    }
}

IAsyncOperation<SoftwareBitmap> load_image_async(const std::wstring& image_path) {
    auto file = co_await StorageFile::GetFileFromPathAsync(image_path);
    auto stream = co_await file.OpenAsync(FileAccessMode::Read);
    auto decoder = co_await BitmapDecoder::CreateAsync(stream);
    SoftwareBitmap bitmap = co_await decoder.GetSoftwareBitmapAsync();
    co_return bitmap;
}

} // namespace

extern "C" {

OCR_API void* ocr_create(void) {
    try {
        auto engine = OcrEngine::TryCreateFromUserProfileLanguages();
        if (engine == nullptr) {
            return nullptr;
        }
        return new OcrEngine(engine);
    } catch (...) {
        return nullptr;
    }
}

OCR_API void ocr_destroy(void* handle) {
    if (handle) {
        delete reinterpret_cast<OcrEngine*>(handle);
    }
}

OCR_API char* ocr_recognize(void* handle, const char* imagePath) {
    if (!handle || !imagePath) {
        std::string error_json = "{\"text\":\"\",\"blocks\":[],\"error\":\"Invalid arguments\"}";
        char* result = (char*)malloc(error_json.size() + 1);
        strcpy_s(result, error_json.size() + 1, error_json.c_str());
        return result;
    }

    OcrEngine* engine = reinterpret_cast<OcrEngine*>(handle);
    std::wstring image_path = to_wstring(imagePath);

    try {
        SoftwareBitmap bitmap = load_image_async(image_path).get();

        auto result_async = engine->RecognizeAsync(bitmap);
        OcrResult ocr_result = result_async.get();

        std::wstring json_result = L"{\"text\":\"";
        std::wstring text_escaped;
        escape_json_string(ocr_result.Text(), text_escaped);
        json_result += text_escaped;
        json_result += L"\",\"blocks\":[";

        bool first = true;
        for (const OcrLine& line : ocr_result.Lines()) {
            if (!first) json_result += L",";
            first = false;

            json_result += L"{\"text\":\"";
            std::wstring line_text_escaped;
            escape_json_string(line.Text(), line_text_escaped);
            json_result += line_text_escaped;
            json_result += L"\",";

            double min_x = 1.0, min_y = 1.0, max_x = 0.0, max_y = 0.0;
            bool has_words = false;

            for (const OcrWord& word : line.Words()) {
                has_words = true;
                BoundingRect rect = word.BoundingRect();
                min_x = std::min(min_x, (double)rect.X);
                min_y = std::min(min_y, (double)rect.Y);
                max_x = std::max(max_x, (double)(rect.X + rect.Width));
                max_y = std::max(max_y, (double)(rect.Y + rect.Height));
            }

            if (!has_words) {
                BoundingRect rect = line.BoundingRect();
                min_x = (double)rect.X;
                min_y = (double)rect.Y;
                max_x = (double)(rect.X + rect.Width);
                max_y = (double)(rect.Y + rect.Height);
            }

            json_result += L"\"x\":" + std::to_wstring(min_x) + L",";
            json_result += L"\"y\":" + std::to_wstring(min_y) + L",";
            json_result += L"\"width\":" + std::to_wstring(max_x - min_x) + L",";
            json_result += L"\"height\":" + std::to_wstring(max_y - min_y) + L"}";
        }

        json_result += L"],\"error\":null}";

        std::string result_utf8 = to_utf8(json_result);
        char* result = (char*)malloc(result_utf8.size() + 1);
        strcpy_s(result, result_utf8.size() + 1, result_utf8.c_str());
        return result;

    } catch (const winrt::hresult_error& e) {
        std::string error_msg = to_utf8(e.message());
        std::string error_json = "{\"text\":\"\",\"blocks\":[],\"error\":\"";
        error_json += error_msg;
        error_json += "\"}";
        char* result = (char*)malloc(error_json.size() + 1);
        strcpy_s(result, error_json.size() + 1, error_json.c_str());
        return result;
    } catch (const std::exception& e) {
        std::string error_json = "{\"text\":\"\",\"blocks\":[],\"error\":\"";
        error_json += e.what();
        error_json += "\"}";
        char* result = (char*)malloc(error_json.size() + 1);
        strcpy_s(result, error_json.size() + 1, error_json.c_str());
        return result;
    } catch (...) {
        std::string error_json = "{\"text\":\"\",\"blocks\":[],\"error\":\"Unknown error\"}";
        char* result = (char*)malloc(error_json.size() + 1);
        strcpy_s(result, error_json.size() + 1, error_json.c_str());
        return result;
    }
}

OCR_API void ocr_free_result(char* result) {
    if (result) {
        free(result);
    }
}

OCR_API const char* ocr_version(void) {
    return "Windows.Media.Ocr 1.0";
}

} // extern "C"

#endif // _WIN32
