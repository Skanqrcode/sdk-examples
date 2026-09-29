package com.skanqrcode.example.scanner

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
// SkanQRCodeClient here is the OkHttp-based Android build of the SDK — same public API
// (checkUrl, CheckResult/Verdict/Recommendation) as sdk/kotlin. See this module's README.
import com.skanqrcode.sdk.CheckResult
import com.skanqrcode.sdk.Recommendation
import com.skanqrcode.sdk.SkanQRCodeClient
import com.skanqrcode.sdk.SkanQRCodeException
import kotlinx.coroutines.launch

private sealed interface ScanState {
    data object Scanning : ScanState
    data class Checking(val target: String) : ScanState
    data class Decided(val target: String, val result: CheckResult) : ScanState
    data class Failed(val message: String) : ScanState
}

class ScannerActivity : ComponentActivity() {

    // Real apps should read the API key from a secrets store, not hardcode it —
    // and ideally proxy this call through your own backend rather than shipping a
    // long-lived API key inside a distributed APK at all.
    private val client = SkanQRCodeClient(apiKey = BuildConfig.SKANQRCODE_API_KEY)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ScannerScreen(client = client, onOpen = ::openUrl)
        }
    }

    private fun openUrl(target: String) {
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(target)))
    }
}

@Composable
private fun ScannerScreen(client: SkanQRCodeClient, onOpen: (String) -> Unit) {
    var state by remember { mutableStateOf<ScanState>(ScanState.Scanning) }
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    fun onQrDetected(target: String) {
        if (state !is ScanState.Scanning) return // already handling one code
        state = ScanState.Checking(target)
        scope.launch {
            state = try {
                ScanState.Decided(target, client.checkUrl(target))
            } catch (e: SkanQRCodeException) {
                ScanState.Failed("${e.code}: ${e.message}")
            } catch (e: Exception) {
                // Fail closed: a timeout or dropped connection must not fall through to
                // "safe to open" — surface an error and make the user re-scan instead.
                ScanState.Failed(e.message ?: "Could not reach SkanQRCode")
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                val previewView = PreviewView(ctx)
                val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                cameraProviderFuture.addListener({
                    val cameraProvider = cameraProviderFuture.get()
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    val scanner = BarcodeScanning.getClient(
                        BarcodeScannerOptions.Builder()
                            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                            .build()
                    )
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { imageAnalysis ->
                            imageAnalysis.setAnalyzer(ContextCompat.getMainExecutor(ctx)) { imageProxy ->
                                val mediaImage = imageProxy.image
                                if (mediaImage == null) {
                                    imageProxy.close()
                                    return@setAnalyzer
                                }
                                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                                scanner.process(image)
                                    .addOnSuccessListener { barcodes ->
                                        barcodes.firstOrNull { it.rawValue != null }?.rawValue?.let(::onQrDetected)
                                    }
                                    .addOnCompleteListener { imageProxy.close() }
                            }
                        }

                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        analysis
                    )
                }, ContextCompat.getMainExecutor(ctx))
                previewView
            }
        )

        when (val s = state) {
            is ScanState.Checking -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            is ScanState.Decided -> DecisionDialog(
                target = s.target,
                result = s.result,
                onDismiss = { state = ScanState.Scanning },
                onOpen = {
                    onOpen(s.target)
                    state = ScanState.Scanning
                }
            )
            is ScanState.Failed -> AlertDialog(
                onDismissRequest = { state = ScanState.Scanning },
                title = { Text("Couldn't check this link") },
                text = { Text(s.message) },
                confirmButton = {
                    TextButton(onClick = { state = ScanState.Scanning }) { Text("OK") }
                }
            )
            ScanState.Scanning -> Unit
        }
    }
}

@Composable
private fun DecisionDialog(
    target: String,
    result: CheckResult,
    onDismiss: () -> Unit,
    onOpen: () -> Unit,
) {
    when (result.recommendation) {
        Recommendation.PROCEED -> LaunchedEffect(target) { onOpen() } // no dialog, launch immediately
        Recommendation.WARN -> AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("This link looks suspicious") },
            text = { Text("$target\n\nReasons: ${result.reasons.joinToString()}") },
            confirmButton = { TextButton(onClick = onOpen) { Text("Open anyway") } },
            dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
        )
        Recommendation.BLOCK -> AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("This link is unsafe") },
            text = { Text("$target\n\nReasons: ${result.reasons.joinToString()}\n\nSkanQRCode blocked this link.") },
            confirmButton = { TextButton(onClick = onDismiss) { Text("OK") } }
        )
    }
}
