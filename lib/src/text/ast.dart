import 'dart:async';
import 'dart:io';
import 'package:charcode/ascii.dart';
import '../shell.dart';

abstract class Expression {
  Future accept(Shell shell);

  Future acceptStandalone(Shell shell) => accept(shell);
}

abstract class StringExpression extends Expression {
  String get value;

  String processValue(Shell shell) {
    var b = new StringBuffer();

    for (int ch in value.codeUnits) {
      if (ch != $tilde)
        b.writeCharCode(ch);
      else if (ch == $tilde) {
        b.write(shell.homeDir);
      }
    }

    return b.toString();
  }

  @override
  Future accept(Shell shell) async => processValue(shell);

  @override
  Future acceptStandalone(Shell shell) async {
    return await shell.run(processValue(shell), []);
  }
}

class IdStringExpression extends StringExpression {
  final String name;

  IdStringExpression(this.name);

  @override
  String get value => name;
}

class SingleQuotedStringExpression extends StringExpression {
  final String match;

  static final RegExp _unicode = new RegExp(r'\\u([A-Fa-f0-9]+)');
  String _value;

  SingleQuotedStringExpression(this.match);

  @override
  String get value {
    if (_value != null) return _value;

    var t = match.substring(1, match.length - 1);
    t = t
        .replaceAll('\\b', '\b')
        .replaceAll('\\f', '\f')
        .replaceAll('\\r', '\r')
        .replaceAll('\\n', '\n')
        .replaceAll('\\t', '\t')
        .replaceAllMapped(_unicode, (m) {
      new String.fromCharCode(int.parse(m[1], radix: 16));
    });
    return _value = t;
  }

  @override
  Future accept(Shell shell) async {
    return toString();
  }
}

class NumberExpression extends Expression {}

class SymbolExpression extends Expression {
  final String name;

  SymbolExpression(this.name);

  Expression resolve(Shell shell) {
    var symbol = shell.scope.resolve(name);
    return new IdStringExpression(
        symbol?.value?.toString() ?? Platform.environment[name] ?? '');
  }

  @override
  Future acceptStandalone(Shell shell) =>
      resolve(shell).acceptStandalone(shell);

  @override
  Future accept(Shell shell) => resolve(shell).accept(shell);

  @override
  String toString() => '\$$name';
}

class CallExpression extends Expression {
  final Map<String, Expression> environment;
  final Expression target;
  final List<Expression> arguments;

  CallExpression(this.environment, this.target, this.arguments);

  @override
  Future accept(Shell shell) async {
    var target = await this.target.accept(shell);
    var args = <String>[];
    for (var arg in arguments) args.add(await arg.accept(shell));
    return await shell.run(target, args);
  }
}

class AssignmentExpression extends Expression {
  final String id;
  final Expression value;

  AssignmentExpression(this.id, this.value);
}
