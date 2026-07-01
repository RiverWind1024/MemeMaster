import 'dart:math';

import '../database/daos/color_dao.dart';
import '../database/database.dart';

/// CIE Lab 色彩空间中的 ΔE 色差计算
double _deltaE(double l1, double a1, double b1, double l2, double a2, double b2) {
  final dl = l1 - l2;
  final da = a1 - a2;
  final db = b1 - b2;
  return sqrt(dl * dl + da * da + db * db);
}

class ColorRepository {
  final ColorDao _dao;
  ColorRepository(this._dao);

  Future<List<ColorEntry>> getByMemeId(String memeId) =>
      _dao.getByMemeId(memeId);

  /// 颜色搜索：按 ΔE 色差排序
  Future<List<ColorEntry>> searchByColor({
    required double targetL,
    required double targetA,
    required double targetB,
    int limit = 100,
  }) async {
    final allColors = await _dao.getAll();

    // 计算每个颜色与目标色的 ΔE 色差，按色差升序排列
    final scored = allColors.map((c) {
      final de = _deltaE(targetL, targetA, targetB, c.labL, c.labA, c.labB);
      return (color: c, distance: de);
    }).toList();

    scored.sort((a, b) => a.distance.compareTo(b.distance));

    return scored.take(limit).map((s) => s.color).toList();
  }

  /// 获取所有不重复的 meme ID（有颜色数据的）
  Future<List<String>> getAllMemeIds() async {
    final all = await _dao.getAll();
    return all.map((c) => c.memeId).toSet().toList();
  }

  /// 获取所有颜色条目
  Future<List<ColorEntry>> getAll() => _dao.getAll();
}
