"""Literais Dart a partir de valores Go (funções puras)."""


def double_literal(s):
    """Literal double Dart a partir do %g do Go (1 → 1.0; 1e+06 é válido)."""
    s = str(s)
    return s if any(c in s for c in ".eE") else s + ".0"


def dart_string(s):
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "'":
            out.append("\\'")
        elif ch == "$":
            out.append("\\$")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F:
            out.append(f"\\x{ord(ch):02x}")
        else:
            out.append(ch)
    return "'" + "".join(out) + "'"
