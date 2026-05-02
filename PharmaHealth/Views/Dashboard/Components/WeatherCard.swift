import SwiftUI

/// Compact weather pill for the home screen. Renders nothing until the view
/// model has either a snapshot or a state worth surfacing — avoids a flash of
/// "—" on first launch.
struct WeatherCard: View {
    @ObservedObject var viewModel: WeatherViewModel

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            EmptyView()
        case .loaded(let snapshot):
            loaded(snapshot)
        case .denied:
            deniedPrompt
        case .failed:
            EmptyView()
        }
    }

    private func loaded(_ snapshot: WeatherSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.sfSymbol)
                .font(.title3)
                .foregroundColor(.mbPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snapshot.displayTemperature())
                        .font(.headline)
                    Text(snapshot.conditionLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let place = snapshot.locationName, !place.isEmpty {
                    Text(place)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.mbSurface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current weather: \(snapshot.displayTemperature()), \(snapshot.conditionLabel)\(snapshot.locationName.map { ", \($0)" } ?? "")")
    }

    private var deniedPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("Enable location to show local weather")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.mbSurface)
        )
    }
}
