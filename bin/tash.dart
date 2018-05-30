#!/usr/bin/env dart
import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:tash/tash.dart';

main(List<String> args) async {
  try {
    var argResults = argParser.parse(args);
    var options = new ShellOptions.fromArgResults(argParser.parse(args))
      ..printPrompt = stdin.hasTerminal;
    var group = new StreamGroup<List<int>>();
    Stream<List<int>> input;

    if (argResults.rest.isNotEmpty) {
      input = new File(argResults.rest[0]).openRead();
    } else if (argResults['command'].isNotEmpty) {
      options.printPrompt = false;
      var b = new StringBuffer();
      for (var cmd in argResults['command']) b.writeln(cmd);
      input = new Stream<List<int>>.fromIterable([b.toString().codeUnits]);
    } else {
      var tashrcUri = p.join(Shell.homeDir, '.tashrc');
      var tashrc = new File.fromUri(p.toUri(tashrcUri));
      if (await tashrc.exists())
        group.add(tashrc.openRead());

      input = stdin
        ..echoMode = false
        ..lineMode = false;
    }

    group.add(input);
    var shell = new Shell(group.stream, options);
    await shell.repl();
    exit(shell.exitCode);
  } on ArgParserException catch (e) {
    exit(1);
  }
}
