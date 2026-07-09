cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# ===== 本地 LLM (llama.cpp) =====
# 编译 meme_llm.so 并链接到可执行文件
set(LOCAL_LLM_DIR "${CMAKE_SOURCE_DIR}/cpp")
if(EXISTS "${LOCAL_LLM_DIR}/CMakeLists.txt" AND EXISTS "${LOCAL_LLM_DIR}/meme_llm.cpp")
  message(STATUS "Including meme_llm build from ${LOCAL_LLM_DIR}")
  add_subdirectory(${LOCAL_LLM_DIR} cpp_build)

  # 链接 meme_llm 到主程序
  if(TARGET meme_llm)
    target_link_libraries(${BINARY_NAME} PRIVATE meme_llm)
    install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
  elseif(TARGET meme_llm_empty)
    target_link_libraries(${BINARY_NAME} PRIVATE meme_llm_empty)
    install(TARGETS meme_llm_empty LIBRARY DESTINATION lib COMPONENT runtime)
  endif()
else()
  message(STATUS "meme_llm source not found at ${LOCAL_LLM_DIR}, skipping local LLM build")
endif()
