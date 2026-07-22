// windows_ocr.h
//
// C API 封装 Windows.Media.Ocr
// 封装层使得 Dart ffi 可以调用 Windows OCR
//
// 使用方法 (Dart):
//   typedef OcrCreateNative = Pointer<Void> Function();
//   typedef OcrRecognizeNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
//
//   final dylib = DynamicLibrary.open('windows_ocr.dll');
//   final create = dylib.lookupFunction<OcrCreateNative, OcrCreateDart>('ocr_create');
//   final recognize = dylib.lookupFunction<OcrRecognizeNative, OcrRecognizeDart>('ocr_recognize');
//
//   final handle = create();
//   final result = recognize(handle, imagePath.toNativeUtf8());
//   // result 是 JSON: { "text": "...", "blocks": [...] }

#ifndef WINDOWS_OCR_H
#define WINDOWS_OCR_H

#ifdef _WIN32
#ifdef WINDOWS_OCR_EXPORTS
#define OCR_API __declspec(dllexport)
#else
#define OCR_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

// 创建 OCR 引擎
// 返回: OCR 引擎句柄，失败返回 NULL
OCR_API void* ocr_create(void);

// 销毁 OCR 引擎
OCR_API void ocr_destroy(void* handle);

// 识别图片中的文字
// handle: ocr_create() 返回的句柄
// imagePath: 图片文件路径 (UTF-8)
// 返回: JSON 字符串，格式如下:
//   {
//     "text": "识别出的完整文本",
//     "blocks": [
//       {
//         "text": "文本块内容",
//         "x": 0.0,        // 左上角 X (归一化坐标 0-1)
//         "y": 0.0,        // 左上角 Y (归一化坐标 0-1)
//         "width": 0.5,    // 宽度 (归一化坐标)
//         "height": 0.1    // 高度 (归一化坐标)
//       }
//     ],
//     "error": null       // 错误信息，无错误时为 null
//   }
// 返回值需要调用 ocr_free_result() 释放
OCR_API char* ocr_recognize(void* handle, const char* imagePath);

// 释放 ocr_recognize 返回的字符串
OCR_API void ocr_free_result(char* result);

// 获取版本信息
OCR_API const char* ocr_version(void);

#ifdef __cplusplus
}
#endif

#endif // _WIN32
#endif // WINDOWS_OCR_H
