package dev.extramobs.ipfs_ffi_android

import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // O Android descarta o multicast que chega ao app sem este lock: sem ele o
    // mDNS do kubo (descoberta na rede local) não recebe resposta.
    // ponytail: preso enquanto a Activity vive (custa bateria no Wi-Fi); num
    // app de verdade, só com o nó online.
    private var multicast: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // App de validação: a tela fica acesa com ele aberto, para o nó (que
        // fecha no background) seguir online nas medições longas.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        multicast = wifi.createMulticastLock("ipfs_ffi-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        multicast?.release()
        super.onDestroy()
    }
}
