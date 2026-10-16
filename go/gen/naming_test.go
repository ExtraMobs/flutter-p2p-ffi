package main

import "testing"

func TestNames(t *testing.T) {
	for _, c := range []struct{ goName, typ, member string }{
		{"CoreAPI", "CoreApi", "coreApi"},
		{"UnixfsAPI", "UnixfsApi", "unixfsApi"},
		{"IpfsNode", "IpfsNode", "ipfsNode"},
		{"PeerID", "PeerId", "peerId"},
		{"HTTPServer", "HttpServer", "httpServer"},
		{"MD5Sum", "Md5Sum", "md5Sum"},
		{"NewPluginLoader", "NewPluginLoader", "newPluginLoader"},
		{"ID", "Id", "id"},
		{"ResolvePath", "ResolvePath", "resolvePath"},
		{"CidVersion", "CidVersion", "cidVersion"},
		{"MaxHAMTFanout", "MaxHamtFanout", "maxHamtFanout"},
		{"Type", "Type$", "type"},
		{"Ls", "Ls", "ls"},
		{"IsPinned", "IsPinned", "isPinned"},
		{"Default", "Default", "default$"},
		{"Value", "Value", "value$"},
		{"UseWholeCIDs", "UseWholeCids", "useWholeCids"},
		{"PeerIDs", "PeerIds", "peerIds"},
		{"CIDsByName", "CidsByName", "cidsByName"},
	} {
		if got := typeName(c.goName); got != c.typ {
			t.Errorf("typeName(%q) = %q, quero %q", c.goName, got, c.typ)
		}
		if got := memberName(c.goName); got != c.member {
			t.Errorf("memberName(%q) = %q, quero %q", c.goName, got, c.member)
		}
	}
}
