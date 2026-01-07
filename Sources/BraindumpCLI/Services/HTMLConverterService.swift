import Foundation

public enum HTMLConverterError: Error {
    case conversionFailed(String)
}

public actor HTMLConverterService {
    
    public init() {}
    
    public func convert(_ html: String) throws -> String {
        // Basic HTML to Markdown conversion using String manipulation and Regex
        // Apple Notes HTML is usually relatively simple.
        
        var text = html
        
        // 1. Remove meta/html/body tags wrapping
        text = text.replacingOccurrences(of: "<!DOCTYPE html>", with: "")
        text = text.replacingOccurrences(of: "<html>", with: "")
        text = text.replacingOccurrences(of: "</html>", with: "")
        text = text.replacingOccurrences(of: "<body>", with: "")
        text = text.replacingOccurrences(of: "</body>", with: "")
        text = text.replacingOccurrences(of: "<head>.*?</head>", with: "", options: .regularExpression)
        
        // 2. Handle specific formatting tags
        
        // Bold checks: <b>, <strong>
        text = text.replacingOccurrences(of: "<b>", with: "**")
        text = text.replacingOccurrences(of: "</b>", with: "**")
        text = text.replacingOccurrences(of: "<strong>", with: "**")
        text = text.replacingOccurrences(of: "</strong>", with: "**")
        
        // Italic: <i>, <em>
        text = text.replacingOccurrences(of: "<i>", with: "_")
        text = text.replacingOccurrences(of: "</i>", with: "_")
        text = text.replacingOccurrences(of: "<em>", with: "_")
        text = text.replacingOccurrences(of: "</em>", with: "_")
        
        // Headers <h1>...<h6>
        // Note: Regex approach is simplistic but works for well-formed simple HTML
        for i in 1...6 {
            let headerMarker = String(repeating: "#", count: i)
            text = text.replacingOccurrences(of: "<h\(i)>", with: "\n\(headerMarker) ", options: .caseInsensitive)
            text = text.replacingOccurrences(of: "</h\(i)>", with: "\n", options: .caseInsensitive)
        }
        
        // Links <a href="...">text</a>
        // Pattern: <a[^>]*href="([^"]*)"[^>]*>(.*?)</a>
        // Replacement: [$2]($1)
        // Note: simple regex, might fail on complex attributes
        try? text = text.replacingOccurrences(of: "<a[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)
        
        // Lists
        // <ul>, <ol>, <li>
        // This is tricky with regex because state (indentation) is hard.
        // For now, simpler approach:
        text = text.replacingOccurrences(of: "<ul>", with: "\n")
        text = text.replacingOccurrences(of: "</ul>", with: "\n")
        text = text.replacingOccurrences(of: "<ol>", with: "\n")
        text = text.replacingOccurrences(of: "</ol>", with: "\n")
        text = text.replacingOccurrences(of: "<li>", with: "- ")
        text = text.replacingOccurrences(of: "</li>", with: "\n")
        
        // Paragraphs and Divs
        text = text.replacingOccurrences(of: "<p>", with: "\n")
        text = text.replacingOccurrences(of: "</p>", with: "\n")
        text = text.replacingOccurrences(of: "<div>", with: "\n")
        text = text.replacingOccurrences(of: "</div>", with: "\n")
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n")
        
        // 4. Strip remaining tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 3. Decode HTML Entities
        // Only basic ones or use a helper
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        // 5. Cleanup whitespace
        // Remove repeated newlines
        // text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression) 
        // Trim
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
}
