part of '../../sort.dart';

const _unknownHint = 0, _increasingHint = 1, _decreasingHint = 2;

final class _Pdq {
  _Pdq(this.less, this.swap);

  final _Less less;
  final _Swap swap;

  void insertionSort(int a, int b) {
    for (var i = a + 1; i < b; i++) {
      for (var j = i; j > a && less(j, j - 1); j--) {
        swap(j, j - 1);
      }
    }
  }

  void siftDown(int lo, int hi, int first) {
    var root = lo;
    for (;;) {
      var child = 2 * root + 1;
      if (child >= hi) break;
      if (child + 1 < hi && less(first + child, first + child + 1)) child++;
      if (!less(first + root, first + child)) return;
      swap(first + root, first + child);
      root = child;
    }
  }

  void heapSort(int a, int b) {
    final first = a, hi = b - a;
    for (var i = (hi - 1) ~/ 2; i >= 0; i--) {
      siftDown(i, hi, first);
    }
    for (var i = hi - 1; i >= 0; i--) {
      swap(first, first + i);
      siftDown(0, i, first);
    }
  }

  void pdqsort(int a, int b, int limit) {
    const maxInsertion = 12;
    var wasBalanced = true, wasPartitioned = true;
    for (;;) {
      final length = b - a;
      if (length <= maxInsertion) {
        insertionSort(a, b);
        return;
      }
      if (limit == 0) {
        heapSort(a, b);
        return;
      }
      if (!wasBalanced) {
        breakPatterns(a, b);
        limit--;
      }
      var (pivot, hint) = choosePivot(a, b);
      if (hint == _decreasingHint) {
        reverseRange(a, b);
        pivot = (b - 1) - (pivot - a);
        hint = _increasingHint;
      }
      if (wasBalanced && wasPartitioned && hint == _increasingHint) {
        if (partialInsertionSort(a, b)) return;
      }
      if (a > 0 && !less(a - 1, pivot)) {
        a = partitionEqual(a, b, pivot);
        continue;
      }
      final (mid, alreadyPartitioned) = partition(a, b, pivot);
      wasPartitioned = alreadyPartitioned;
      final leftLen = mid - a, rightLen = b - mid;
      final balanceThreshold = length ~/ 8;
      if (leftLen < rightLen) {
        wasBalanced = leftLen >= balanceThreshold;
        pdqsort(a, mid, limit);
        a = mid + 1;
      } else {
        wasBalanced = rightLen >= balanceThreshold;
        pdqsort(mid + 1, b, limit);
        b = mid;
      }
    }
  }

  (int, bool) partition(int a, int b, int pivot) {
    swap(a, pivot);
    var i = a + 1, j = b - 1;
    while (i <= j && less(i, a)) {
      i++;
    }
    while (i <= j && !less(j, a)) {
      j--;
    }
    if (i > j) {
      swap(j, a);
      return (j, true);
    }
    swap(i, j);
    i++;
    j--;
    for (;;) {
      while (i <= j && less(i, a)) {
        i++;
      }
      while (i <= j && !less(j, a)) {
        j--;
      }
      if (i > j) break;
      swap(i, j);
      i++;
      j--;
    }
    swap(j, a);
    return (j, false);
  }

  int partitionEqual(int a, int b, int pivot) {
    swap(a, pivot);
    var i = a + 1, j = b - 1;
    for (;;) {
      while (i <= j && !less(a, i)) {
        i++;
      }
      while (i <= j && less(a, j)) {
        j--;
      }
      if (i > j) break;
      swap(i, j);
      i++;
      j--;
    }
    return i;
  }

  bool partialInsertionSort(int a, int b) {
    const maxSteps = 5, shortestShifting = 50;
    var i = a + 1;
    for (var step = 0; step < maxSteps; step++) {
      while (i < b && !less(i, i - 1)) {
        i++;
      }
      if (i == b) return true;
      if (b - a < shortestShifting) return false;
      swap(i, i - 1);
      if (i - a >= 2) {
        for (var j = i - 1; j >= 1; j--) {
          if (!less(j, j - 1)) break;
          swap(j, j - 1);
        }
      }
      if (b - i >= 2) {
        for (var j = i + 1; j < b; j++) {
          if (!less(j, j - 1)) break;
          swap(j, j - 1);
        }
      }
    }
    return false;
  }

