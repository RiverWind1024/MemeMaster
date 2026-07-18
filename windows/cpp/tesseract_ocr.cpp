// tesseract_ocr.cpp
//
// This file documents the Tesseract FFI interface for Windows.
// Tesseract functions are called directly via dart:ffi DynamicLibrary.open()
// from the pre-built DLLs in third_party/tesseract-dlls/
//
// No compile-time linking is needed - DLLs are loaded at runtime via FFI.
//
// Pre-built DLL source:
// https://github.com/simonflueckiger/tesserocr-windows_build/releases
//
// The release package includes:
//   - tesseract*.dll    (Tesseract OCR engine)
//   - leptonica*.dll    (Image processing library)
//   - libpng*.dll       (PNG image support)
//   - libjpeg*.dll      (JPEG image support)
//   - libtiff*.dll      (TIFF image support)
//   - zlib*.dll         (Compression support)
//
// Usage from Dart:
//
//   import 'dart:ffi';
//   import 'dart:io';
//
//   final dllDir = Directory('third_party/tesseract-dlls');
//   final tessDll = DynamicLibrary.open(
//     File(p.join(dllDir.path, 'tesseract*.dll')).pathSync()
//   );
//
//   // Tesseract API functions (via FFI):
//   //   TessBaseAPICreate
//   //   TessBaseAPIInit3
//   //   TessBaseAPISetImage
//   //   TessBaseAPIGetUTF8Text
//   //   TessBaseAPIClose
//   //   TessBaseAPIDelete
//   //   ... etc
//
// This file serves as documentation only. It is not compiled into meme_llm.dll.
// The Tesseract DLLs are standalone and loaded independently by the OCR service.
//
// See also:
//   - windows/cpp/tesseract_ocr.h (FFI bindings definition)
//   - lib/services/ocr_service.dart (Dart OCR service using FFI)

#ifdef __cplusplus
extern "C" {
#endif

// Stub export - keeps the compiler happy if this file is compiled alone
// This function does nothing; actual Tesseract calls go through FFI.
DLL_EXPORT void tesseract_ocr_stub(void) {
    // No-op stub
    // Tesseract is loaded via dart:ffi DynamicLibrary.open(), not via this DLL.
}

#ifdef __cplusplus
}
#endif
