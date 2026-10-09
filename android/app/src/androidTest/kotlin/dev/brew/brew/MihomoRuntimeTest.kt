package dev.brew.brew

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.github.oviron.libmihomo.Clash
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MihomoRuntimeTest {
    @Test
    fun loadsNativeLibrariesFromInstalledApkDirectory() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val nativeLibraryDir = File(context.applicationInfo.nativeLibraryDir)
        assertTrue(File(nativeLibraryDir, "libclash.so").isFile)
        assertTrue(File(nativeLibraryDir, "libmihomo-jni.so").isFile)

        MihomoRuntime.load(context)

        assertTrue(Clash.isLoaded())
        assertEquals(Clash.EXPECTED_BRIDGE_ABI, Clash.bridgeABI())
    }
}
