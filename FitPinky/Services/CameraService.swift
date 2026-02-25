import AVFoundation
import UIKit
import Observation

@Observable
final class CameraService: NSObject {
    var capturedImage: UIImage?
    var isAuthorized = false
    var isSessionRunning = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.fitpinky.camera.session")
    private var currentPosition: AVCaptureDevice.Position = .front
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    // MARK: - Authorization

    func checkAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        guard isAuthorized else { return }

        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()
        }
    }

    func startSession() {
        sessionQueue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Camera Toggle

    func toggleCamera() {
        sessionQueue.async { [self] in
            currentPosition = currentPosition == .back ? .front : .back

            session.beginConfiguration()

            if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
                session.removeInput(currentInput)
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            session.commitConfiguration()
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                photoContinuation = continuation
                let settings = AVCapturePhotoSettings()
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = photoContinuation
        photoContinuation = nil

        if let error {
            continuation?.resume(throwing: error)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(throwing: CameraError.captureFailure)
            return
        }

        let finalImage: UIImage
        if currentPosition == .front,
           let cgImage = image.cgImage {
            finalImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        } else {
            finalImage = image
        }

        continuation?.resume(returning: finalImage)
    }
}

enum CameraError: LocalizedError {
    case captureFailure
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .captureFailure: "Failed to capture photo"
        case .notAuthorized: "Camera access not authorized"
        }
    }
}
