import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';
import 'package:charcode/ascii.dart';
import 'options.dart';

class Terminal {
  final Stream<List<int>> stdin;
  final ShellOptions options;
  Future Function(String) lineHandler;
  bool charMode = false;
  String dirname = 'tash) ';
  String workingDirectory = Directory.current.absolute.path;

  final StreamController<int> _charStream = new StreamController.broadcast();
  final List<TerminalLine> _lines = [new TerminalLine()];
  final StreamController<String> _lineStream = new StreamController();
  int _line = 0;
  StreamQueue<int> _chars;

  Terminal(this.stdin, this.options);

  Stream<int> get chars => _charStream.stream;

  Stream<String> get lines => _lineStream.stream;

  void _clearLine() {
    stdout.write('\r');
    for (int i = 0; i < stdout.terminalColumns; i++)
      stdout.writeCharCode($space);
  }

  _listen() async {
    doPrompt();

    while (await _chars.hasNext) {
      if (charMode) {
        _charStream.add(await _chars.next);
        continue;
      }

      var line = _lines[_line];
      int ch = await _chars.next;

      if (ch == $esc) {
        ch = await _chars.next;
        if (ch == $lbracket) ch = await _chars.next;
        if (ch == $A) {
          _line = (_line - 2).clamp(0, _lines.length - 1);
          _clearLine();
          stdout.write('\r');
          doPrompt();
          _lines[_line].write(' ');
        }
        if (ch == $B) {
          _line = (_line + 1).clamp(0, _lines.length - 1);
          _clearLine();
          stdout.write('\r');
          doPrompt();
          _lines[_line].write(' ');
        } else if (ch == $D) {
          line.left();
        }
      } else if (ch == $cr) {
      } else if (ch == $lf) {
        stdout.writeln();
        await lineHandler(line.toString().trim());
        if (_lines.last.isEmpty) {
          _line = _lines.length - 1;
        } else {
          _line = _lines.length;
          _lines.add(new TerminalLine());
        }
        doPrompt();
      } else if (ch == $bs || ch == $del) {
        line.backspace();
        _clearLine();
        stdout.write('\r');
        doPrompt();
        stdout.write(line.toString());
        //line.write(' ');
      } else {
        stdout.writeCharCode(ch);
        line.put(ch);
      }
    }
  }

  void doPrompt() {
    if (options.printPrompt) {
      stdout.write('${Platform.localHostname}:');
      stdout.write('$dirname');
      stdout.write(r'$ ');
    }
  }

  void start() {
    _chars = new StreamQueue(stdin.expand((list) => list));
    _listen();
  }
}

class TerminalLine {
  List<int> _buf = [];
  int _index = 0;

  bool get isEmpty => new String.fromCharCodes(_buf).trim().isEmpty;

  void backspace() {
    _index = _index.clamp(0, _buf.length - 1);
    if (_index < _buf.length) _buf.removeAt(_index);
  }

  void left() {
    _index = (_index - 1).clamp(0, _buf.length - 1);
  }

  void seek(int idx) => _index = idx;

  void put(int ch) {
    if (_index < _buf.length)
      _buf[_index++] = ch;
    else {
      _buf.add(ch);
      _index++;
    }
  }

  void write([String suffix]) {
    stdout.add(_buf);
    if (suffix != null) stdout.write(suffix);
  }

  @override
  String toString() => new String.fromCharCodes(_buf);
}
