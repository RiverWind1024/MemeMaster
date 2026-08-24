import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../cli_context.dart';
import 'command.dart';

/// albums 命令：管理相册（list/create/rename/delete/add/rm 子命令）。
class AlbumsCommand extends CliCommand {
  AlbumsCommand() : super(name: 'albums', description: '管理相册');

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.isEmpty) {
      stderr.writeln(
          '用法: mememaster albums <list|create|rename|delete|add|rm> ...');
      return 1;
    }
    switch (args.rest.first) {
      case 'list':
        return _list(context, args);
      case 'create':
        return _create(context, args);
      case 'rename':
        return _rename(context, args);
      case 'delete':
        return _delete(context, args);
      case 'add':
        return _addMeme(context, args);
      case 'rm':
        return _removeMeme(context, args);
      default:
        stderr.writeln('未知 albums 子命令: ${args.rest.first}');
        return 1;
    }
  }

  /// albums list
  Future<int> _list(CliContext context, ArgResults args) async {
    final albums = await context.albumRepo.getAll();

    if (context.jsonOutput) {
      print(jsonEncode([
        for (final a in albums)
          {
            'id': a.id,
            'name': a.name,
            'isDefault': a.isDefault,
            'sortOrder': a.sortOrder,
            'createdAt': a.createdAt,
            'icon': a.icon,
          },
      ]));
      return 0;
    }

    print('共 ${albums.length} 个相册');
    for (final a in albums) {
      final marker = a.isDefault == 1 ? '（默认）' : '';
      print('${a.name}  $marker${a.id}');
    }
    return 0;
  }

  /// `albums create <name>`
  Future<int> _create(CliContext context, ArgResults args) async {
    if (args.rest.length < 2 || args.rest[1].trim().isEmpty) {
      stderr.writeln('用法: mememaster albums create <name>');
      return 1;
    }
    final name = args.rest[1].trim();

    final album = await context.albumRepo.create(name: name);

    if (context.jsonOutput) {
      print(jsonEncode({'success': true, 'id': album.id, 'name': album.name}));
    } else {
      print('已创建相册 "${album.name}" (id: ${album.id})');
    }
    return 0;
  }

  /// `albums rename <id> <name>`
  Future<int> _rename(CliContext context, ArgResults args) async {
    if (args.rest.length < 3 || args.rest[2].trim().isEmpty) {
      stderr.writeln('用法: mememaster albums rename <id> <name>');
      return 1;
    }
    final id = args.rest[1];
    final name = args.rest[2].trim();

    if (await context.albumRepo.getById(id) == null) {
      stderr.writeln('未找到相册: $id');
      return 1;
    }

    await context.albumRepo.rename(id, name);

    if (context.jsonOutput) {
      print(jsonEncode({'success': true, 'id': id, 'name': name}));
    } else {
      print('已重命名相册为 "$name"');
    }
    return 0;
  }

  /// `albums delete <id>`
  Future<int> _delete(CliContext context, ArgResults args) async {
    if (args.rest.length < 2) {
      stderr.writeln('用法: mememaster albums delete <id>');
      return 1;
    }
    final id = args.rest[1];

    if (await context.albumRepo.getById(id) == null) {
      stderr.writeln('未找到相册: $id');
      return 1;
    }

    await context.albumRepo.delete(id);

    if (context.jsonOutput) {
      print(jsonEncode({'success': true, 'id': id}));
    } else {
      print('已删除相册');
    }
    return 0;
  }

  /// `albums add <memeId> <albumId>`
  Future<int> _addMeme(CliContext context, ArgResults args) async {
    if (args.rest.length < 3) {
      stderr.writeln('用法: mememaster albums add <memeId> <albumId>');
      return 1;
    }
    final memeId = args.rest[1];
    final albumId = args.rest[2];

    if (await context.memeRepo.getById(memeId) == null) {
      stderr.writeln('未找到 meme: $memeId');
      return 1;
    }
    if (await context.albumRepo.getById(albumId) == null) {
      stderr.writeln('未找到相册: $albumId');
      return 1;
    }

    await context.albumRepo.addMemeToAlbum(memeId, albumId);

    if (context.jsonOutput) {
      print(jsonEncode({
        'success': true,
        'memeId': memeId,
        'albumId': albumId,
      }));
    } else {
      print('已将 meme $memeId 添加到相册 $albumId');
    }
    return 0;
  }

  /// `albums rm <memeId> <albumId>`
  Future<int> _removeMeme(CliContext context, ArgResults args) async {
    if (args.rest.length < 3) {
      stderr.writeln('用法: mememaster albums rm <memeId> <albumId>');
      return 1;
    }
    final memeId = args.rest[1];
    final albumId = args.rest[2];

    if (await context.memeRepo.getById(memeId) == null) {
      stderr.writeln('未找到 meme: $memeId');
      return 1;
    }
    if (await context.albumRepo.getById(albumId) == null) {
      stderr.writeln('未找到相册: $albumId');
      return 1;
    }

    await context.albumRepo.removeMemeFromAlbum(memeId, albumId);

    if (context.jsonOutput) {
      print(jsonEncode({
        'success': true,
        'memeId': memeId,
        'albumId': albumId,
      }));
    } else {
      print('已将 meme $memeId 从相册 $albumId 移除');
    }
    return 0;
  }
}
