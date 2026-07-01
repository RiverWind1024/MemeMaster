// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_pipeline_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AnalysisPipelineConfig {
  /// 颜色提取 — 始终执行，不可关闭
  bool get colorExtraction => throw _privateConstructorUsedError;

  /// OCR 识别 — 用户可选开关
  bool get ocrEnabled => throw _privateConstructorUsedError;

  /// LLM 描述生成 — 用户可选开关
  bool get llmEnabled => throw _privateConstructorUsedError;

  /// 是否已有 embedding 模型（自动检测）
  bool get hasEmbeddingModel => throw _privateConstructorUsedError;

  /// 是否已有 LLM 模型（自动检测）
  bool get hasLlmModel => throw _privateConstructorUsedError;

  /// Create a copy of AnalysisPipelineConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalysisPipelineConfigCopyWith<AnalysisPipelineConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalysisPipelineConfigCopyWith<$Res> {
  factory $AnalysisPipelineConfigCopyWith(
    AnalysisPipelineConfig value,
    $Res Function(AnalysisPipelineConfig) then,
  ) = _$AnalysisPipelineConfigCopyWithImpl<$Res, AnalysisPipelineConfig>;
  @useResult
  $Res call({
    bool colorExtraction,
    bool ocrEnabled,
    bool llmEnabled,
    bool hasEmbeddingModel,
    bool hasLlmModel,
  });
}

/// @nodoc
class _$AnalysisPipelineConfigCopyWithImpl<
  $Res,
  $Val extends AnalysisPipelineConfig
