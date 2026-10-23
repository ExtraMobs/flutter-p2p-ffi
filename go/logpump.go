// The standard log of the p2p_host (log.Printf: mDNS's zeroconf warns through
// it) never blocks: the app reads the host's stderr on its event loop, which
// does not run while the app waits on a synchronous call. A Go function that
// logs from a goroutine the call waits for (mdns Close waits for a responder
// that warns) would block on the full pipe, and the call with it.
package main

import (
	"io"
	"log"
	"os"
)

// logPump: lines queue here and a goroutine writes them to stderr; when the
// queue is full the line is dropped.
// ponytail: only the standard log; go-log (kubo, libp2p) writes to stderr
// directly, at error level by default.
type logPump chan []byte

func (p logPump) Write(b []byte) (int, error) {
	select {
	case p <- append([]byte(nil), b...):
	default:
	}
	return len(b), nil
}

func pumpLog(to io.Writer) {
	p := make(logPump, 1024)
	go func() {
		for b := range p {
			_, _ = to.Write(b)
		}
	}()
	log.SetOutput(p)
}

func init() { pumpLog(os.Stderr) }
