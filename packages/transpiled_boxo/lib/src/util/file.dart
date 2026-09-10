// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:io';

/// Reports whether [filename] exists, including directories and special files.
bool fileExists(String filename) =>
    FileSystemEntity.typeSync(filename, followLinks: false) !=
    FileSystemEntityType.notFound;
