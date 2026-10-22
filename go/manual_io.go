// Hand-written (WIRE.md, id 42): any io.Reader handle read to the end as a
// stream of byte pieces, for lib/go/io_stream.dart. The commands already
// stream their readers (emitReader); this is the same for the readers the
// generated API returns (files.File, mfs descriptors...).
package main

import "io"

func init() {
	table[42] = entry{key: "io.Reader.Stream", stream: true, fn: func(q *req, r *reader, _ *writer) error {
		rd, err := decH[io.Reader](r)
		if err != nil {
			return err
		}
		if err := r.done(); err != nil {
			return err
		}
		return readChunks(rd, func(chunk []byte) {
			q.item(func(w *writer) { w.bytes(chunk) })
		})
	}}
}
