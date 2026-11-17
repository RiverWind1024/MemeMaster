# S3 同步 v2 —— 设计文档

日期：2026-10-10

## 背景与问题

现有 S3 同步同时存在两套互不兼容的元数据格式，且各操作只认其中一套，导致实际数据无法正确恢复：

- **全量上传**（`uploadAll`）：写 `snapshot-v1.json` + `data/memes.json` + `data/albums.json` + 图片 `memes/<hash><ext>`
- **增量同步**（`incremental`）：写单条文件 `data/memes/<id>.json` + 图片（不写快照）
- **全量下载**（`downloadAll`）：**只读 `snapshot-v1.json`**，忽略 `data/memes/*.json`

实测故障（桶 `meme-jzf`，694 个对象）：

| 对象 | 数量 | 说明 |
|---|---|---|
| `memes/<hash>.*` | 356 | 图片 |
| `data/memes/<id>.json` | 335 | 333 条正常 meme + 2 条墓碑 |
| `snapshot-v1.json` / `data/memes.json` | 2 | **只含 6 条 meme（被全量上传覆盖）** |
| `data/albums.json` | 1 | 相册 |

结果：全量下载只恢复 6 条，而 S3 实际有 333 条（另一批），且存储统计显示 694（裸对象数），三者完全对不上。

根因：
1. 两套格式并存，全量下载只认快照；
2. 全量上传会**静默把快照覆盖**成"当前本地全部"，且从不清理远端旧图片/旧文件 → 产生孤儿对象；
3. 进度 `total = memes.length + 1` 把"元数据导入"算作一步，造成 `6 → 7` 的误解；
4. 存储统计口径是裸对象数，不是可用数据量。

另一个隐患：**标签/颜色/相册归属的修改不会更新 meme 的 `updatedAt`**（`saveTags`/`saveColors` 直接写子表，见 `meme_repository.dart:289,299`），按 `updatedAt` 做差异会漏判"只改了标签"的情况。

## 目标与非目标

目标：

- 单一权威格式（manifest 索引 + 单条文件 + 内容寻址图片），彻底消除双格式分裂；
- 支持多设备**双向**同步，冲突采用 **LWW（最后写入获胜）**；
- 同步范围：图片、meme 元数据、标签/颜色、相册与归属、用户统计；**不含向量 embedding**；
- **仅手动触发**同步，不做后台/定时；
- 一次 GET 算出全部差异，可扩展；
- 可测试：同步逻辑与具体对象存储解耦。

非目标：

- 字段级合并、冲突副本保留（已确认用 LWW）；
- 后台/自动/定时同步；
- embedding 跨设备同步；
- 保留旧格式读取的自动迁移代码（改用一次性数据迁移，见下）。

## Bucket 数据布局（v2）

```
sync/manifest.json          # 权威索引：一次 GET 拿到全部差异
sync/memes/<id>.json        # 单条 meme 全量（元数据 + tags + colors + albumIds）
sync/albums/<id>.json       # 单条相册
sync/user_stats.json        # 用户统计（按天）
blobs/<sha256>              # 图片本体，内容寻址（天然去重，永不重复上传）
```

manifest 结构（小文件，数百~数千条都很轻）：

```json
{
  "schema": 2,
  "generatedAt": 1720000000000,
  "lastWriter": "<deviceId>",
  "clock": 1720000000000,
  "memes":  { "<id>": { "updatedAt": 1720000000000, "deletedAt": null, "hash": "<sha256>", "ext": ".jpg" } },
  "albums": { "<id>": { "updatedAt": 1720000000000, "deletedAt": null } },
  "userStats": { "updatedAt": 1720000000000 }
}
```

要点：

- **meme 是最小同步单元**，tags/colors/相册归属内联进 meme json；
- 图片按 `hash` 寻址，同哈希即同图，跨设备/跨版本自动去重；
- 旧格式（`snapshot-v1.json`、`data/*`、`memes/*`）不再读取。

## 同步单元与元数据

- 统一 `updatedAt` 语义：**任何影响该 meme 同步内容的操作都要 bump 父 meme 的 `updatedAt`**，包括改标签、改颜色、加入/移出相册。实现上让 `saveTags`/`saveColors`/相册归属变更顺带更新父 meme 的 `updatedAt`。
- 新增持久化 **`deviceId`**（首次生成后固定），仅用于冲突兜底与调试。
- 引入**逻辑时钟** `clock`：写本地改动时 `updatedAt = max(系统时间, clock + 1)`；拉到远端更大时间戳时把 `clock` 前移。缓解设备系统时间偏差导致的 LWW 误判。
- 删除用墓碑（`deletedAt`），manifest 中保留，供其它设备传播删除。

## 同步算法（手动触发，三阶段）

一次"增量同步"（默认推荐）流程：

**阶段 0 — 准备**

- `GET sync/manifest.json`；404 视为首次同步（远端空）。

**阶段 1 — 推送本地变更**

- 遍历本地所有 meme（含墓碑），与 manifest 比对：
  - 不在 manifest，或 `local.updatedAt > remote.updatedAt` → 上传实体 json（图片若 `blobs/<hash>` 不存在则上传）；
  - 本地已软删除但 manifest 未标记 → 上传墓碑 json。

**阶段 2 — 拉取远端变更**

