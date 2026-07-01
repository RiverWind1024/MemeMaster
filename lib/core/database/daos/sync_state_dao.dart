import '../database.dart';

/// 同步状态持久化 DAO
///
/// 管理 SyncStateTable 中三个 key:
/// - last_sync_at: 上次同步时间戳
/// - last_snapshot_version: 上次快照版本号
/// - last_pull_at: 上次拉取时间戳
class SyncStateDao {
  final AppDatabase _db;

  SyncStateDao(this._db);

  Future<String?> get(String id) async {
    final row = await (_db.select(_db.syncStateTable)
      ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String id, String value) async {
    await _db.into(_db.syncStateTable).insertOnConflictUpdate(
      SyncStateEntry(
        id: id,
        value: value,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<int?> getLastSyncAt() async {
    final v = await get('last_sync_at');
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setLastSyncAt(int timestamp) =>
      set('last_sync_at', timestamp.toString());

  Future<int?> getLastSnapshotVersion() async {
    final v = await get('last_snapshot_version');
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setLastSnapshotVersion(int version) =>
      set('last_snapshot_version', version.toString());

  Future<void> reset() async {
    await (_db.delete(_db.syncStateTable)).go();
  }
}
