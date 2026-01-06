import Foundation

enum IDResolverError: Error {
    case invalidIndex(Int)
    case notFound(String)
    case ambiguous(String, matches: [String])
}

struct IDResolver {
    static func resolve(_ query: String, from reminders: [Reminder]) throws -> Reminder {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let index = Int(trimmed) {
            let arrayIndex = index - 1
            guard arrayIndex >= 0 && arrayIndex < reminders.count else {
                throw IDResolverError.invalidIndex(index)
            }
            return reminders[arrayIndex]
        }
        
        if let exactMatch = reminders.first(where: { $0.id == trimmed }) {
            return exactMatch
        }
        
        if trimmed.count >= 4 {
            let prefixMatches = reminders.filter { $0.id.lowercased().hasPrefix(trimmed.lowercased()) }
            if prefixMatches.count == 1 {
                return prefixMatches[0]
            } else if prefixMatches.count > 1 {
                throw IDResolverError.ambiguous(trimmed, matches: prefixMatches.map { $0.title })
            }
        }
        
        let titleExactMatches = reminders.filter { $0.title.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        if titleExactMatches.count == 1 {
            return titleExactMatches[0]
        }
        if titleExactMatches.count > 1 {
             throw IDResolverError.ambiguous(trimmed, matches: titleExactMatches.map { $0.title })
        }
        
        let titlePartialMatches = reminders.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
        if titlePartialMatches.count == 1 {
            return titlePartialMatches[0]
        } else if titlePartialMatches.count > 1 {
            let startsWithMatches = titlePartialMatches.filter { $0.title.range(of: trimmed, options: [.anchored, .caseInsensitive]) != nil }
            if startsWithMatches.count == 1 {
                return startsWithMatches[0]
            }
            throw IDResolverError.ambiguous(trimmed, matches: titlePartialMatches.map { $0.title })
        }
        
        throw IDResolverError.notFound(trimmed)
    }
}
