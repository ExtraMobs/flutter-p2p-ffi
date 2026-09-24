// Package ice GatheringState implementation.
library;

/// GatheringState indicates the state of candidate gathering.
enum GatheringState {
  new_,
  gathering,
  complete;

  String string() {
    switch (this) {
      case GatheringState.new_:
        return 'new';
      case GatheringState.gathering:
        return 'gathering';
      case GatheringState.complete:
        return 'complete';
    }
  }

  @override
  String toString() => string();
}
