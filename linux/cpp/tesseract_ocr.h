#ifndef TESSERACT_OCR_H
#define TESSERACT_OCR_H

#ifdef __cplusplus
extern "C" {
#endif

void* tess_create();
void tess_destroy(void* handle);
int tess_init(void* handle, const char* datapath, const char* language);
void tess_end(void* handle);
int tess_set_image_file(void* handle, const char* filename);
char* tess_get_utf8_text(void* handle);
void tess_free_text(char* text);
const char* tess_version();

#ifdef __cplusplus
}
#endif

#endif
