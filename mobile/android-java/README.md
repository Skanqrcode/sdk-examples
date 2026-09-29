# Android scanner (Java)

Scans a QR code with CameraX + ML Kit, checks the decoded URL with SkanQRCode before
launching it, and branches the UI on `recommendation`: `PROCEED` opens immediately, `WARN`
shows an "Open anyway" / "Cancel" dialog with reason codes, `BLOCK` shows a dead-end alert.
See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the API contract.

This example assumes an OkHttp-based Android build of `com.skanqrcode.sdk` (same
`checkUrl`/`CheckResult`/`Verdict`/`Recommendation` shape as [`../../sdk/java`](../../sdk/java),
which uses `java.net.http.HttpClient` instead since that's unavailable on Android) — swap in
your own OkHttp-backed client with that same shape if you're pulling this into a real app.
`checkUrl` is blocking, so it's called from a background `ExecutorService`, never the main thread.

## Dependencies

```groovy
dependencies {
    implementation "androidx.camera:camera-core:1.3.4"
    implementation "androidx.camera:camera-camera2:1.3.4"
    implementation "androidx.camera:camera-lifecycle:1.3.4"
    implementation "androidx.camera:camera-view:1.3.4"
    implementation "com.google.mlkit:barcode-scanning:17.3.0"
    implementation "com.squareup.okhttp3:okhttp:4.12.0"
    implementation "org.json:json:20240303"
    implementation "androidx.appcompat:appcompat:1.7.0"
}
```

Also requires the `CAMERA` permission (request it at runtime before launching this activity)
and `SKANQRCODE_API_KEY` wired into `BuildConfig` from a local, non-committed properties file.
