import Foundation

enum AccountPriority: String, Codable, CaseIterable, Equatable {
    case none
    case primary
    case backup
    case auxiliary

    var sortWeight: Int {
        switch self {
        case .primary:
            return 0
        case .backup:
            return 1
        case .auxiliary:
            return 2
        case .none:
            return 3
        }
    }

    func displayLabel(language: ResolvedAppLanguage = .english) -> String {
        AppStrings(language: language).priorityLabel(self)
    }
}
