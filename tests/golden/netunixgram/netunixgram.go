// Sockets Unix de datagrama (unixgram) no shim net, pela rede FFI da VM
// (etapa E3): eco com remetente nomeado, excesso descartado, datagrama
// vazio, remetente sem nome (endereço nil), nomes abstratos e autobind, os
// erros do sendto/connect/bind, prazo, Close (que nunca apaga o arquivo),
// Listen("unixgram") com o Accept que falha, ListenPacket("unix") sobre o
// socket escutando e a leitura pendente acordada por outra goroutine.
//
// Cada linha é "rótulo: resultado". No Node não há unixgram (F4): a linha
// inteira vira o erro "operation not supported" da operação que abre o
// socket (regra F5, netunixgram.node.out). Os nomes têm o pid; o texto
// troca o prefixo por SOCK. Sem o pacote os de arquivos no shim, a
// existência do arquivo é vista pelo connect (refused × no such file), e
// os dois arquivos que o Close não apaga ficam em /tmp.
package main

import (
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

var (
	base = fmt.Sprintf("/tmp/g2d-netunixgram-%d", os.Getpid())
	abs  = fmt.Sprintf("@g2d-netunixgram-%d", os.Getpid())
)

func clean(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, base, "SOCK"), abs, "@SOCK")
}

func er(err error) string {
	if err == nil {
		return "<nil>"
	}
	return clean(err.Error())
}

func ad(a net.Addr) string {
	if a == nil {
		return "<nil>"
	}
	if u, ok := a.(*net.UnixAddr); ok && u == nil {
		return "nil"
	}
	return a.Network() + " " + clean(a.String())
}

func ua(name string) *net.UnixAddr {
	return &net.UnixAddr{Name: name, Net: "unixgram"}
}

// enderecos: os dois lados de um par nomeado.
func enderecos() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-a"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	cli, err := net.DialUnix("unixgram", ua(abs+"-b"), ua(abs+"-a"))
	if err != nil {
		return er(err)
	}
	defer cli.Close()
	return fmt.Sprintf("srv %v | %v ; cli %v | %v", ad(srv.LocalAddr()), ad(srv.RemoteAddr()),
		ad(cli.LocalAddr()), ad(cli.RemoteAddr()))
}

// eco: excesso descartado, resposta ao remetente nomeado.
func eco() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-c"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	cli, err := net.DialUnix("unixgram", ua(abs+"-d"), ua(abs+"-c"))
	if err != nil {
		return er(err)
	}
	defer cli.Close()
	n, err := cli.Write([]byte("0123456789"))
	out := fmt.Sprintf("write %d %v", n, er(err))
	buf := make([]byte, 4)
	n, from, err := srv.ReadFromUnix(buf)
	out += fmt.Sprintf("; lido %d %q de %v %v", n, buf[:n], ad(from), er(err))
	n, err = srv.WriteToUnix([]byte("pong"), from)
	out += fmt.Sprintf("; resposta %d %v", n, er(err))
	big := make([]byte, 16)
	n, err = cli.Read(big)
	out += fmt.Sprintf("; cli leu %q %v", big[:n], er(err))
	cli.Write([]byte("x"))
	n, err = srv.Read(big)
	out += fmt.Sprintf("; seguinte %q %v", big[:n], er(err))
	return out
}

// vazio: datagrama de 0 bytes é 0, nil (não EOF), e ler com buffer vazio
// não consome nada.
func vazio() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-e"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	cli, err := net.DialUnix("unixgram", nil, ua(abs+"-e"))
	if err != nil {
		return er(err)
	}
	defer cli.Close()
	n, err := cli.Write(nil)
	out := fmt.Sprintf("write %d %v", n, er(err))
	n, err = srv.Read(nil)
	out += fmt.Sprintf("; read(nil) %d %v", n, er(err))
	n, err = srv.Read(make([]byte, 8))
	out += fmt.Sprintf("; read %d %v", n, er(err))
	return out
}

