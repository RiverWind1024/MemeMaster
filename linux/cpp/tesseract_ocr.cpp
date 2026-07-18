#include "tesseract_ocr.h"

#include <tesseract/baseapi.h>
#include <leptonica/allheaders.h>

#include <stdlib.h>
#include <string.h>

extern "C" {

void* tess_create() {
    return new tesseract::TessBaseAPI();
}

void tess_destroy(void* handle) {
    if (handle) {
        delete static_cast<tesseract::TessBaseAPI*>(handle);
    }
}

int tess_init(void* handle, const char* datapath, const char* language) {
    if (!handle) return -1;
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    return api->Init(datapath, language) ? 0 : -1;
}

void tess_end(void* handle) {
    if (!handle) return;
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    api->End();
}

int tess_set_image_file(void* handle, const char* filename) {
    if (!handle || !filename) return -1;
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    Pix* image = pixRead(filename);
    if (!image) return -1;
    api->SetImage(image);
    return 0;
}

char* tess_get_utf8_text(void* handle) {
    if (!handle) return nullptr;
    tesseract::TessBaseAPI* api = static_cast<tesseract::TessBaseAPI*>(handle);
    char* text = api->GetUTF8Text();
    return text;
}

void tess_free_text(char* text) {
    if (text) {
        delete[] text;
    }
}

const char* tess_version() {
    return TESSERACT_VERSION;
}
