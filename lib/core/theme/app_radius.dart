/// 全局圆角尺度。
///
/// 原先全项目散落着 2/4/6/8/10/12/14/16/18/22/28 等十余种取值，同类元素
/// 彼此不一致。这里约定四档 + 胶囊，统一引用，避免魔数。
class AppRadius {
  AppRadius._();

  /// 微型元素：进度条、细分隔条、微型色块。
  static const double xs = 4;

  /// 小控件：chip、小图标容器、小标签、小提示框。
  static const double sm = 8;

  /// 常规控件：按钮、输入框、列表项、小卡片。
  static const double md = 12;

  /// 卡片、图片、中等容器。
  static const double lg = 16;

  /// 大容器：dialog、bottom sheet、全宽面板。
  static const double xl = 20;

  /// 完全胶囊形（搜索框、pill 按钮）。
  static const double pill = 999;
}
