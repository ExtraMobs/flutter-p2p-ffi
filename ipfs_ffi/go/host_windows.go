// O canal do ipfs_host no Windows: a região num mapeamento com nome aleatório
// e dois named pipes de um sentido cada (<base>-req: o app toca o sininho do
// host; <base>-resp: aperto de mão e o sininho do app). Um pipe de cada
// sentido evita que uma leitura bloqueante trave a escrita no mesmo handle.
package main

import (
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"
)

type winChan struct {
	mem       []byte
	req, resp *os.File
}

func (c *winChan) region() []byte { return c.mem }

func (c *winChan) bellWait() bool {
	var b [64]byte
	n, err := c.req.Read(b[:])
	return err == nil && n > 0
}

func (c *winChan) bellRing() { _, _ = c.resp.Write([]byte{1}) }

func pipe(name string, dir uint32) (windows.Handle, error) {
	p, err := windows.UTF16PtrFromString(name)
	if err != nil {
		return 0, err
	}
	return windows.CreateNamedPipe(p, dir|windows.FILE_FLAG_FIRST_PIPE_INSTANCE,
		windows.PIPE_TYPE_BYTE|windows.PIPE_READMODE_BYTE|windows.PIPE_WAIT|windows.PIPE_REJECT_REMOTE_CLIENTS,
		1, 4096, 4096, 0, nil)
}

func listen(base string, size int, init func([]byte)) (hostChan, error) {
	var rnd [16]byte
	_, _ = rand.Read(rnd[:])
	name := `Local\ipfs_ffi_` + hex.EncodeToString(rnd[:])
	np, _ := windows.UTF16PtrFromString(name)
	m, err := windows.CreateFileMapping(windows.InvalidHandle, nil, windows.PAGE_READWRITE,
		uint32(uint64(size)>>32), uint32(size), np)
	if err != nil {
		return nil, fmt.Errorf("CreateFileMapping: %w", err)
	}
	addr, err := windows.MapViewOfFile(m, windows.FILE_MAP_WRITE|windows.FILE_MAP_READ, 0, 0, uintptr(size))
	if err != nil {
		return nil, fmt.Errorf("MapViewOfFile: %w", err)
	}
	// o mapeamento fica fora do GC; a conversão por ponteiro evita o aviso do vet
	mem := unsafe.Slice((*byte)(*(*unsafe.Pointer)(unsafe.Pointer(&addr))), size)
	init(mem)
	req, err := pipe(base+"-req", windows.PIPE_ACCESS_INBOUND)
	if err != nil {
		return nil, fmt.Errorf("pipe req: %w", err)
	}
	resp, err := pipe(base+"-resp", windows.PIPE_ACCESS_OUTBOUND)
	if err != nil {
		return nil, fmt.Errorf("pipe resp: %w", err)
	}
	fmt.Println("ready")
	for _, h := range []windows.Handle{req, resp} {
		if err := windows.ConnectNamedPipe(h, nil); err != nil && err != windows.ERROR_PIPE_CONNECTED {
			return nil, fmt.Errorf("ConnectNamedPipe: %w", err)
		}
	}
	c := &winChan{mem: mem, req: os.NewFile(uintptr(req), base+"-req"), resp: os.NewFile(uintptr(resp), base+"-resp")}
	hs := make([]byte, 10+len(name))
	binary.LittleEndian.PutUint64(hs, uint64(size))
	binary.LittleEndian.PutUint16(hs[8:], uint16(len(name)))
	copy(hs[10:], name)
	if _, err := c.resp.Write(hs); err != nil {
		return nil, fmt.Errorf("handshake: %w", err)
	}
	return c, nil
}
