import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_pipeline_config.freezed.dart';

@freezed
class AnalysisPipelineConfig with _$AnalysisPipelineConfig {
  const AnalysisPipelineConfig._();

  const factory AnalysisPipelineConfig({
    /// 颜色提取 — 始终执行，不可关闭
    @Default(true) bool colorExtraction,

    /// OCR 识别 — 用户可选开关
    @Default(false) bool ocrEnabled,

    /// LLM 描述生成 — 用户可选开关
    @Default(false) bool llmEnabled,

    /// 是否已有 embedding 模型（自动检测）
    @Default(false) bool hasEmbeddingModel,

    /// 是否已有 LLM 模型（自动检测）
    @Default(false) bool hasLlmModel,
  }) = _AnalysisPipelineConfig;

  /// 检查至少有一个分析步骤可以执行
  bool get canAnalyze => colorExtraction;
}
