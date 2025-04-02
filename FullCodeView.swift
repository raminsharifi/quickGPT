//
//  FullCodeView.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-02.
//
import AppKit
import SwiftUI

struct FullCodeView: View {
    let code: String
    let language: String
    @State private var fontSize: CGFloat
    @State private var isTextCopied = false
    
    init(code: String, language: String, fontSize: CGFloat = 14) {
        self.code = code
        self.language = language.lowercased()
        self._fontSize = State(initialValue: fontSize)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { self.fontSize = max(self.fontSize - 1, 10) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Text("\(Int(fontSize))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button(action: { self.fontSize = min(self.fontSize + 1, 20) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        isTextCopied = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isTextCopied = false
                        }
                    }) {
                        Image(systemName: isTextCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(isTextCopied ? .green : .primary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .keyboardShortcut("c", modifiers: .command)
                }
            }
            .padding([.horizontal, .top], 8)
            .padding(.bottom, 4)
            
            // Code content
            SimpleHighlightedCodeView(code: code, language: language, fontSize: fontSize)
                .padding([.horizontal, .bottom], 8)
                .frame(minHeight: 100)
        }
        .background(Color(.controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
