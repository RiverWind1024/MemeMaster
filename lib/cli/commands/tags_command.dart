import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../../core/database/database.dart';
import '../cli_context.dart';
import 'command.dart';

/// tags 命令：管理标签（add / rm / list 子命令）。
class TagsCommand extends CliCommand {
  TagsCommand() : super(name: 'tags', description: '管理标签');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.isEmpty) {
      stderr.writeln('用法: mememaster tags <add|rm|list> ...');
      return 1;
    }
    switch (args.rest.first) {
      case 'add':
        return _add(context, args);
      case 'rm':
        return _rm(context, args);
      case 'list':
        return _list(context, args);
      default:
        stderr.writeln('未知 tags 子命令: ${args.rest.first}');
        return 1;
    }
  }

  /// `tags add <memeId> <tag> [--source custom]`
  Future<int> _add(CliContext context, ArgResults args) async {
    if (args.rest.length < 3) {
      stderr.writeln('用法: mememaster tags add <memeId> <tag> [--source custom]');
      return 1;
    }
    final memeId = args.rest[1];
    final tag = args.rest[2].trim();
    final source = args['source'] as String? ?? 'custom';

    if (await context.findMeme(memeId) == null) {
      stderr.writeln('未找到 meme: $memeId');
      return 1;
    }
    if (tag.isEmpty) {
      stderr.writeln('标签不能为空');
      return 1;
    }

    await context.memeRepo.saveTags([
      TagEntry(
        id: '${memeId}_${source}_${tag.hashCode}',
        memeId: memeId,
        content: tag,
        source: source,
        confidence: 1.0,
      ),
    ]);

    if (context.jsonOutput) {
      print(jsonEncode({
        'success': true,
        'memeId': memeId,
        'tag': tag,
        'source': source,
      }));
    } else {
      print('已添加标签 "$tag"（来源 $source）');
    }
    return 0;
  }

  /// `tags rm <memeId> <tag> [--source custom]`
  Future<int> _rm(CliContext context, ArgResults args) async {
    if (args.rest.length < 3) {
      stderr.writeln('用法: mememaster tags rm <memeId> <tag> [--source custom]');
      return 1;
    }
    final memeId = args.rest[1];
    final tag = args.rest[2].trim();
    final source = args['source'] as String? ?? 'custom';

    if (await context.findMeme(memeId) == null) {
      stderr.writeln('未找到 meme: $memeId');
      return 1;
    }

    // 与 GUI 一致：仅删除指定 source 的标签，避免误删自动标签。
    // 删除后重建剩余标签，避免重复主键冲突。
    final all = await context.memeRepo.getTags(memeId);
    final remaining = all
        .where((t) => !(t.content == tag && t.source == source))
        .toList(growable: false);
    await context.memeRepo.deleteTags(memeId);
    if (remaining.isNotEmpty) {
      await context.memeRepo.saveTags(remaining);
    }

    if (context.jsonOutput) {
      print(jsonEncode({
        'success': true,
        'memeId': memeId,
        'tag': tag,
        'removed': all.length - remaining.length,
      }));
    } else {
      final removed = all.length - remaining.length;
      print(removed == 0 ? '未找到标签 "$tag"' : '已删除标签 "$tag"');
    }
    return 0;
  }

  /// `tags list <memeId>`
  Future<int> _list(CliContext context, ArgResults args) async {
    if (args.rest.length < 2) {
      stderr.writeln('用法: mememaster tags list <memeId>');
      return 1;
    }
    final memeId = args.rest[1];

    if (await context.findMeme(memeId) == null) {
      stderr.writeln('未找到 meme: $memeId');
      return 1;
    }

    final tags = await context.memeRepo.getTags(memeId);

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final t in tags)
          {'content': t.content, 'source': t.source, 'confidence': t.confidence},
      ]));
      return 0;
    }

    if (tags.isEmpty) {
      print('（无标签）');
      return 0;
    }
    for (final t in tags) {
      print('${t.content}  (${t.source})');
    }
    return 0;
  }
}
