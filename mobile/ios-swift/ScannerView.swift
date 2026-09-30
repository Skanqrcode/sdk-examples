import SwiftUI
import AVFoundation
import SkanQRCode

// MARK: - Camera layer

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in session.stopRunning() }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer })?.frame = view.bounds
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let payload = object.stringValue
        else { return }
        hasScanned = true
        onCodeScanned?(payload)
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

// MARK: - Scan + check flow

private enum CheckState {
    case idle
    case checking(target: String)
    case result(CheckResult, target: String)
    case failed(message: String)
}

struct ScannerView: View {
    private let client = SkanQRCodeClient(apiKey: ProcessInfo.processInfo.environment["SKANQRCODE_API_KEY"] ?? "")

    @State private var state: CheckState = .idle

    var body: some View {
        ZStack {
            QRScannerRepresentable(onCodeScanned: handleScan)
                .ignoresSafeArea()

            if case .checking = state {
                ProgressView("Checking link safety…")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Suspicious link", isPresented: warnBinding, presenting: warnPayload) { payload in
            Button("Open anyway", role: .destructive) { open(payload.target) }
            Button("Cancel", role: .cancel) { state = .idle }
        } message: { payload in
            Text("This link looks suspicious. Open anyway?\n\nReasons: \(payload.reasons.joined(separator: ", "))")
        }
        .alert("Link blocked", isPresented: blockBinding, presenting: blockPayload) { _ in
            Button("OK") { state = .idle }
        } message: { payload in
            Text("This link was flagged as malicious and can't be opened.\n\nReasons: \(payload.reasons.joined(separator: ", "))")
        }
        .alert("Couldn't check this link", isPresented: errorBinding, presenting: errorMessage) { _ in
            Button("OK") { state = .idle }
        } message: { message in
            // Fail closed: an error or timeout never auto-opens the link. Worst case the
            // user has to rescan; that's a better tradeoff than opening an unchecked URL.
            Text(message)
        }
    }

    private func handleScan(_ target: String) {
        guard case .idle = state else { return }
        state = .checking(target: target)
        Task {
            do {
                let result = try await client.checkURL(target)
                switch result.action {
                case .allow:
                    open(target)
                case .warn, .block:
                    state = .result(result, target: target) // the alerts below take over
                case .unknown:
                    // An action this SDK version doesn't know: fail closed.
                    state = .failed(message: "We couldn't verify this link is safe, so it wasn't opened.")
                }
            } catch {
                state = .failed(message: message(for: error))
            }
        }
    }

    /// Maps an error to user-facing text. Nothing here ever opens the link.
    private func message(for error: Error) -> String {
        guard let apiError = error as? SkanQRCodeError else {
            // Network failure or timeout: no verdict at all.
            return "The safety check timed out or failed, so this link wasn't opened. Please try scanning again."
        }
        switch apiError.code {
        case SkanQRCodeError.Code.rateLimited:
            let wait = apiError.retryAfter.map { "in \($0) seconds" } ?? "in a moment"
            return "Too many scans right now. Try again \(wait)."
        case SkanQRCodeError.Code.quotaExceeded,
             SkanQRCodeError.Code.paymentRequired,
             SkanQRCodeError.Code.unauthorized,
             SkanQRCodeError.Code.forbidden:
            // Not something the user can fix by rescanning: an API key, plan or quota problem.
            return "Link checking isn't available because of a configuration problem. Contact the app's developer. (\(apiError.code), requestId: \(apiError.requestId ?? "none"))"
        default:
            // invalid_request, auth_unavailable, internal, unknown codes, non-JSON proxy errors…
            return "We couldn't verify this link is safe, so it wasn't opened. Please try scanning again. (requestId: \(apiError.requestId ?? "none"))"
        }
    }

    private func open(_ target: String) {
        guard let url = URL(string: target) else { state = .idle; return }
        UIApplication.shared.open(url)
        state = .idle
    }

    // MARK: Alert bindings

    private var warnPayload: (target: String, reasons: [String])? {
        if case .result(let result, let target) = state, result.action == .warn {
            return (target, result.reasons)
        }
        return nil
    }

    private var warnBinding: Binding<Bool> {
        Binding(get: { warnPayload != nil }, set: { if !$0 { state = .idle } })
    }

    private var blockPayload: (target: String, reasons: [String])? {
        if case .result(let result, let target) = state, result.action == .block {
            return (target, result.reasons)
        }
        return nil
    }

    private var blockBinding: Binding<Bool> {
        Binding(get: { blockPayload != nil }, set: { if !$0 { state = .idle } })
    }

    private var errorMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { state = .idle } })
    }
}
