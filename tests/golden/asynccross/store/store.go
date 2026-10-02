// Package store declara a interface; quem a implementa com canais fica em
// outro pacote, emitido depois: a cor async vem da tabela do grafo.
package store

// Store devolve o valor de uma chave.
type Store interface {
	Get(k string) string
}

// Lookup chama pela interface: async porque Store.Get é.
func Lookup(s Store, k string) string {
	return "[" + s.Get(k) + "]"
}

// Mem implementa Store sem suspender (mesma assinatura Future no Dart).
type Mem map[string]string

func (m Mem) Get(k string) string { return m[k] }
