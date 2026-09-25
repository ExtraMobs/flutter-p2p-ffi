"""Precedência de operadores do Dart (maior = liga mais forte)."""

DART_PREC = {
    "*": 14, "/": 14, "~/": 14, "%": 14,
    "+": 13, "-": 13,
    "<<": 12, ">>": 12,
    "&": 11, "^": 10, "|": 9,
    "<": 8, ">": 8, "<=": 8, ">=": 8,
    "==": 7, "!=": 7,
    "&&": 6, "||": 5,
}
NON_ASSOC = frozenset(["<", ">", "<=", ">=", "==", "!="])
POSTFIX = 16  # chamada, seletor, índice, `!`
UNARY = 15
