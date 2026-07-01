enum AnalysisStatus {
  pending,
  processing,
  done,
  failed;

  String get value => name;

  static AnalysisStatus fromString(String value) {
    return AnalysisStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AnalysisStatus.pending,
    );
  }
}
