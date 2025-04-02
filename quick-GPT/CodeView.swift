//import SwiftUI
//import AppKit
//
//// MARK: - Code View
//struct CodeView: View {
//    let code: String
//    let language: String
//    @State private var fontSize: CGFloat
//    @State private var isTextCopied = false
//    
//    init(code: String, language: String, fontSize: CGFloat = 14) {
//        self.code = code
//        self.language = language.lowercased()
//        self._fontSize = State(initialValue: fontSize)
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            // Header with language label and controls
//            HStack {
//                Text(language.uppercased())
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 4)
//                    .background(
//                        RoundedRectangle(cornerRadius: 4)
//                            .fill(Color.secondary.opacity(0.1))
//                    )
//                
//                Spacer()
//                
//                // Font size controls
//                HStack(spacing: 8) {
//                    Button(action: { self.fontSize = max(self.fontSize - 1, 10) }) {
//                        Image(systemName: "minus")
//                            .font(.system(size: 10))
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    
//                    Text("\(Int(fontSize))")
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
//                    
//                    Button(action: { self.fontSize = min(self.fontSize + 1, 20) }) {
//                        Image(systemName: "plus")
//                            .font(.system(size: 10))
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    
//                    // Copy button
//                    Button(action: {
//                        NSPasteboard.general.clearContents()
//                        NSPasteboard.general.setString(code, forType: .string)
//                        isTextCopied = true
//                        
//                        // Reset the copied state after 2 seconds
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                            isTextCopied = false
//                        }
//                    }) {
//                        Image(systemName: isTextCopied ? "checkmark" : "doc.on.doc")
//                            .font(.system(size: 12))
//                            .foregroundColor(isTextCopied ? .green : .primary)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    .keyboardShortcut("c", modifiers: .command)
//                }
//            }
//            .padding([.horizontal, .top], 8)
//            .padding(.bottom, 4)
//            
//            // Code content area with scroll view
//            ScrollView([.horizontal, .vertical]) {
//                Text(code)
//                    .font(.system(size: fontSize, design: .monospaced))
//                    .foregroundColor(.primary) // Ensure text is visible
//                    .padding(10)
//                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//                    .textSelection(.enabled)
//                    .lineSpacing(5) // Add some line spacing for better readability
//            }
//            .background(Color(.textBackgroundColor).opacity(0.2))
//            .cornerRadius(6)
//            .overlay(
//                RoundedRectangle(cornerRadius: 6)
//                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//            )
//            .padding(8)
//            .frame(minHeight: 100) // Ensure a minimum height
//        }
//        .background(Color(.controlBackgroundColor).opacity(0.8))
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//        )
//    }
//}
//
//// MARK: - Simple Highlighter View
//// A simpler approach that uses native SwiftUI Text instead of NSTextView
//struct SimpleHighlightedCodeView: View {
//    let code: String
//    let language: String
//    let fontSize: CGFloat
//    
//    init(code: String, language: String, fontSize: CGFloat = 14) {
//        self.code = code
//        self.language = language.lowercased()
//        self.fontSize = fontSize
//    }
//    
//    var body: some View {
//        ScrollView([.horizontal, .vertical]) {
//            VStack(alignment: .leading, spacing: 0) {
//                ForEach(Array(zip(code.split(separator: "\n", omittingEmptySubsequences: false).indices,
//                                  code.split(separator: "\n", omittingEmptySubsequences: false))),
//                       id: \.0) { index, line in
//                    HStack(alignment: .top, spacing: 0) {
//                        // Line number
//                        Text("\(index + 1)")
//                            .font(.system(size: fontSize - 2, design: .monospaced))
//                            .foregroundColor(.gray)
//                            .frame(width: 40, alignment: .trailing)
//                            .padding(.trailing, 8)
//                        
//                        // Line content
//                        Text(String(line))
//                            .font(.system(size: fontSize, design: .monospaced))
//                            .foregroundColor(.primary)
//                    }
//                    .padding(.vertical, 1)
//                }
//            }
//            .padding(10)
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .background(Color(.textBackgroundColor).opacity(0.2))
//        .textSelection(.enabled)
//    }
//}
//
//// MARK: - Full-featured Code View
//struct FullCodeView: View {
//    let code: String
//    let language: String
//    @State private var fontSize: CGFloat
//    @State private var isTextCopied = false
//    
//    init(code: String, language: String, fontSize: CGFloat = 14) {
//        self.code = code
//        self.language = language.lowercased()
//        self._fontSize = State(initialValue: fontSize)
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            // Header
//            HStack {
//                Text(language.uppercased())
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(.secondary)
//                    .padding(.horizontal, 8)
//                    .padding(.vertical, 4)
//                    .background(
//                        RoundedRectangle(cornerRadius: 4)
//                            .fill(Color.secondary.opacity(0.1))
//                    )
//                
//                Spacer()
//                
//                HStack(spacing: 8) {
//                    Button(action: { self.fontSize = max(self.fontSize - 1, 10) }) {
//                        Image(systemName: "minus")
//                            .font(.system(size: 10))
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    
//                    Text("\(Int(fontSize))")
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
//                    
//                    Button(action: { self.fontSize = min(self.fontSize + 1, 20) }) {
//                        Image(systemName: "plus")
//                            .font(.system(size: 10))
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    
//                    Button(action: {
//                        NSPasteboard.general.clearContents()
//                        NSPasteboard.general.setString(code, forType: .string)
//                        isTextCopied = true
//                        
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                            isTextCopied = false
//                        }
//                    }) {
//                        Image(systemName: isTextCopied ? "checkmark" : "doc.on.doc")
//                            .font(.system(size: 12))
//                            .foregroundColor(isTextCopied ? .green : .primary)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                    .keyboardShortcut("c", modifiers: .command)
//                }
//            }
//            .padding([.horizontal, .top], 8)
//            .padding(.bottom, 4)
//            
//            // Code content
//            SimpleHighlightedCodeView(code: code, language: language, fontSize: fontSize)
//                .padding([.horizontal, .bottom], 8)
//                .frame(minHeight: 100)
//        }
//        .background(Color(.controlBackgroundColor).opacity(0.8))
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//        )
//    }
//}
//
//// MARK: - Preview Provider
//struct CodeView_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 20) {
//            CodeView(code: """
//            def bfs(graph, start):
//                visited = set()
//                queue = deque([start])
//                
//                while queue:
//                    current = queue.popleft()
//                    if current not in visited:
//                        print(current)
//                        visited.add(current)
//                        
//                        for neighbor in graph[current]:
//                            if neighbor not in visited:
//                                queue.append(neighbor)
//            """, language: "python")
//            
//            FullCodeView(code: """
//            def bfs(graph, start):
//                visited = set()
//                queue = deque([start])
//                
//                while queue:
//                    current = queue.popleft()
//                    if current not in visited:
//                        print(current)
//                        visited.add(current)
//                        
//                        for neighbor in graph[current]:
//                            if neighbor not in visited:
//                                queue.append(neighbor)
//            """, language: "python")
//        }
//        .frame(width: 500)
//        .padding()
//        .preferredColorScheme(.dark)
//    }
//}
