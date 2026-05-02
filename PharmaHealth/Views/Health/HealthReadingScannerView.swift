import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Coordinator view that owns the OCR scan lifecycle: pick → recognize →
/// confirm → save. Keeping this orchestration in a dedicated view (rather
/// than threading state through the parent) makes it easy to launch from any
/// entry point — Health Overview, a per-metric detail screen, etc.
struct HealthReadingScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Optional metric hint. When provided, that metric is preselected on the
    /// confirmation screen if the parser didn't surface a clear winner.
    let metricHint: HealthMetricType?

    @State private var image: UIImage?
    @State private var showingCamera = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var ocrError: String?
    @State private var parsed: [ParsedHealthReading] = []
    @State private var showingConfirmation = false
    @State private var saveStatusMessage: String?

    @StateObject private var healthKit = HealthKitService()

    private let ocr = VisionOCRService()
    private let parser: HealthReadingParser = LocalRegexHealthReadingParser()

    init(metricHint: HealthMetricType? = nil) {
        self.metricHint = metricHint
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityLabel("Captured photo of health reading")
                    } else {
                        placeholder
                    }

                    actionButtons

                    if isProcessing {
                        ProgressView("Reading the image…")
                            .padding(.top, 8)
                    }

                    if let ocrError {
                        Text(ocrError)
                            .foregroundColor(.mbDanger)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }

                    Text("Always double-check scanned values against the original device. The app does not provide medical advice.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Scan Health Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraImagePicker { captured in
                    if let captured { handle(image: captured) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoSelection) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        handle(image: img)
                    }
                }
            }
            .sheet(isPresented: $showingConfirmation) {
                if let image {
                    HealthReadingConfirmationView(
                        image: image,
                        candidates: parsed,
                        metricHint: metricHint,
                        onSave: { reading, alsoSaveToHealth in
                            context.insert(reading)
                            try? context.save()
                            MBHaptics.success()
                            handlePostSave(reading: reading, alsoSaveToHealth: alsoSaveToHealth)
                        },
                        onRetake: {
                            self.image = nil
                            self.parsed = []
                        }
                    )
                }
            }
            .alert(
                "Reading saved",
                isPresented: Binding(
                    get: { saveStatusMessage != nil },
                    set: { if !$0 { saveStatusMessage = nil } }
                )
            ) {
                Button("OK") {
                    saveStatusMessage = nil
                    dismiss()
                }
            } message: {
                Text(saveStatusMessage ?? "")
            }
        }
    }

    private func handlePostSave(reading: HealthReading, alsoSaveToHealth: Bool) {
        guard alsoSaveToHealth else {
            saveStatusMessage = "Saved to PharmaHealth."
            return
        }
        Task {
            // Make sure we've requested write permission at least once.
            if !healthKit.canWrite(reading.metric) {
                await healthKit.requestWriteAuthorization()
            }
            let result = await healthKit.saveReadingToHealthKit(reading)
            switch result {
            case .saved:
                saveStatusMessage = "Saved to PharmaHealth and Apple Health."
            case .skippedNoPermission:
                saveStatusMessage = "Saved to PharmaHealth. Apple Health permission is missing — you can grant it in iOS Settings → Health → Data Access & Devices."
            case .unsupported:
                saveStatusMessage = "Saved to PharmaHealth. Apple Health isn't available on this device."
            case .failed(let message):
                saveStatusMessage = "Saved to PharmaHealth. Apple Health write failed: \(message)"
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)
            Text("Take a photo of a device reading")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("We'll detect the numbers and let you confirm before saving.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.mbSurface)
            .frame(height: 200)
            .overlay(
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
            )
            .accessibilityHidden(true)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                #if targetEnvironment(simulator)
                ocrError = "Camera is not available on the simulator. Please use Photo Library."
                #else
                showingCamera = true
                #endif
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
            }
            .buttonStyle(.mbPrimary)

            PhotosPicker(
                selection: $photoSelection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundColor(.mbPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.mbPrimary, lineWidth: 1.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    /// Performs OCR + parsing on the chosen image and triggers the
    /// confirmation flow. Always async + off-main; the UI reports progress.
    private func handle(image: UIImage) {
        self.image = image
        ocrError = nil
        parsed = []
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                let result = try await ocr.recognizeText(in: image)
                let candidates = parser.parse(text: result.joined)
                parsed = candidates
                showingConfirmation = true
                MBHaptics.selection()
            } catch let error as VisionOCRService.OCRError {
                ocrError = error.errorDescription
            } catch {
                ocrError = error.localizedDescription
            }
        }
    }
}
