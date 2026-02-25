import UIKit
import Observation

@Observable
final class SweatCamViewModel {
    var capturedImage: UIImage?
    var watermarkedImage: UIImage?
    var caption: String = ""
    var showConfirmation = false
    var isSubmitting = false
    var error: String?

    let cameraService = CameraService()

    // MARK: - Camera Lifecycle

    func setupCamera() async {
        await cameraService.checkAuthorization()
        if cameraService.isAuthorized {
            cameraService.setupSession()
            cameraService.startSession()
        }
    }

    func teardownCamera() {
        cameraService.stopSession()
    }

    // MARK: - Photo Capture

    func capturePhoto() async {
        do {
            let image = try await cameraService.capturePhoto()
            capturedImage = image
            watermarkedImage = applyWatermark(to: image)
            showConfirmation = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func retakePhoto() {
        capturedImage = nil
        watermarkedImage = nil
        caption = ""
        showConfirmation = false
        error = nil
    }

    /// Returns true if the workout was saved successfully.
    func confirmPhoto(dataService: any DataServiceProtocol) async -> Bool {
        guard let watermarkedImage,
              let photoData = watermarkedImage.jpegData(compressionQuality: 0.7) else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            try await dataService.logWorkout(
                photoData: photoData,
                caption: trimmedCaption.isEmpty ? nil : trimmedCaption
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Watermark

    private func applyWatermark(to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            image.draw(at: .zero)

            let text = Date.now.watermarkString
            let fontSize: CGFloat = image.size.width * 0.035
            let padding: CGFloat = image.size.width * 0.04

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
            shadow.shadowOffset = CGSize(width: 1, height: 1)
            shadow.shadowBlurRadius = 4

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .shadow: shadow
            ]

            let textSize = (text as NSString).size(withAttributes: attributes)
            let textOrigin = CGPoint(
                x: padding,
                y: image.size.height - textSize.height - padding
            )

            (text as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }
}