// semNome: quem disca sem laddr não tem nome (local "@"); o ReadFrom
// devolve endereço nil.
func semNome() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-f"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	cli, err := net.DialUnix("unixgram", nil, ua(abs+"-f"))
	if err != nil {
		return er(err)
	}
	defer cli.Close()
	out := fmt.Sprintf("cli %v | %v", ad(cli.LocalAddr()), ad(cli.RemoteAddr()))
	cli.Write([]byte("x"))
	buf := make([]byte, 4)
	n, from, err := srv.ReadFromUnix(buf)
	out += fmt.Sprintf("; ReadFromUnix %d nil=%v %v", n, from == nil, er(err))
	cli.Write([]byte("yz"))
	n, a, err := srv.ReadFrom(buf)
	out += fmt.Sprintf("; ReadFrom %d %v %v", n, ad(a), er(err))
	return out
}

func errosEscrita() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-g"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	cli, err := net.DialUnix("unixgram", ua(abs+"-h"), ua(abs+"-g"))
	if err != nil {
		return er(err)
	}
	defer cli.Close()
	var out []string
	_, err = srv.Write([]byte("x"))
	out = append(out, er(err))
	_, err = srv.WriteToUnix([]byte("x"), ua(abs+"-nada"))
	out = append(out, er(err))
	_, err = srv.WriteToUnix([]byte("x"), &net.UnixAddr{Name: abs + "-h", Net: "unix"})
	out = append(out, er(err))
	_, err = srv.WriteToUnix([]byte("x"), nil)
	out = append(out, er(err))
	_, err = cli.WriteToUnix([]byte("x"), ua(abs+"-g"))
	out = append(out, er(err), fmt.Sprint(errors.Is(err, net.ErrWriteToConnected)))
	_, err = srv.WriteTo([]byte("x"), &net.TCPAddr{})
	out = append(out, er(err))
	return strings.Join(out, " | ")
}

func errosAbertura() string {
	var out []string
	_, err := net.DialUnix("unixgram", nil, ua(abs+"-nada"))
	out = append(out, er(err))
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-i"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	_, err = net.ListenUnixgram("unixgram", ua(abs+"-i"))
	out = append(out, er(err))
	_, err = net.ListenUnixgram("unix", ua(abs+"-i"))
	out = append(out, er(err))
	_, err = net.ListenUnixgram("unixgram", nil)
	out = append(out, er(err))
	_, err = net.DialUnix("unixgram", nil, nil)
	out = append(out, er(err))
	_, err = net.Dial("unixgram", "")
	out = append(out, er(err))
	_, err = net.Dial("unix", abs+"-i")
	out = append(out, er(err))
	_, err = net.ListenUnixgram("unixgram", ua(base+"/nao/existe"))
	out = append(out, er(err))
	return strings.Join(out, " | ")
}

// soLaddr: DialUnix só com laddr (raddr vazio) é um datagrama sem destino.
func soLaddr() string {
	c, err := net.DialUnix("unixgram", ua(abs+"-j"), ua(""))
	if err != nil {
		return er(err)
	}
	defer c.Close()
	_, err = c.Write([]byte("x"))
	return fmt.Sprintf("%v | %v ; write %v", ad(c.LocalAddr()), ad(c.RemoteAddr()), er(err))
}

func prazo() string {
	srv, err := net.ListenUnixgram("unixgram", ua(abs+"-k"))
	if err != nil {
		return er(err)
	}
	defer srv.Close()
	srv.SetReadDeadline(time.Now().Add(20 * time.Millisecond))
	_, _, err = srv.ReadFromUnix(make([]byte, 4))
	out := fmt.Sprintf("%v timeout=%v", er(err), os.IsTimeout(err))
	srv.SetReadDeadline(time.Now().Add(-time.Second))
	_, err = srv.Read(make([]byte, 4))
	return out + "; " + er(err)
}

// listenUnixgram: net.Listen numa rede de datagrama devolve um
// *UnixListener cujo Accept falha (accept4).
func listenUnixgram() string {
	l, err := net.Listen("unixgram", abs+"-l")
	if err != nil {
		return er(err)
	}
	_, aerr := l.Accept()
	return fmt.Sprintf("%T %v; accept: %v; close: %v", l, ad(l.Addr()), er(aerr), er(l.Close()))
}

