import 'package:combinator/combinator.dart';
import 'ast.dart';

class Grammar {
  static final RegExp _id = new RegExp(
      r'[A-Za-z_!",\\+-\\./:;\\?<>%&\\*@\[\]\\{\}\\|`\\^~][A-Za-z0-9_!\\$",\\+-\\./:;\\?<>%&\*@\[\]\\{\}\\|`\\^~]*');

  static final RegExp _doubleQuotedString = new RegExp(
      r'"((\\(["\\/bfnrt]|(u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])))|([^"\\]))*"');

  static final RegExp _singleQuotedString = new RegExp(
      r"'((\\(['\\/bfnrt]|(u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])))|([^'\\]))*'");

  final Parser<IdStringExpression> idString =
      match(_id, errorMessage: 'Expected an ID.')
          .map((r) => new IdStringExpression(r.span.text));

  final Reference<Expression> _callTarget = reference<Expression>();

  final Reference<Expression> _orTarget = reference<Expression>();

  final Parser<SingleQuotedStringExpression> singleQuotedString = match(
          _singleQuotedString,
          errorMessage: 'Expected a single-quoted string.')
      .map((r) => new SingleQuotedStringExpression(r.span.text));

  final Reference<SymbolExpression> symbolExpression =
      reference<SymbolExpression>();

  final Reference<CallExpression> callExpression = reference<CallExpression>();

  final Reference<Map<String, Expression>> environment = reference();

  final Reference<Map<String, Expression>> environmentVariables = reference();

  final Reference<Expression> expression = reference<Expression>();

  Parser<Expression> _compilationUnit;

  Parser<Expression> get compilationUnit =>
      _compilationUnit ??= expression.foldErrors();

  Grammar() {
    _callTarget.parser = longest([
      idString,
      singleQuotedString,
      symbolExpression,
      expression.parenthesized(),
    ]);

    _orTarget.parser = longest([
      idString,
      expression.parenthesized(),
    ]);

    callExpression.parser = chain([
      environmentVariables.space().opt(),
      _callTarget.space().plus(),
    ]).map((r) => new CallExpression(
        r.value[0] ?? {}, r.value[1][0], r.value[1].skip(1).toList()));

    /*
    callExpression.parser = chain([
      environmentVariables.opt(),
      expression.times(2, exact: false),
    ]).map((r) => new CallExpression(
        r.value[0] ?? {}, r.value[0], r.value.skip(1).toList()));
        */
    //callExpression.parser = id.map((r) => new CallExpression({}, r.value, []));

    /*callExpression.parser = chain([
      environmentVariables.opt(),
      expression,
      _callTarget.plus(),
    ]).map((r) =>
        new CallExpression(r.value[0] ?? {}, r.value[1], r.value[2] ?? []));
        */

    environment.parser = chain([
      idString.space().map((r) => r.value.name),
      match('=').space(),
      expression,
    ]).map((r) => {r.value[0]: r.value[2]});

    environmentVariables.parser = environment
        .space()
        .plus()
        .map((r) => r.value.fold({}, (out, map) => out..addAll(map)));

    expression.parser = longest([
      _callTarget,
      callExpression,
      expression.parenthesized(),
    ]);

    symbolExpression.parser = match(r'$')
        .then(
            match(_id, errorMessage: 'Expected an ID.').map((r) => r.span.text))
        .index(1)
        .map((r) => new SymbolExpression(r.value));
  }
}
