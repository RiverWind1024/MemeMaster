import 'dart:io';

import 'package:mememaster/cli/cli_app.dart';

Future<void> main(List<String> args) async {
  exitCode = await CliApp().run(args);
}
