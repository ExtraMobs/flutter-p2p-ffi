package gen

func AsSlice[T any](v []T) []T { return append([]T(nil), v...) }

type Pair[K comparable, V any] struct {
	K K
	V V
}

func New[K comparable, V any](k K, v V) *Pair[K, V] { return &Pair[K, V]{k, v} }