// listenPacketUnix: ListenPacket numa rede de fluxo devolve um *UnixConn
// sobre o socket escutando: ler e escrever falham no sistema.
func listenPacketUnix() string {
	pc, err := net.ListenPacket("unix", abs+"-m")
	if err != nil {
		return er(err)
	}
	defer pc.Close()
	_, from, rerr := pc.ReadFrom(make([]byte, 4))
	_, werr := pc.WriteTo([]byte("x"), &net.UnixAddr{Name: abs + "-a", Net: "unix"})
	return fmt.Sprintf("%T %v; read %v %v; write %v", pc, ad(pc.LocalAddr()), ad(from), er(rerr), er(werr))
}

// autobind: nome vazio ganha um nome abstrato de 5 dígitos; o abstrato
// manda para ele e chega com o próprio nome.
func autobind() string {
	au, err := net.ListenUnixgram("unixgram", ua(""))
	if err != nil {
		return er(err)
	}
	defer au.Close()
	pc, err := net.ListenPacket("unixgram", abs+"-n")
	if err != nil {
		return er(err)
	}
	defer pc.Close()
	name := au.LocalAddr().String()
	_, err = pc.WriteTo([]byte("hi"), au.LocalAddr())
	buf := make([]byte, 8)
	n, from, rerr := au.ReadFromUnix(buf)
	return fmt.Sprintf("nome %d %q %v; write %v; lido %q de %v %v", len(name), name[:1],
		au.LocalAddr().Network(), er(err), buf[:n], ad(from), er(rerr))
}

// fechar: Close acorda a leitura pendente com ErrClosed e não apaga o
// arquivo (o connect seguinte é recusado, não "no such file").
func fechar() string {
	path := base + "-o"
	srv, err := net.ListenUnixgram("unixgram", ua(path))
	if err != nil {
		return er(err)
	}
	res := make(chan string)
	go func() {
		_, _, err := srv.ReadFromUnix(make([]byte, 4))
		res <- fmt.Sprintf("pendente: %v closed=%v", er(err), errors.Is(err, net.ErrClosed))
	}()
	time.Sleep(20 * time.Millisecond)
	cerr := srv.Close()
	out := <-res
	_, err = net.DialUnix("unixgram", nil, ua(path))
	return fmt.Sprintf("close %v; %s; de novo %v; dial %v", er(cerr), out, er(srv.Close()), er(err))
}

// packetConn: ListenPacket com arquivo, pela interface, e uma goroutine que
// espera o datagrama; o Close do UnixConn também não apaga.
func packetConn() string {
	path := base + "-p"
	pc, err := net.ListenPacket("unixgram", path)
	if err != nil {
		return er(err)
	}
	res := make(chan string)
	go func() {
		buf := make([]byte, 16)
		n, from, err := pc.ReadFrom(buf)
		res <- fmt.Sprintf("goroutine leu %q de %v %v", buf[:n], ad(from), er(err))
	}()
	d := net.Dialer{LocalAddr: ua(abs + "-q")}
	c, err := d.Dial("unixgram", path)
	if err != nil {
		pc.Close()
		return er(err)
	}
	time.Sleep(10 * time.Millisecond)
	c.Write([]byte("datagrama"))
	out := <-res
	c.Close()
	pc.Close()
	_, err = net.Dial("unixgram", path)
	return fmt.Sprintf("%T %v; %s; dial depois do close %v", pc, ad(pc.LocalAddr()), out, er(err))
}

func main() {
	fmt.Println("endereços:", enderecos())
	fmt.Println("eco:", eco())
	fmt.Println("vazio:", vazio())
	fmt.Println("sem nome:", semNome())
	fmt.Println("erros de escrita:", errosEscrita())
	fmt.Println("erros de abertura:", errosAbertura())
	fmt.Println("só laddr:", soLaddr())
	fmt.Println("prazo:", prazo())
	fmt.Println("Listen unixgram:", listenUnixgram())
	fmt.Println("ListenPacket unix:", listenPacketUnix())
	fmt.Println("autobind:", autobind())
	fmt.Println("fechar:", fechar())
	fmt.Println("PacketConn:", packetConn())
	fmt.Println("fim")
}
