// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-libp2p-record`.
library;

export 'src/pubkey_validator.dart' show PublicKeyValidator;
export 'src/record.dart' show Record;
export 'src/util.dart' show splitKey;
export 'src/validator.dart'
    show
        BetterRecordException,
        InvalidRecordTypeException,
        NamespacedValidator,
        Validator;
