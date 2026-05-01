import Foundation
import UIKit

struct PDFExporter {

    static func exportPrepSummary(appointment: Appointment, summary: String) -> Data {
        // A4 page in points (1pt = 1/72 inch). A4 = 595 x 842 points.
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.preferredFont(forTextStyle: .title1)
        let headerFont = UIFont.preferredFont(forTextStyle: .headline)
        let bodyFont = UIFont.systemFont(ofSize: 14)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 40
            var y: CGFloat = margin

            let title = "MedBridge — Appointment Prep"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            (title as NSString).draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: titleAttrs
            )
            y += titleFont.lineHeight + 8

            let header = "Dr. \(appointment.doctorName)\n\(dateFormatter.string(from: appointment.date))"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            let headerSize = (header as NSString).boundingRect(
                with: CGSize(width: pageRect.width - margin * 2, height: .infinity),
                options: [.usesLineFragmentOrigin],
                attributes: headerAttrs,
                context: nil
            ).size
            (header as NSString).draw(
                in: CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: headerSize.height),
                withAttributes: headerAttrs
            )
            y += headerSize.height + 16

            // Divider
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.separator.setStroke()
            path.lineWidth = 1
            path.stroke()
            y += 16

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.label
            ]

            let availableWidth = pageRect.width - margin * 2
            var remainingHeight = pageRect.height - y - margin

            let bodySize = (summary as NSString).boundingRect(
                with: CGSize(width: availableWidth, height: .infinity),
                options: [.usesLineFragmentOrigin],
                attributes: bodyAttrs,
                context: nil
            ).size

            if bodySize.height <= remainingHeight {
                (summary as NSString).draw(
                    in: CGRect(x: margin, y: y, width: availableWidth, height: bodySize.height),
                    withAttributes: bodyAttrs
                )
            } else {
                // Naive paginated rendering — split by lines.
                let lines = summary.components(separatedBy: "\n")
                var lineIdx = 0
                while lineIdx < lines.count {
                    var pageText = ""
                    while lineIdx < lines.count {
                        let candidate = pageText.isEmpty ? lines[lineIdx] : pageText + "\n" + lines[lineIdx]
                        let h = (candidate as NSString).boundingRect(
                            with: CGSize(width: availableWidth, height: .infinity),
                            options: [.usesLineFragmentOrigin],
                            attributes: bodyAttrs,
                            context: nil
                        ).size.height
                        if h > remainingHeight { break }
                        pageText = candidate
                        lineIdx += 1
                    }
                    let h = (pageText as NSString).boundingRect(
                        with: CGSize(width: availableWidth, height: .infinity),
                        options: [.usesLineFragmentOrigin],
                        attributes: bodyAttrs,
                        context: nil
                    ).size.height
                    (pageText as NSString).draw(
                        in: CGRect(x: margin, y: y, width: availableWidth, height: h),
                        withAttributes: bodyAttrs
                    )
                    if lineIdx < lines.count {
                        context.beginPage()
                        y = margin
                        remainingHeight = pageRect.height - margin * 2
                    }
                }
            }
        }
    }
}
