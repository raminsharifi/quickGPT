import SwiftUI
import AppKit

// MARK: - Code Block Model
struct CodeBlock: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let language: String
    
    static func == (lhs: CodeBlock, rhs: CodeBlock) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Content Block
enum ContentBlock: Identifiable, Equatable {
    case text(String)
    case code(CodeBlock)
    
    var id: UUID {
        switch self {
        case .text:
            return UUID()
        case .code(let codeBlock):
            return codeBlock.id
        }
    }
    
    static func == (lhs: ContentBlock, rhs: ContentBlock) -> Bool {
        switch (lhs, rhs) {
        case (.text(let lhsText), .text(let rhsText)):
            return lhsText == rhsText
        case (.code(let lhsCode), .code(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}

// MARK: - Content Parser
class ContentParser {
    static func parseContent(_ content: String) -> [ContentBlock] {
        // Debug print the content to check if it's empty
        print("Content to parse: \(content.prefix(100))... (length: \(content.count))")
        
        var blocks: [ContentBlock] = []
        
        // If content is empty, return empty array
        if content.isEmpty {
            return blocks
        }
        
        // Regular expression to match code blocks with language specification
        // Matches patterns like ```python ... ``` or ```javascript ... ```
        let codeBlockPattern = "```([a-zA-Z0-9+#]*)\\s*\\n([\\s\\S]*?)```"
        
        do {
            let regex = try NSRegularExpression(pattern: codeBlockPattern, options: [])
            let nsContent = content as NSString
            let fullRange = NSRange(location: 0, length: nsContent.length)
            let matches = regex.matches(in: content, options: [], range: fullRange)
            
            print("Found \(matches.count) code blocks")
            
            // If no code blocks, just return the text
            if matches.isEmpty {
                blocks.append(.text(content))
                return blocks
            }
            
            var lastEndIndex = 0
            
            for match in matches {
                // Get the text before this code block
                if match.range.location > lastEndIndex {
                    let textRange = NSRange(location: lastEndIndex, length: match.range.location - lastEndIndex)
                    let textBefore = nsContent.substring(with: textRange)
                    
                    if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        blocks.append(.text(textBefore))
                    }
                }
                
                // Get language and code
                let languageRange = match.range(at: 1)
                let codeRange = match.range(at: 2)
                
                let language = languageRange.location != NSNotFound ? nsContent.substring(with: languageRange) : ""
                let code = codeRange.location != NSNotFound ? nsContent.substring(with: codeRange) : ""
                
                print("Extracted code block - Language: \(language), Code length: \(code.count)")
                
                // Create code block
                let codeBlock = CodeBlock(code: code, language: language.isEmpty ? "text" : language)
                blocks.append(.code(codeBlock))
                
                lastEndIndex = match.range.location + match.range.length
            }
            
            // Add remaining text after the last code block
            if lastEndIndex < nsContent.length {
                let textRange = NSRange(location: lastEndIndex, length: nsContent.length - lastEndIndex)
                let textAfter = nsContent.substring(with: textRange)
                
                if !textAfter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(textAfter))
                }
            }
        } catch {
            print("Error parsing code blocks: \(error)")
            
            // If regex fails, just return the text as is
            blocks.append(.text(content))
        }
        
        // Debug print the parsed blocks
        print("Parsed \(blocks.count) content blocks")
        for (index, block) in blocks.enumerated() {
            switch block {
            case .text(let text):
                print("Block \(index): Text block with \(text.count) characters")
            case .code(let code):
                print("Block \(index): Code block with language '\(code.language)' and \(code.code.count) characters")
            }
        }
        
        return blocks
    }
    
    // Helper method to directly extract code blocks for debugging
    static func extractCodeBlocks(from content: String) -> [(language: String, code: String)] {
        var blocks: [(language: String, code: String)] = []
        
        do {
            let regex = try NSRegularExpression(pattern: "```([a-zA-Z0-9+#]*)\\s*\\n([\\s\\S]*?)```", options: [])
            let nsContent = content as NSString
            let fullRange = NSRange(location: 0, length: nsContent.length)
            let matches = regex.matches(in: content, options: [], range: fullRange)
            
            for match in matches {
                let languageRange = match.range(at: 1)
                let codeRange = match.range(at: 2)
                
                let language = languageRange.location != NSNotFound ? nsContent.substring(with: languageRange) : ""
                let code = codeRange.location != NSNotFound ? nsContent.substring(with: codeRange) : ""
                
                blocks.append((language: language, code: code))
            }
        } catch {
            print("Error extracting code blocks: \(error)")
        }
        
        return blocks
    }
}

// MARK: - Enhanced Content Block View
struct ContentBlockView: View {
    let block: ContentBlock
    let fontSize: CGFloat
    
