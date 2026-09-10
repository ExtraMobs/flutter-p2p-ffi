// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-ipld-prime`'s `datamodel` package (the IPLD Data Model's
/// core interfaces -- `Node`/`NodeBuilder`/`NodeAssembler`, `Kind`, `Path`,
/// `Link`) and `node/basicnode` (a concrete, general-purpose `Node`
/// implementation for any Data Model value).
///
/// Everything else in go-ipld-prime -- codecs beyond the shared `codec` API
/// and `codec/raw`, advanced linking/storage backends,
/// `traversal`/`traversal/selector`, `schema`/`schema/gen/go` (code
/// generation via Go reflection has no direct Dart equivalent and needs
/// its own design), and the ADL system -- is not ported yet.
library;

export 'fluent/qp.dart';
export 'traversal_selector.dart';
export 'traversal_selector_builder.dart';
export 'traversal_selector_parse.dart';
export 'traversal.dart';
export 'codec_dagjson.dart';

export 'src/basicnode/any_node.dart' show AnyBuilder, PrototypeAny;
export 'src/basicnode/base_node.dart' show BaseAssembler, BaseNode;
export 'src/basicnode/list_node.dart'
    show PlainList, PlainListAssembler, PrototypeList;
export 'src/basicnode/map_node.dart'
    show PlainMap, PlainMapAssembler, PrototypeMap;
export 'src/basicnode/prototypes.dart' show BasicnodePrototype, prototype;
export 'src/basicnode/scalars.dart'
    show
        Basicnode,
        PlainBool,
        PlainBoolAssembler,
        PlainBytes,
        PlainBytesAssembler,
        PlainFloat,
        PlainFloatAssembler,
        PlainInt,
        PlainIntAssembler,
        PlainLink,
        PlainLinkAssembler,
        PlainString,
        PlainStringAssembler,
        PlainUint,
        PrototypeBool,
        PrototypeBytes,
        PrototypeFloat,
        PrototypeInt,
        PrototypeLink,
        PrototypeString;
export 'src/basicnode/stream_bytes.dart' show StreamBytes;
export 'src/basicnode/value_assembler.dart' show ValueAssembler;
export 'src/codec/api.dart'
    show BudgetExhaustedException, Decoder, Encoder, MapSortMode;
export 'src/datamodel/copy.dart' show copyNode;
export 'src/datamodel/equal.dart' show deepEqual;
export 'src/datamodel/errors.dart'
    show
        InvalidSegmentForListException,
        IteratorOverreadException,
        NotExistsException,
        RepeatedMapKeyException,
        WrongKindException;
export 'src/datamodel/kind.dart' show Kind, KindSet;
export 'src/datamodel/link.dart' show Link, LinkPrototype;
export 'src/datamodel/node.dart'
    show
        ByteReadSeeker,
        LargeBytesNode,
        ListIterator,
        MapIterator,
        Node,
        NodePrototype,
        NodePrototypeSupportingAmend,
        SeekOrigin,
        UintNode;
export 'src/datamodel/node_builder.dart'
    show ListAssembler, MapAssembler, NodeAssembler, NodeBuilder;
export 'src/datamodel/null_node.dart' show absentNode, nullNode;
export 'src/datamodel/path.dart' show Path;
export 'src/datamodel/path_segment.dart' show PathSegment;
export 'src/linking/cid/cid_link.dart' show CidLink, CidLinkPrototype;
export 'src/linking/cid/link_system.dart'
    show Memory, defaultLinkSystem, linkSystemUsingMulticodecRegistry;
export 'src/linking/linking.dart';
export 'src/multicodec/registry.dart';
export 'src/storage/memstore.dart' show MemoryStore;
export 'src/storage/storage.dart' hide get;
