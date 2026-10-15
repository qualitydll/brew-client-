package dev.brew.brew

import android.content.Context
import android.os.Build
import io.github.oviron.libmihomo.Clash
import java.io.File

/**
 * Owns one-time initialization of the embedded Mihomo JNI bridge.
 *
 * Configuration validation happens in MainActivity before the VpnService
 * starts, so the service must reuse the already-loaded bridge instead of
 * loading the same native Go runtime a second time.
 */
internal object MihomoRuntime {
    private val requiredLibraries = listOf("libclash.so", "libmihomo-jni.so")

    @Synchronized
    fun load(context: Context) {
        val nativeLibraryDir = File(context.applicationInfo.nativeLibraryDir)
        val missing = requiredLibraries.filterNot { File(nativeLibraryDir, it).isFile }
        check(missing.isEmpty()) {
            "Mihomo native libraries are missing from ${nativeLibraryDir.absolutePath} " +
                "for supported ABIs ${Build.SUPPORTED_ABIS.joinToString()}: " +
                missing.joinToString()
        }

        // libmihomo-android explicitly requires Clash.load() to be called once
        // per process. validateConfig() loads it in MainActivity; when the
        // service later starts, loading it again can reset/reinitialize the
        // native bridge before quickSetup() applies the profile.
        if (!Clash.isLoaded()) {
            Clash.load(nativeLibraryDir.absolutePath)
        }

        Clash.assertReady()
        val abi = Clash.bridgeABI()
        check(abi == Clash.EXPECTED_BRIDGE_ABI) {
            "Mihomo JNI bridge ABI mismatch: expected ${Clash.EXPECTED_BRIDGE_ABI}, got $abi."
        }
    }
}
