// Package plug só existe pelo efeito do init (padrão de plugins/codecs do kubo).
package plug

import "g2d.test/blankimport/registry"

func init() { registry.Register("plug") }
