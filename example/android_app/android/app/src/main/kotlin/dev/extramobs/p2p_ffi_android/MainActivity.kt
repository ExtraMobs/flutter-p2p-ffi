package dev.extramobs.p2p_ffi_android

import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Android drops the multicast that reaches the app without this lock: without
    // it, kubo's mDNS (local network discovery) gets no answer.
    // ponytail: held while the Activity lives (costs battery on Wi-Fi); in a real
    // app, only with the node online.
    private var multicast: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Validation app: the screen stays on while it is open, so the node
        // (which closes in the background) stays online during long measurements.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        multicast = wifi.createMulticastLock("p2p_ffi-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        multicast?.release()
        super.onDestroy()
    }
}
