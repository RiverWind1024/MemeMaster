# ML Kit 可选语言模块 - google_mlkit_text_recognition 插件在运行时
# 通过 try-catch 动态加载这些语言模块，编译期 R8 会报 Missing class 错误。
# 这些类会在运行时按需加载，不需要在编译期解析。
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ML Kit 官方推荐：保留所有 ML Kit 类，防止 R8 误删反射类
-keep class com.google.mlkit.** { *; }
