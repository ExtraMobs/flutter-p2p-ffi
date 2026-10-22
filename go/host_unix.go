//go:build linux

// O canal do ipfs_host no linux e no Android (o GOOS android também é
// linux): região num memfd passado por SCM_RIGHTS no Unix socket, que depois
// é o sininho dos dois sentidos.
package main

import (
	"encoding/binary"
	"fmt"
	"net"
	"os"

	"golang.org/x/sys/unix"
)

type unixChan struct {
	mem  []byte
	conn *net.UnixConn
}

func (c *unixChan) region() []byte { return c.mem }

func (c *unixChan) bellWait() bool {
	var b [64]byte
	n, err := c.conn.Read(b[:])
	return err == nil && n > 0
}

func (c *unixChan) bellRing() { _, _ = c.conn.Write([]byte{1}) }

// listen cria a região, escuta em [path], avisa "ready" no stdout e espera o
// app conectar; então manda o tamanho e o descritor da região.
func listen(path string, size int, init func([]byte)) (hostChan, error) {
	fd, err := unix.MemfdCreate("p2p_ffi", unix.MFD_CLOEXEC)
	if err != nil {
		return nil, fmt.Errorf("memfd: %w", err)
	}
	if err := unix.Ftruncate(fd, int64(size)); err != nil {
		return nil, fmt.Errorf("ftruncate: %w", err)
	}
	mem, err := unix.Mmap(fd, 0, size, unix.PROT_READ|unix.PROT_WRITE, unix.MAP_SHARED)
	if err != nil {
		return nil, fmt.Errorf("mmap: %w", err)
	}
	init(mem)
	_ = os.Remove(path)
	l, err := net.ListenUnix("unix", &net.UnixAddr{Name: path, Net: "unix"})
	if err != nil {
		return nil, err
	}
	_ = os.Chmod(path, 0o600)
	fmt.Println("ready")
	conn, err := l.AcceptUnix()
	l.Close()
	_ = os.Remove(path)
	if err != nil {
		return nil, err
	}
	var hs [8]byte
	binary.LittleEndian.PutUint64(hs[:], uint64(size))
	if _, _, err := conn.WriteMsgUnix(hs[:], unix.UnixRights(fd), nil); err != nil {
		return nil, fmt.Errorf("handshake: %w", err)
	}
	unix.Close(fd)
	return &unixChan{mem: mem, conn: conn}, nil
}