    var body: some View {
        switch block {
        case .text(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: fontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
            
        case .code(let codeBlock):
            // Use our new improved code view
            FullCodeView(code: codeBlock.code, language: codeBlock.language, fontSize: fontSize)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - Debug View for Content Parsing
struct ContentParserDebugView: View {
    let content: String
    @State private var parsedBlocks: [ContentBlock] = []
    @State private var extractedCodeBlocks: [(language: String, code: String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Parser Debug")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Original Content (length: \(content.count))")
                .font(.headline)
            
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 150)
            
            Divider()
            
            Text("Parsed Blocks: \(parsedBlocks.count)")
                .font(.headline)
            
            ForEach(Array(parsedBlocks.enumerated()), id: \.element.id) { index, block in
                VStack(alignment: .leading, spacing: 4) {
                    switch block {
                    case .text(let text):
                        Text("Block \(index): Text (\(text.count) chars)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(text.prefix(100))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        
                    case .code(let codeBlock):
                        Text("Block \(index): Code - \(codeBlock.language) (\(codeBlock.code.count) chars)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        FullCodeView(code: codeBlock.code, language: codeBlock.language, fontSize: 12)
                            .frame(height: 100)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
            
            Divider()
            
            Text("Direct Code Block Extraction: \(extractedCodeBlocks.count)")
                .font(.headline)
            
            ForEach(Array(extractedCodeBlocks.enumerated()), id: \.offset) { index, block in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block \(index): \(block.language) (\(block.code.count) chars)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FullCodeView(code: block.code, language: block.language, fontSize: 12)
                        .frame(height: 100)
                }
                .padding(8)
                .background(Color.green.opacity(0.05))
                .cornerRadius(8)
            }
            
            Button("Reparse Content") {
                parsedBlocks = ContentParser.parseContent(content)
                extractedCodeBlocks = ContentParser.extractCodeBlocks(from: content)
            }
            .padding()
        }
        .padding()
        .onAppear {
            parsedBlocks = ContentParser.parseContent(content)
            extractedCodeBlocks = ContentParser.extractCodeBlocks(from: content)
        }
    }
}

struct ContentParser_Previews: PreviewProvider {
    static var previews: some View {
        ContentParserDebugView(content: """
        # Breadth-First Search (BFS) Algorithm
        
        Breadth-First Search is a graph traversal algorithm that explores all vertices at the current depth before moving on to vertices at the next depth level.
        
        ## Python Implementation
        
        ```python
        from collections import deque
        
        def bfs(graph, start):
            visited = set()
            queue = deque([start])
            
            while queue:
                current = queue.popleft()
                if current not in visited:
                    print(current)
                    visited.add(current)
                    
                    for neighbor in graph[current]:
                        if neighbor not in visited:
                            queue.append(neighbor)
        ```
        
        ## Swift Implementation
        
        ```swift
        func bfs(graph: [String: [String]], start: String) {
            var visited = Set<String>()
            var queue = [start]
            
            while !queue.isEmpty {
                let current = queue.removeFirst()
                
                if !visited.contains(current) {
                    print(current)
                    visited.insert(current)
                    
                    for neighbor in graph[current] ?? [] {
                        if !visited.contains(neighbor) {
                            queue.append(neighbor)
                        }
                    }
                }
            }
        }
        ```
        """)
        .frame(width: 800, height: 1000)
    }
}
