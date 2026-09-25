// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Erro de limites com a mensagem do runtime Go (sem o prefixo
/// "runtime error: "), igual em todas as plataformas — a indexação de
/// typed data lança RangeError na VM e IndexError no JS.
final class BoundsError extends RangeError {
  BoundsError(this.goMessage) : super(goMessage);

  final String goMessage;
}
