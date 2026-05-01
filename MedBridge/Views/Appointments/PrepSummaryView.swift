import SwiftUI
import UIKit

struct PrepSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let appointment: Appointment
    @State var summary: String

    @StateObject private var subscription = SubscriptionManager.shared
    @State private var isEditing = false
    @State private var showingPaywall = false
    @State private var pdfURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isEditing {
                    TextEditor(text: $summary)
                        .frame(minHeight: 400)
                        .font(.body)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    Text(summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .background(Color.mbBackground.ignoresSafeArea())
        .navigationTitle("Prep Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        appointment.prepSummary = summary
                        try? context.save()
                    }
                    isEditing.toggle()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: summary) {
                        Label("Share text", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        exportPDF()
                    } label: {
                        Label(
                            subscription.canExportPDF ? "Export PDF" : "Export PDF (Premium)",
                            systemImage: subscription.canExportPDF ? "doc.fill" : "lock.fill"
                        )
                    }
                    Button {
                        printSummary()
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Share options")
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $pdfURL) { url in
            ShareSheet(items: [url])
        }
    }

    private func exportPDF() {
        guard subscription.canExportPDF else {
            showingPaywall = true
            return
        }
        let data = PDFExporter.exportPrepSummary(appointment: appointment, summary: summary)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("MedBridge-Prep-\(appointment.doctorName).pdf")
        do {
            try data.write(to: url)
            pdfURL = url
        } catch {
            // ignore
        }
    }

    private func printSummary() {
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "MedBridge Prep Summary"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = summary
        controller.present(animated: true, completionHandler: nil)
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