  void breakPatterns(int a, int b) {
    final length = b - a;
    if (length < 8) return;
    // xorshift de 64 bits sobre Golang.Uint64 (sem bitwise > 32 bits no JS).
    var r = Golang.Uint64(length);
    // nextPowerOfTwo(length) - 1: máscara de bits.Len(length) bits (< 53).
    final mask = Golang.Uint64((1 << length.bitLength) - 1);
    final mid = a + (length ~/ 4) * 2;
    for (var idx = mid - 1; idx <= mid + 1; idx++) {
      r ^= r << 13;
      r ^= r >> 7;
      r ^= r << 17;
      var other = (r & mask).toInt();
      if (other >= length) other -= length;
      swap(idx, a + other);
    }
  }

  (int, int) choosePivot(int a, int b) {
    const shortestNinther = 50, maxSwaps = 4 * 3;
    final l = b - a;
    final swaps = [0];
    var i = a + l ~/ 4 * 1, j = a + l ~/ 4 * 2, k = a + l ~/ 4 * 3;
    if (l >= 8) {
      if (l >= shortestNinther) {
        i = medianAdjacent(i, swaps);
        j = medianAdjacent(j, swaps);
        k = medianAdjacent(k, swaps);
      }
      j = median(i, j, k, swaps);
    }
    return switch (swaps[0]) {
      0 => (j, _increasingHint),
      maxSwaps => (j, _decreasingHint),
      _ => (j, _unknownHint),
    };
  }

  (int, int) order2(int a, int b, List<int> swaps) {
    if (less(b, a)) {
      swaps[0]++;
      return (b, a);
    }
    return (a, b);
  }

  int median(int a, int b, int c, List<int> swaps) {
    (a, b) = order2(a, b, swaps);
    (b, c) = order2(b, c, swaps);
    (a, b) = order2(a, b, swaps);
    return b;
  }

  int medianAdjacent(int a, List<int> swaps) => median(a - 1, a, a + 1, swaps);

  void reverseRange(int a, int b) {
    for (var i = a, j = b - 1; i < j; i++, j--) {
      swap(i, j);
    }
  }

  void swapRange(int a, int b, int n) {
    for (var i = 0; i < n; i++) {
      swap(a + i, b + i);
    }
  }

  void stable(int n) {
    var blockSize = 20;
    var a = 0, b = blockSize;
    while (b <= n) {
      insertionSort(a, b);
      a = b;
      b += blockSize;
    }
    insertionSort(a, n);
    while (blockSize < n) {
      a = 0;
      b = 2 * blockSize;
      while (b <= n) {
        symMerge(a, a + blockSize, b);
        a = b;
        b += 2 * blockSize;
      }
      final m = a + blockSize;
      if (m < n) symMerge(a, m, n);
      blockSize *= 2;
    }
  }

  void symMerge(int a, int m, int b) {
    if (m - a == 1) {
      var i = m, j = b;
      while (i < j) {
        final h = (i + j) ~/ 2;
        if (less(h, a)) {
          i = h + 1;
        } else {
          j = h;
        }
      }
      for (var k = a; k < i - 1; k++) {
        swap(k, k + 1);
      }
      return;
    }
    if (b - m == 1) {
      var i = a, j = m;
      while (i < j) {
        final h = (i + j) ~/ 2;
        if (!less(m, h)) {
          i = h + 1;
        } else {
          j = h;
        }
      }
      for (var k = m; k > i; k--) {
        swap(k, k - 1);
      }
      return;
    }
    final mid = (a + b) ~/ 2;
    final n = mid + m;
    int start, r;
    if (m > mid) {
      start = n - b;
      r = mid;
    } else {
      start = a;
      r = m;
    }
    final p = n - 1;
    while (start < r) {
      final c = (start + r) ~/ 2;
      if (!less(p - c, c)) {
        start = c + 1;
      } else {
        r = c;
      }
    }
    final end = n - start;
    if (start < m && m < end) rotate(start, m, end);
    if (a < start && start < mid) symMerge(a, start, mid);
    if (mid < end && end < b) symMerge(mid, end, b);
  }

  void rotate(int a, int m, int b) {
    var i = m - a, j = b - m;
    while (i != j) {
      if (i > j) {
        swapRange(m - i, m, j);
        i -= j;
      } else {
        swapRange(m - i, m + j - i, i);
        j -= i;
      }
    }
    swapRange(m - i, m, i);
  }
}