- 对 manifest 每条与本地比对：
  - 本地不存在，或 `remote.updatedAt > local.updatedAt` → 下载 json + 图片并落库（LWW 远端赢）；
  - `remote.deletedAt != null` 且本地未删 → 本地软删除；
  - 时间戳相同 → 无变化，不动作。

**阶段 3 — 收敛**

- `PUT sync/manifest.json`：合并索引（每条取两边 `max(updatedAt)`、`deletedAt` 取非空、`clock` 前移）；
- 更新本地 `sync_state`。

约束：

- **冲突**：纯 LWW（`updatedAt` 大者赢，平局保持本地不动）；
- **幂等**：三阶段可重复执行无副作用；
- **并发**：两设备同时写 manifest 时"后写覆盖"，但实体文件粒度更细，下次同步自愈；
- **失败处理**：单个实体失败只记录并跳过，不中断整轮；结束报告"成功 N / 失败 M"；网络中断直接重跑。

## 迁移（一次性数据转换，agent 侧执行）

不保留旧格式读取代码。迁移在数据层完成：

1. 从 S3 拉全部旧对象到本地临时目录（安全备份，已完成：694 文件 / 93 MB）；
2. 本地合并两套旧格式为权威集合：`snapshot` 里的 6 条 + `data/memes/*.json` 里的 333 条 = 339 条，2 条墓碑保留；
3. 按 v2 布局在本地生成 `sync/manifest.json`、`sync/memes/<id>.json`、`sync/albums/<id>.json`、`blobs/<hash>`；
4. 上传 v2 对象到 S3；
5. 删除旧键（`snapshot-v1.json`、`data/*`、`memes/*`），**不单独清空桶**，避免出现空桶窗口。

已知限制：那 333 条单条文件里不含相册/相册归属信息（旧增量同步从不写相册），只有 6 条的 snapshot 含相册，故迁移出的相册数据仅覆盖该部分，属旧逻辑历史遗留。

## 统计口径与 UI

- **S3 占用**（`getStorageStats`）分项展示：对象总数、总字节、**已引用图片数 / 未引用(孤儿)图片数**、元数据文件数；另提供"清理未引用图片"维护动作（删除 hash 不在 manifest 中引用的 `blobs/*`，并顺带清理遗留旧键）。
- 同步按钮语义：
  - 「增量同步」= 三阶段双向 LWW（默认，日常用）；
  - 「全量上传」= 强制把本地全部推成权威（配合清空后重建）；
  - 「全量下载」= 以云端为准重建本地（危险，二次确认）。
- 进度：把"元数据导入"从总数中移除，按"实体数 + 图片数"计；完成时提示"新增 X / 更新 Y / 删除 Z / 图片上传 P"。

## 可测试性改造

将 `S3SyncService` 对 `Minio` 的直接依赖抽成接口：

```dart
abstract class ObjectStore {
  Future<void> put(String key, Stream<List<int>> data, {required int size});
  Future<Stream<List<int>>?> get(String key);   // null = 不存在
  Future<bool> exists(String key);
  Future<List<String>> list(String prefix);
  Future<void> delete(String key);
}
```

- 生产实现 `MinioObjectStore`；测试实现 `InMemoryObjectStore`；
- 同步逻辑只依赖该接口，可在无网络、无 Dart 插件下全量单测三阶段算法、LWW、墓碑、孤儿清理；
- 复用现有 `test/cli/` 的纯 Dart 测试模式。

## 改动文件（预估）

- `lib/services/s3_sync_service.dart`：重写为三阶段 v2 算法，依赖 `ObjectStore`
- `lib/services/object_store.dart`（新）：`ObjectStore` 接口 + `MinioObjectStore`
- `lib/services/s3_sync_serializer.dart`：v2 实体序列化（内联 tags/colors/albumIds、manifest 读写）
- `lib/services/s3_config.dart` / `s3_secret_store.dart`：`deviceId` 持久化
- `lib/core/database/daos/meme_dao.dart`、`tag_dao.dart`、`color_dao.dart`、`album_dao.dart`：子数据变更 bump 父 meme `updatedAt` / 相册 `updatedAt`
- `lib/features/settings/s3_sync_screen.dart`：按钮语义、进度、统计分项、危险操作确认
- `lib/l10n/*`：新增文案
- `test/`：`InMemoryObjectStore` + 同步算法单测

## 测试策略

- 单元测试（纯 Dart，`InMemoryObjectStore`）：
  - 首次上传/下载全量往返一致；
  - 双向 LWW：新者覆盖旧者、平局不动；
  - 标签/颜色/相册归属变更被正确识别（bump 生效）；
  - 墓碑传播删除；
  - 孤儿图片识别与清理；
  - manifest 缺失（首次同步）分支。
- 手工验证：手机与桌面各一台，分别导入/改标签/删图，验证双向一致。

## 风险与权衡

- **LWW + 时钟**：跨设备系统时间偏差可能误判，用逻辑时钟 `clock` 前移缓解；极端场景接受"较新改动被较旧时间戳覆盖"的个人库级风险。
- **manifest 并发写**：手动触发 + 实体文件细粒度使冲突自愈；不做条件写（七牛兼容性未知）。
- **孤儿图片**：默认不自动删除，提供显式维护动作，避免误删别设备尚未拉取的图片。
