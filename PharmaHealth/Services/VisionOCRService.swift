import Foundation
import Vision
import CoreImage
#if canImport(UIKit)
import UIKit
#endif

/// Wraps Apple's Vision text recognizer. We only run OCR after the user
/// commits to an image (camera capture or library selection); the live
/// camera feed is never continuously analyzed in order to save battery.
struct VisionOCRService {

    enum OCRError: Error, LocalizedError {
        case invalidImage
        case noTextFound
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .invalidImage:    return "We couldn't read that image. Please try again."
            case .noTextFound:     return "No readable text was found in this image."
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    /// Recognize text in a single image. The caller passes a `UIImage` (or
    /// `CGImage` directly via the second overload) and gets back the joined
    /// text plus the per-observation strings (handy if a parser later wants
    /// to associate values with positions).
    func recognizeText(in image: UIImage) async throws -> (joined: String, lines: [String]) {
        guard let cgImage = image.cgImage ?? image.ciImage.flatMap(Self.cgImage(from:)) else {
            throw OCRError.invalidImage
        }
        return try await recognizeText(in: cgImage)
    }

    func recognizeText(in cgImage: CGImage) async throws -> (joined: String, lines: [String]) {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.underlying(error))
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [String] = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                guard !lines.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                let joined = lines.joined(separator: "\n")
                continuation.resume(returning: (joined, lines))
            }
            // Accuracy beats speed for tiny digits on monitor LCDs.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            // Common medical-device language hints. Keeping it small avoids
            // unnecessary memory pressure on older devices.
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            // Push the actual recognition to a background queue. Vision is
            // CPU/GPU heavy and we never want it on the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.underlying(error))
                }
            }
        }
    }

    private static func cgImage(from ciImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
