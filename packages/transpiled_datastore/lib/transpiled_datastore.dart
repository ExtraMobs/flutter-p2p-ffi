// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-datastore`: `key.go`, `datastore.go`, `batch.go`,
/// `basic_ds.go`, `null_ds.go`, `features.go`, and the `query` subpackage.
///
/// The decorator packages (`keytransform`, `namespace`, `sync`, `mount`,
/// `retrystore`, `failstore`, `scoped`, `delayed`, `autobatch`, `trace`,
/// `context`) are not ported yet -- see doc/transpilation/PROGRESS.md.
library;

export 'src/basic_ds.dart' show LogDatastore, MapDatastore, Shim;
export 'src/batch.dart' show BasicBatch;
export 'src/datastore.dart'
    show
        Batch,
        BatchUnsupportedException,
        Batching,
        CheckedDatastore,
        Datastore,
        GcDatastore,
        NotFoundException,
        PersistentDatastore,
        Read,
        ScrubbedDatastore,
        TtlDatastore,
        Txn,
        TxnDatastore,
        Write,
        diskUsage,
        getBackedHas,
        getBackedSize,
        queryIter;
export 'src/features.dart'
    show
        Feature,
        featureByName,
        featureNameBatching,
        featureNameChecked,
        featureNameGc,
        featureNamePersistent,
        featureNameScrubbed,
        featureNameTransaction,
        featureNameTtl,
        features,
        featuresForDatastore;
export 'src/key.dart'
    show Key, entryKeys, namespaceType, namespaceValue, randomKey;
export 'src/null_ds.dart' show NullDatastore;
export 'src/path_clean.dart' show cleanPath;
export 'src/query/filter.dart'
    show
        Filter,
        FilterKeyCompare,
        FilterKeyPrefix,
        FilterOp,
        FilterValueCompare;
export 'src/query/order.dart'
    show
        Order,
        OrderByFunction,
        OrderByKey,
        OrderByKeyDescending,
        OrderByValue,
        OrderByValueDescending,
        compareBytes,
        queryCompare,
        queryLess,
        querySort;
export 'src/query/query.dart'
    show
        Entry,
        Query,
        QueryIterator,
        QueryResult,
        Results,
        ResultsProcess,
        keysOnlyBufSize,
        normalBufSize,
        resultsFromIterator,
        resultsReplaceQuery,
        resultsWithContext,
        resultsWithEntries;
export 'src/query/query_impl.dart'
    show
        naiveFilter,
        naiveLimit,
        naiveOffset,
        naiveOrder,
        naiveQueryApply,
        resultEntriesFrom;
