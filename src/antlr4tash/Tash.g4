grammar Tash;

program: statement*;

statement:
    expression #ExpressionStatement
    | callee=expression '[' index=expression ']' #IndexExpression
    | '[' (expression ','?)* ']' #ArrayExpression
    | 'return' expression #ReturnStatement
    | 'export'? ID '=' expression #IdentifierAssignmentStatement
    | 'scope' ('(' (scopeParameter ','*)* ')')? block #ScopeStatement
    | block #BlockStatement
;

scopeParameter: ID '=' expression;

block:
    '=>' expression #ArrowBlock
    | '{' statement* '}' #NormalBlock
;

expression:
    ID #IdExpression
    | '/'* (pathSegment? '/')* pathSegment #FilePathExpression
    | left=expression '>' right=expression #FileWriteRedirectExpression
    | left=expression '>>' right=expression #FileAppendRedirectExpression
    | left=expression '|' right=expression #PipeExpression
    | left=expression '&&' right=expression #ThenExpression
    | left=expression '&' right=expression #ConcurrencyExpression
    | callee=expression '('? (arguments+=expression ','*)* ')' #ExplicitCallStatement
    | callee=expression (arguments+=expression ','*)+  #ImplicitCallStatement
    | '(' expression ')' #ParenthesizedExpression
;

pathSegment:
    '.' #CurrentDirectoryPathSegment
    | '..' #ParentDirectoryPathSegment
    | '$' ID #IdentifierPathSegment
    | '$' '(' expression ')' #ExpressionPathSegment
    | '~' username=ID? #HomePathSegment
    | SINGLE_STRING #SingleStringPathSegment
    | DOUBLE_STRING #DoubleStringPathSegment
    | TILDE_STRING #TildeStringPathSegment
    | (ID '.')+ ID #DottedNamePathSegment
    | ID #RegularPathSegment;

WS: [ \n\r\t]+ -> skip;
COMMENT: '#'(~'\n')* -> skip;
SINGLE_STRING: '"' (('\\"') | ~('"' | '\n') )* '"';
DOUBLE_STRING: '\'' (('\\\'') | ~('\'' | '\n') )* '\'';
TILDE_STRING: '`' (('\\`') | ~('`' | '\n') )* '`';
ID: [A-Za-z_][A-Za-z0-9]*;