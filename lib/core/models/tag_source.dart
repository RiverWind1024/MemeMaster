enum TagSource {
  ocr,
  llm,
  color,
  user;

  String get value => name;

  static TagSource fromString(String value) {
    return TagSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TagSource.user,
    );
  }
}
