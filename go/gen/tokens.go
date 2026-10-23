package main

import (
	"fmt"
	"go/types"
	"sort"
)

// anyTypes: exposed struct types that cross inside a dynamic value (any), both
// ways (WIRE.md, "Value encoding"): Go → Dart as their class (the events out of
// the event bus's `chan any`), Dart → Go as a token that Go turns into
// new(T) (Bus.Subscribe takes the event type by example). Each class gets
// `static const $type`.
var anyTypes = []string{
	"github.com/libp2p/go-libp2p/core/event.EvtAutoRelayAddrsUpdated",
	"github.com/libp2p/go-libp2p/core/event.EvtHostReachableAddrsChanged",
	"github.com/libp2p/go-libp2p/core/event.EvtLocalAddressesUpdated",
	"github.com/libp2p/go-libp2p/core/event.EvtLocalProtocolsUpdated",
	"github.com/libp2p/go-libp2p/core/event.EvtLocalReachabilityChanged",
	"github.com/libp2p/go-libp2p/core/event.EvtNATDeviceTypeChanged",
	"github.com/libp2p/go-libp2p/core/event.EvtPeerConnectednessChanged",
	"github.com/libp2p/go-libp2p/core/event.EvtPeerIdentificationCompleted",
	"github.com/libp2p/go-libp2p/core/event.EvtPeerIdentificationFailed",
	"github.com/libp2p/go-libp2p/core/event.EvtPeerProtocolsUpdated",
}

// funcTokens: Go functions that cross as values in an `any`, as a token: a
// `<name>Func` constant in their library (libp2p.Transport takes the
// transport's constructor, which fx calls with what it needs).
var funcTokens = []string{
	"github.com/libp2p/go-libp2p/p2p/transport/tcp.NewTCPTransport",
	"github.com/libp2p/go-libp2p/p2p/transport/quic.NewTransport",
	"github.com/libp2p/go-libp2p/p2p/transport/websocket.New",
	"github.com/libp2p/go-libp2p/p2p/transport/webtransport.New",
	"github.com/libp2p/go-libp2p/p2p/transport/webrtc.New",
	"github.com/libp2p/go-libp2p/p2p/security/noise.New",
	"github.com/libp2p/go-libp2p/p2p/security/tls.New",
	"github.com/libp2p/go-libp2p/p2p/transport/quicreuse.NewConnManager",
}

// token: a type of anyTypes or a function of funcTokens, numbered from 1 in
// key order (the numbers go into the table hash).
type token struct {
	id  int
	key string
	t   *tinfo      // a type: its class
	fn  *types.Func // a function
}

func (m *model) tokens() ([]*token, error) {
	var out []*token
	for _, key := range append(append([]string{}, anyTypes...), funcTokens...) {
		path, name, _ := splitRoot(key)
		p := m.load(path)
		if p == nil {
			return nil, fmt.Errorf("token %s: package not found", key)
		}
		switch o := p.Scope().Lookup(name).(type) {
		case *types.TypeName:
			t := m.classify(o.Type())
			if t.k != kDTO {
				return nil, fmt.Errorf("token %s: not a struct of exported fields (%s)", key, describe(t))
			}
			out = append(out, &token{key: key, t: t})
		case *types.Func:
			out = append(out, &token{key: key, fn: o})
		default:
			return nil, fmt.Errorf("token %s: neither a type nor a function", key)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].key < out[j].key })
	for i, t := range out {
		t.id = i + 1
	}
	return out, nil
}
