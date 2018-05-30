import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:string_scanner/string_scanner.dart';
import 'package:symbol_table/symbol_table.dart';
import 'text/text.dart';
import 'options.dart';
import 'terminal.dart';

class Shell {
  final Grammar grammar = new Grammar();
  final Terminal terminal;
  final ShellOptions options;
  int exitCode = 0;
  SymbolTable scope = new SymbolTable();

  static String get homeDir => Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];

  Shell(Stream<List<int>> stdin, this.options)
      : terminal = new Terminal(stdin, options) {
    terminal.dirname = p.basename(Directory.current.absolute.path);

    scope.create('cd', constant: true, value: (List args) {
      if (args.isNotEmpty) {
        Directory.current = args[0].toString();
        terminal.dirname = p.basename(Directory.current.absolute.path);
      }
    });

    scope.create('enter', constant: true, value: (List args) {
      scope = scope.createChild();
    });

    scope.create('exit', constant: true, value: (List args) {
      if (!scope.isRoot) {
        scope = scope.parent;
      } else {
        var ec = 0;
        if (args.isNotEmpty) {
          if (args[0] is num)
            ec = args[0].toInt();
          else
            ec = int.tryParse(args[0]) ?? ec;
        }

        exit(ec);
      }
    });
  }

  Future run(String command, List args) async {
    var symbol = scope.resolve(command);

    if (symbol != null) {
      if (symbol.value is! Function) {
        print('${symbol
            .value} is not a function, and therefore cannot be called.');
      } else {
        var fn = symbol.value as Function;
        return await fn(args);
      }
    } else {
      return Process.start(command, args.map((a) => a.toString()).toList());
    }
  }

  void normalizePrompt() {
    if (p.equals(Directory.current.absolute.path, p.absolute(homeDir)))
      terminal.dirname = '~';
    else
      terminal.dirname = p.basename(Directory.current.absolute.path);
  }

  Future repl() async {
    normalizePrompt();

    terminal.lineHandler = (line) async {
      if (line.isEmpty) return;
      var result = grammar.compilationUnit.parse(new SpanScanner(line));
      if (result.errors.isNotEmpty) {
        for (var err in result.errors) {
          print(err.toolString);
        }
      } else {
        try {
          var r = await result.value.acceptStandalone(this);

          if (r is Process) {
            var sub = terminal.chars.listen((ch) {
              stdout.writeCharCode(ch);
              r.stdin.writeCharCode(ch);
            });
            terminal.charMode = true;
            r.stdout.forEach(stdout.add);
            r.stderr.forEach(stderr.add);
            exitCode = await r.exitCode;
            terminal.charMode = false;
            sub.cancel();
            //stdout.writeln();
          } else if (r != null) print(r);
        } catch (e) {
          print(e);
          exitCode = 1;
        }
      }

      normalizePrompt();
    };

    terminal.start();

    await terminal.lines.toList();
  }
}
