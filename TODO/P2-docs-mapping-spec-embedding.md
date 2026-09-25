# `mapping-spec.md` diz que a promoção por embedding é ❌

- **Prioridade:** P2 · **Área:** docs
- **Depende de:** —

## Problema

A seção de structs afirma que embedding é campo comum e a promoção é ❌, mas a promoção existe (tabela de classes intermediárias ✅, fixture `embed`).

## Prova

```text
$ sed -n 169,170p docs/mapping-spec.md
- Campos em branco (`_`) ficam fora do construtor e da igualdade. Embedding é
  tratado como campo comum; a promoção é ❌.

$ grep -n Promote tests/golden/embed/embed.dart
101:class Doc extends go.GoStruct<Doc> with Logger$PromotePtr implements Named {
226:mixin Logger$PromotePtr {
```

## Critério de pronto

- Trecho corrigido, apontando para a seção de embedding.
