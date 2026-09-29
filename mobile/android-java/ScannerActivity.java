package com.skanqrcode.example.scanner;

import android.content.Intent;
import android.media.Image;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ProgressBar;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;

import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.common.InputImage;
// SkanQRCodeClient here is the OkHttp-based Android build of the SDK — same public API
// (checkUrl, CheckResult/Verdict/Recommendation) as sdk/java. See this module's README.
import com.skanqrcode.sdk.CheckResult;
import com.skanqrcode.sdk.Recommendation;
import com.skanqrcode.sdk.SkanQRCodeClient;
import com.skanqrcode.sdk.SkanQRCodeException;

import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public class ScannerActivity extends AppCompatActivity {

    // Real apps should read the API key from a secrets store, not hardcode it —
    // and ideally proxy this call through your own backend rather than shipping a
    // long-lived API key inside a distributed APK at all.
    private final SkanQRCodeClient client = new SkanQRCodeClient(BuildConfig.SKANQRCODE_API_KEY);
    private final ExecutorService networkExecutor = Executors.newSingleThreadExecutor();
    private final AtomicBoolean handlingScan = new AtomicBoolean(false);

    private PreviewView previewView;
    private ProgressBar progressBar;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        FrameLayout root = new FrameLayout(this);
        previewView = new PreviewView(this);
        root.addView(previewView);

        progressBar = new ProgressBar(this);
        progressBar.setVisibility(View.GONE);
        FrameLayout.LayoutParams progressParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT);
        progressParams.gravity = Gravity.CENTER;
        root.addView(progressBar, progressParams);

        setContentView(root);
        startCamera();
    }

    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(this);
        cameraProviderFuture.addListener(() -> {
            try {
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();

                Preview preview = new Preview.Builder().build();
                preview.setSurfaceProvider(previewView.getSurfaceProvider());

                BarcodeScanner scanner = BarcodeScanning.getClient(
                        new BarcodeScannerOptions.Builder()
                                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                                .build());

                ImageAnalysis analysis = new ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build();
                analysis.setAnalyzer(ContextCompat.getMainExecutor(this), imageProxy -> analyze(scanner, imageProxy));

                cameraProvider.unbindAll();
                cameraProvider.bindToLifecycle(this, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }, ContextCompat.getMainExecutor(this));
    }

    private void analyze(BarcodeScanner scanner, ImageProxy imageProxy) {
        Image mediaImage = imageProxy.getImage();
        if (mediaImage == null) {
            imageProxy.close();
            return;
        }
        InputImage image = InputImage.fromMediaImage(mediaImage, imageProxy.getImageInfo().getRotationDegrees());
        scanner.process(image)
                .addOnSuccessListener((List<Barcode> barcodes) -> {
                    for (Barcode barcode : barcodes) {
                        String value = barcode.getRawValue();
                        if (value != null) {
                            onQrDetected(value);
                            break;
                        }
                    }
                })
                .addOnCompleteListener(task -> imageProxy.close());
    }

    private void onQrDetected(String target) {
        if (!handlingScan.compareAndSet(false, true)) {
            return; // already checking one code
        }
        runOnUiThread(() -> progressBar.setVisibility(View.VISIBLE));

        networkExecutor.execute(() -> {
            try {
                CheckResult result = client.checkUrl(target);
                runOnUiThread(() -> onResult(target, result));
            } catch (SkanQRCodeException e) {
                runOnUiThread(() -> onError(e.getCode() + ": " + e.getMessage()));
            } catch (Exception e) {
                // Fail closed: a timeout or dropped connection must not fall through to
                // "safe to open" — surface an error and make the user re-scan instead.
                runOnUiThread(() -> onError(e.getMessage() != null ? e.getMessage() : "Could not reach SkanQRCode"));
            }
        });
    }

    private void onResult(String target, CheckResult result) {
        progressBar.setVisibility(View.GONE);
        Recommendation recommendation = result.getRecommendation();
        String reasons = String.join(", ", result.getReasons());

        if (recommendation == Recommendation.PROCEED) {
            openUrl(target);
            handlingScan.set(false);
            return;
        }

        if (recommendation == Recommendation.WARN) {
            new AlertDialog.Builder(this)
                    .setTitle("This link looks suspicious")
                    .setMessage(target + "\n\nReasons: " + reasons)
                    .setPositiveButton("Open anyway", (dialog, which) -> {
                        openUrl(target);
                        handlingScan.set(false);
                    })
                    .setNegativeButton("Cancel", (dialog, which) -> handlingScan.set(false))
                    .setOnCancelListener(dialog -> handlingScan.set(false))
                    .show();
            return;
        }

        // BLOCK — no proceed option.
        new AlertDialog.Builder(this)
                .setTitle("This link is unsafe")
                .setMessage(target + "\n\nReasons: " + reasons + "\n\nSkanQRCode blocked this link.")
                .setPositiveButton("OK", (dialog, which) -> handlingScan.set(false))
                .setCancelable(false)
                .show();
    }

    private void onError(String message) {
        progressBar.setVisibility(View.GONE);
        new AlertDialog.Builder(this)
                .setTitle("Couldn't check this link")
                .setMessage(message)
                .setPositiveButton("OK", (dialog, which) -> handlingScan.set(false))
                .show();
    }

    private void openUrl(String target) {
        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(target)));
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        networkExecutor.shutdown();
    }
}