>
    implements $AnalysisPipelineConfigCopyWith<$Res> {
  _$AnalysisPipelineConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalysisPipelineConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? colorExtraction = null,
    Object? ocrEnabled = null,
    Object? llmEnabled = null,
    Object? hasEmbeddingModel = null,
    Object? hasLlmModel = null,
  }) {
    return _then(
      _value.copyWith(
            colorExtraction: null == colorExtraction
                ? _value.colorExtraction
                : colorExtraction // ignore: cast_nullable_to_non_nullable
                      as bool,
            ocrEnabled: null == ocrEnabled
                ? _value.ocrEnabled
                : ocrEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            llmEnabled: null == llmEnabled
                ? _value.llmEnabled
                : llmEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasEmbeddingModel: null == hasEmbeddingModel
                ? _value.hasEmbeddingModel
                : hasEmbeddingModel // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasLlmModel: null == hasLlmModel
                ? _value.hasLlmModel
                : hasLlmModel // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AnalysisPipelineConfigImplCopyWith<$Res>
    implements $AnalysisPipelineConfigCopyWith<$Res> {
  factory _$$AnalysisPipelineConfigImplCopyWith(
    _$AnalysisPipelineConfigImpl value,
    $Res Function(_$AnalysisPipelineConfigImpl) then,
  ) = __$$AnalysisPipelineConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool colorExtraction,
    bool ocrEnabled,
    bool llmEnabled,
    bool hasEmbeddingModel,
    bool hasLlmModel,
  });
}

/// @nodoc
class __$$AnalysisPipelineConfigImplCopyWithImpl<$Res>
    extends
        _$AnalysisPipelineConfigCopyWithImpl<$Res, _$AnalysisPipelineConfigImpl>
    implements _$$AnalysisPipelineConfigImplCopyWith<$Res> {
  __$$AnalysisPipelineConfigImplCopyWithImpl(
    _$AnalysisPipelineConfigImpl _value,
    $Res Function(_$AnalysisPipelineConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalysisPipelineConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? colorExtraction = null,
    Object? ocrEnabled = null,
    Object? llmEnabled = null,
    Object? hasEmbeddingModel = null,
    Object? hasLlmModel = null,
  }) {
    return _then(
      _$AnalysisPipelineConfigImpl(
        colorExtraction: null == colorExtraction
            ? _value.colorExtraction
            : colorExtraction // ignore: cast_nullable_to_non_nullable
                  as bool,
        ocrEnabled: null == ocrEnabled
            ? _value.ocrEnabled
            : ocrEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        llmEnabled: null == llmEnabled
            ? _value.llmEnabled
            : llmEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasEmbeddingModel: null == hasEmbeddingModel
            ? _value.hasEmbeddingModel
            : hasEmbeddingModel // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasLlmModel: null == hasLlmModel
            ? _value.hasLlmModel
            : hasLlmModel // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$AnalysisPipelineConfigImpl extends _AnalysisPipelineConfig {
  const _$AnalysisPipelineConfigImpl({
    this.colorExtraction = true,
    this.ocrEnabled = false,
    this.llmEnabled = false,
    this.hasEmbeddingModel = false,
    this.hasLlmModel = false,
  }) : super._();

  /// 颜色提取 — 始终执行，不可关闭
  @override
  @JsonKey()
  final bool colorExtraction;

  /// OCR 识别 — 用户可选开关
  @override
  @JsonKey()
  final bool ocrEnabled;

  /// LLM 描述生成 — 用户可选开关
  @override
  @JsonKey()
  final bool llmEnabled;

  /// 是否已有 embedding 模型（自动检测）
  @override
  @JsonKey()
  final bool hasEmbeddingModel;

  /// 是否已有 LLM 模型（自动检测）
  @override
  @JsonKey()
  final bool hasLlmModel;

  @override
  String toString() {
    return 'AnalysisPipelineConfig(colorExtraction: $colorExtraction, ocrEnabled: $ocrEnabled, llmEnabled: $llmEnabled, hasEmbeddingModel: $hasEmbeddingModel, hasLlmModel: $hasLlmModel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalysisPipelineConfigImpl &&
            (identical(other.colorExtraction, colorExtraction) ||
                other.colorExtraction == colorExtraction) &&
            (identical(other.ocrEnabled, ocrEnabled) ||
                other.ocrEnabled == ocrEnabled) &&
            (identical(other.llmEnabled, llmEnabled) ||
                other.llmEnabled == llmEnabled) &&
            (identical(other.hasEmbeddingModel, hasEmbeddingModel) ||
                other.hasEmbeddingModel == hasEmbeddingModel) &&
            (identical(other.hasLlmModel, hasLlmModel) ||
                other.hasLlmModel == hasLlmModel));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    colorExtraction,
    ocrEnabled,
    llmEnabled,
    hasEmbeddingModel,
    hasLlmModel,
  );

  /// Create a copy of AnalysisPipelineConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalysisPipelineConfigImplCopyWith<_$AnalysisPipelineConfigImpl>
  get copyWith =>
      __$$AnalysisPipelineConfigImplCopyWithImpl<_$AnalysisPipelineConfigImpl>(
        this,
        _$identity,
      );
}

abstract class _AnalysisPipelineConfig extends AnalysisPipelineConfig {
  const factory _AnalysisPipelineConfig({
    final bool colorExtraction,
    final bool ocrEnabled,
    final bool llmEnabled,
    final bool hasEmbeddingModel,
    final bool hasLlmModel,
  }) = _$AnalysisPipelineConfigImpl;
  const _AnalysisPipelineConfig._() : super._();

  /// 颜色提取 — 始终执行，不可关闭
  @override
  bool get colorExtraction;

  /// OCR 识别 — 用户可选开关
  @override
  bool get ocrEnabled;

  /// LLM 描述生成 — 用户可选开关
  @override
  bool get llmEnabled;

  /// 是否已有 embedding 模型（自动检测）
  @override
  bool get hasEmbeddingModel;

  /// 是否已有 LLM 模型（自动检测）
  @override
  bool get hasLlmModel;

  /// Create a copy of AnalysisPipelineConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalysisPipelineConfigImplCopyWith<_$AnalysisPipelineConfigImpl>
  get copyWith => throw _privateConstructorUsedError;
}
