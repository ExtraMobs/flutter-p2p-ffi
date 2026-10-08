// net.ListenMulticastUDP (usuário no grafo: huin/goupnp/httpu): o socket
// escuta no "não especificado" da família com SO_REUSEADDR (outro membro
// do grupo na mesma porta), entra no grupo (IP_ADD_MEMBERSHIP, com o índice
// da interface quando há uma) e desliga o IP_MULTICAST_LOOP (o que ele
// mesmo manda ao grupo não volta para a máquina). Na VM no linux pela rede
// FFI; no Node pelo dgram (reuseAddr, addMembership, setMulticastLoopback,
// setMulticastInterface).
package main

import (
	"fmt"
	"net"
	"strings"
	"time"
)

var labels [][2]string

func label(real, name string) { labels = append(labels, [2]string{real, name}) }

func clean(s string) string {
	for i := len(labels) - 1; i >= 0; i-- {
		s = strings.ReplaceAll(s, labels[i][0], labels[i][1])
	}
	return s
}

func show(name string, err error) {
	if err == nil {
		fmt.Println(name+":", "<nil>")
		return
	}
	fmt.Println(name+":", clean(err.Error()))
}

func read(name string, c *net.UDPConn) {
	buf := make([]byte, 64)
	c.SetReadDeadline(time.Now().Add(time.Second))
	n, from, err := c.ReadFromUDP(buf)
	if err != nil {
		show(name, err)
		return
	}
	fmt.Println(name+":", string(buf[:n]), clean(from.String()))
}

func main() {
	group := net.IPv4(239, 255, 0, 77)
	c, err := net.ListenMulticastUDP("udp4", nil, &net.UDPAddr{IP: group})
	show("listen", err)
	if err != nil {
		return
	}
	la := c.LocalAddr().(*net.UDPAddr)
	fmt.Println("local:", la.IP, la.Port > 0)
	grp := &net.UDPAddr{IP: group, Port: la.Port}
	label(grp.String(), "GRP")
	label(fmt.Sprint(":", la.Port), ":PORT")

	// Outro membro na mesma porta (SO_REUSEADDR).
	c2, err := net.ListenMulticastUDP("udp", nil, grp)
	show("listen2", err)

	// O que o próprio membro manda ao grupo não volta (loop desligado).
	_, err = c.WriteToUDP([]byte("self"), grp)
	show("write self", err)
	s, err := net.DialUDP("udp4", nil, grp)
	show("dial group", err)
	label(s.LocalAddr().String(), "SENDER")
	_, err = s.Write([]byte("ping"))
	show("write", err)
	read("c", c)
	read("c2", c2)
	c2.Close()

	// Unicast para a porta também chega (escuta no não especificado).
	u, _ := net.DialUDP("udp4", nil, &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: la.Port})
	label(u.LocalAddr().String(), "UNI")
	u.Write([]byte("unicast"))
	read("unicast", c)
	u.Close()
	s.Close()
	c.Close()

	// Com interface: o índice dela no IP_ADD_MEMBERSHIP e no IP_MULTICAST_IF.
	ifs, _ := net.Interfaces()
	for _, ifi := range ifs {
		if ifi.Flags&net.FlagLoopback == 0 {
			continue
		}
		c3, err := net.ListenMulticastUDP("udp4", &ifi, &net.UDPAddr{IP: net.IPv4(239, 255, 0, 78)})
		show("listen loopback", err)
		if err == nil {
			p := c3.LocalAddr().(*net.UDPAddr).Port
			label(fmt.Sprint(":", p), ":PORT3")
			c3.Close()
		}
		break
	}

	_, err = net.ListenMulticastUDP("tcp", nil, grp)
	show("tcp", err)
	_, err = net.ListenMulticastUDP("udp", nil, nil)
	show("nil", err)
	_, err = net.ListenMulticastUDP("udp", nil, &net.UDPAddr{Port: 1})
	show("sem ip", err)
	_, err = net.ListenMulticastUDP("udp4", nil, &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	show("unicast group", err)
}
