import Foundation
import JavaScriptCore

enum HTMLConverterError: Error {
    case resourceNotFound
    case contextInitFailed
    case conversionFailed(String)
}

actor HTMLConverterService {
    private var context: JSContext?
    private var turndownLoaded = false
    
    init() {}
    
    private func setupContext() throws {
        if context == nil {
            context = JSContext()
            
            // Handle console.log in JS
            let logFunction: @convention(block) (String) -> Void = { message in
                print("JS Log: \(message)")
            }
            context?.objectForKeyedSubscript("console")?.setObject(logFunction, forKeyedSubscript: "log" as NSString)
        }
        
        if !turndownLoaded {
            guard let jsPath = Bundle.module.path(forResource: "turndown", ofType: "js", inDirectory: "Resources") else {
                throw HTMLConverterError.resourceNotFound
            }
            
            let jsSource = try String(contentsOfFile: jsPath, encoding: .utf8)
            context?.evaluateScript(jsSource)
            
            let initScript = """
            var turndownService = new TurndownService({
                headingStyle: 'atx',
                codeBlockStyle: 'fenced',
                bulletListMarker: '-'
            });
            """
            context?.evaluateScript(initScript)
            
            turndownLoaded = true
        }
    }
    
    func convert(_ html: String) throws -> String {
        try setupContext()
        
        guard let context = context else {
            throw HTMLConverterError.contextInitFailed
        }
        
        let data = try JSONEncoder().encode(html)
        guard let safeHtml = String(data: data, encoding: .utf8) else {
            throw HTMLConverterError.conversionFailed("Failed to encode HTML")
        }
        
        let script = "turndownService.turndown(\(safeHtml))"
        let result = context.evaluateScript(script)
        
        if result?.isUndefined == true || result?.isNull == true {
             throw HTMLConverterError.conversionFailed("JS returned null/undefined")
        }
        
        return result?.toString() ?? ""
    }
}
