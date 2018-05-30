import 'package:args/args.dart';

final ArgParser argParser = new ArgParser()
  ..addMultiOption('command', abbr: 'c', help: 'Arbitrary commands to run.');

class ShellOptions {
  final List<String> arguments = [];
  bool printPrompt = true;

  ShellOptions();

  factory ShellOptions.fromArgResults(ArgResults argResults) {
    return new ShellOptions()..arguments.addAll(argResults.rest);
  }
}
