import AVFoundation
import CoreMedia
import CoreVideo
import SwiftUI

struct CameraPulseView: UIViewControllerRepresentable {
    let onProgress: (Double, String) -> Void
    let onResult: (Result<Double, PulseCaptureError>) -> Void

    func makeUIViewController(context: Context) -> PulseCameraViewController {
        let controller = PulseCameraViewController()
        controller.onProgress = onProgress
        controller.onResult = onResult
        controller.start()
        return controller
    }

    func updateUIViewController(_ uiViewController: PulseCameraViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: PulseCameraViewController, coordinator: ()) {
        uiViewController.stop()
    }
}

final class PulseCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onProgress: ((Double, String) -> Void)?
    var onResult: ((Result<Double, PulseCaptureError>) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.anishdas.vita.pulse-camera")
    private var camera: AVCaptureDevice?
    private var startedAt: CFTimeInterval = 0
    private var lastSampleAt: CFTimeInterval = 0
    private var samples: [PulseSample] = []
    private var isCapturing = false
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndStart()
                } else {
                    self?.fail(.cameraAccess)
                }
            }
        default:
            fail(.cameraAccess)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isCapturing = false
            self.turnTorch(on: false)
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.fail(.cameraAccess)
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                self.session.beginConfiguration()
                self.session.sessionPreset = .low
                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.fail(.cameraAccess)
                    return
                }
                self.session.addInput(input)

                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.sessionQueue)
                guard self.session.canAddOutput(output) else {
                    self.session.commitConfiguration()
                    self.fail(.cameraAccess)
                    return
                }
                self.session.addOutput(output)
                self.session.commitConfiguration()

                self.camera = camera
                self.turnTorch(on: true)
                self.samples.removeAll(keepingCapacity: true)
                self.startedAt = CACurrentMediaTime()
                self.lastSampleAt = 0
                self.didFinish = false
                self.isCapturing = true
                self.session.startRunning()
                self.progress(0, "Cover the rear camera and flash")
            } catch {
                self.fail(.cameraAccess)
            }
        }
    }

    private func turnTorch(on: Bool) {
        guard let camera, camera.hasTorch else { return }
        do {
            try camera.lockForConfiguration()
            camera.torchMode = on ? .on : .off
            camera.unlockForConfiguration()
        } catch {
            // The torch is an optional improvement; the camera signal can still be sampled.
        }
    }

    private func progress(_ value: Double, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onProgress?(value, message)
        }
    }

    private func fail(_ error: PulseCaptureError) {
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(.failure(error))
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCapturing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let now = CACurrentMediaTime()
        guard now - lastSampleAt >= 0.05 else { return }
        lastSampleAt = now

        if let value = redGreenRatio(from: pixelBuffer) {
            samples.append(PulseSample(time: now - startedAt, value: value))
        }

        let elapsed = now - startedAt
        if elapsed >= 12 {
            finish()
        } else {
            let phase = elapsed < 3 ? "Warming up the signal…" : elapsed < 9 ? "Reading your pulse…" : "Checking signal quality…"
            progress(min(1, elapsed / 12), phase)
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        isCapturing = false
        turnTorch(on: false)
        session.stopRunning()
        let result = PulseEstimator.estimate(from: samples).map { Result<Double, PulseCaptureError>.success($0) } ?? .failure(.noStableSignal)
        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
        }
    }

    private func redGreenRatio(from pixelBuffer: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let xStart = width / 8
        let xEnd = width * 7 / 8
        let yStart = height / 8
        let yEnd = height * 7 / 8
        var red = 0.0
        var green = 0.0
        var count = 0.0

        for y in stride(from: yStart, to: yEnd, by: 3) {
            for x in stride(from: xStart, to: xEnd, by: 3) {
                let offset = y * bytesPerRow + x * 4
                green += Double(buffer[offset + 1])
                red += Double(buffer[offset + 2])
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return (red / count) / max(green / count, 1)
    }
}
