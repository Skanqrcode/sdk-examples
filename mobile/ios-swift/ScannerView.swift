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
    case failed(target: String)
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
        .alert("Couldn't check this link", isPresented: errorBinding) {
            Button("OK") { state = .idle }
        } message: {
            // Fail closed: a network/timeout error never auto-opens the link. Worst case
            // the user has to rescan; that's a better tradeoff than opening an unchecked URL.
            Text("We couldn't verify this link is safe, so it wasn't opened. Please try scanning again.")
        }
    }

    private func handleScan(_ target: String) {
        guard case .idle = state else { return }
        state = .checking(target: target)
        Task {
            do {
                let result = try await client.checkURL(target)
                state = .result(result, target: target)
                if result.recommendation == .proceed {
                    open(target)
                }
            } catch {
                state = .failed(target: target)
            }
        }
    }

    private func open(_ target: String) {
        guard let url = URL(string: target) else { state = .idle; return }
        UIApplication.shared.open(url)
        state = .idle
    }

    // MARK: Alert bindings

    private var warnPayload: (target: String, reasons: [String])? {
        if case .result(let result, let target) = state, result.recommendation == .warn {
            return (target, result.reasons)
        }
        return nil
    }

    private var warnBinding: Binding<Bool> {
        Binding(get: { warnPayload != nil }, set: { if !$0 { state = .idle } })
    }

    private var blockPayload: (target: String, reasons: [String])? {
        if case .result(let result, let target) = state, result.recommendation == .block {
            return (target, result.reasons)
        }
        return nil
    }

    private var blockBinding: Binding<Bool> {
        Binding(get: { blockPayload != nil }, set: { if !$0 { state = .idle } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = state { return true } else { return false } },
            set: { if !$0 { state = .idle } }
        )
    }
}
