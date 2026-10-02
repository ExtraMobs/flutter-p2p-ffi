# Método ausente em tipo de shim gera Dart inválido

- **Prioridade:** P1 · **Área:** infra
- **Depende de:** —

## Problema

`python -m g2d shims` lista os símbolos de nível de pacote de cada shim, e o
g2d recusa (`shim-simbolo:`) o que não está lá. Métodos de tipos de shim
(`time.Time.Format`, `bytes.Buffer.X`...) não passam por essa conferência: o
g2d emite a chamada e o `dart analyze` falha. Pela regra do projeto, isso
devia ser `Unsupported`, nunca Dart inválido. Hoje o audit mostra 0
`dart-invalido` porque os pacotes que chamam esses métodos param antes, mas
o buraco aparece assim que o shim do pacote anterior entrar.

## Prova

Ver o repro de `P1-shim-time-layout.md`: `t.Format("2006-01-02")` passa pelo
g2d sem `Unsupported` e o `dart analyze` acusa `The method 'format' isn't
defined for the type 'Time'`.

## Critério de pronto

- `python -m g2d shims` também registra os métodos (e campos) de cada tipo
  de shim; chamada fora dessa lista vira `Unsupported`
  `shim-simbolo:time.Time.Format` (ou forma equivalente).
- Teste em `tests/test_engine.py`; audit regerado.
