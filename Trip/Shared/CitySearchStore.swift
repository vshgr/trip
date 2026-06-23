import MapKit
import SwiftUI

struct CitySuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
}

@MainActor
final class CitySearchStore: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [CitySuggestion] = []
    @Published var isSearching = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }

        isSearching = true
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.prefix(8).map { result in
            let title = result.title
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? result.title
            let subtitle = result.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

            return CitySuggestion(
                id: "\(result.title)-\(result.subtitle)",
                name: title,
                subtitle: subtitle
            )
        }

        Task { @MainActor in
            self.suggestions = Array(
                Dictionary(grouping: results, by: \.name)
                    .compactMap { $0.value.first }
                    .prefix(6)
            )
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
            self.isSearching = false
        }
    }

    private let completer = MKLocalSearchCompleter()
}
