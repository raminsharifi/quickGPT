import AppKit
import SwiftUI

// MARK: - Enhanced Response Window Controller
class EnhancedResponseWindowController: NSWindowController, NSWindowDelegate {
    private var eventMonitor: Any?
    
    init(responseText: String) {
        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("Response Window")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.identifier = NSUserInterfaceItemIdentifier("GPTResponseWindow")
        
        super.init(window: window)
        
        window.delegate = self
        
        let lastPrompt = UserDefaults.standard.string(forKey: "LastPrompt") ?? "Unknown Prompt"
        
        // Create the enhanced response view with content parsing
        let contentBlocks = ContentParser.parseContent(responseText)
        let responseView = EnhancedResponseView(responseText: responseText, promptText: lastPrompt)
        window.contentView = NSHostingView(rootView: responseView)
        
        // Set up escape key handling to close window
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // 53 is Escape
                self?.window?.close()
                return nil // Consume the event
            }
            return event
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowWillClose(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
// MARK: - Enhanced Response Window
struct EnhancedResponseView: View {
    @State var responseText: String
    @State var promptText: String
    @State private var isTextCopied = false
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 30
    @State private var selectedMarkdownView = true
    @State private var fontSize: CGFloat = 14
    @State private var contentBlocks: [ContentBlock] = []
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(Color(.windowBackgroundColor).opacity(AppTheme.backgroundOpacity))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                )
                .shadow(color: Color.black.opacity(0.2), radius: AppTheme.shadowRadius, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 0) {
                // Title bar with controls (unchanged from original)
                HStack {
                    // Title and prompt info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(AppTheme.primaryColor)
                                .font(.system(size: AppTheme.iconSize))
                            
                            Text("GPT Response")
                                .font(AppTheme.fontHeadline)
                                .foregroundColor(.primary)
                        }
                        
                        if !promptText.isEmpty {
                            Text("Prompt: \"\(promptText)\"")
                                .font(AppTheme.fontCaption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // Font size controls
                        Group {
                            Button(action: { fontSize = max(fontSize - 1, 10) }) {
                                Image(systemName: "textformat.size.smaller")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            
                            Button(action: { fontSize = min(fontSize + 1, 20) }) {
                                Image(systemName: "textformat.size.larger")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        // Toggle between markdown and plain text views
                        Button(action: { selectedMarkdownView.toggle() }) {
                            Image(systemName: selectedMarkdownView ? "doc.plaintext" : "doc.richtext")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(selectedMarkdownView ? "View as plain text" : "View with formatting")
                        
                        // Copy button
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(responseText, forType: .string)
                            isTextCopied = true
                            
                            // Reset the copied state after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isTextCopied = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isTextCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12))
                                Text(isTextCopied ? "Copied!" : "Copy")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(isTextCopied ? 0.2 : 0.1))
                            )
                            .foregroundColor(isTextCopied ? .green : .blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .contentShape(Rectangle())
                        .keyboardShortcut("c", modifiers: .command)
                        
                        // Close button
                        Button(action: {
                            if let window = NSApplication.shared.windows.first(where: {
                                $0.identifier == NSUserInterfaceItemIdentifier("GPTResponseWindow")
                            }) {
                                withAnimation(.easeIn(duration: AppTheme.disappearDuration)) {
                                    opacity = 0
                                    yOffset = -10
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + AppTheme.disappearDuration) {
                                    window.close()
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .contentShape(Rectangle())
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let window = NSApplication.shared.windows.first(where: {
                                $0.identifier == NSUserInterfaceItemIdentifier("GPTResponseWindow")
                            }) {
                                let newOrigin = CGPoint(
                                    x: window.frame.origin.x + value.location.x - value.startLocation.x,
                                    y: window.frame.origin.y - value.location.y + value.startLocation.y
                                )
                                window.setFrameOrigin(newOrigin)
                            }
                        }
                )
                
                Divider()
                    .padding(.horizontal, 12)
                
                // Enhanced response content with code block support
                if selectedMarkdownView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(contentBlocks) { block in
                                ContentBlockView(block: block, fontSize: fontSize)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.textBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
                    .padding(12)
                } else {
                    // Plain text view remains the same
                    ScrollView {
                        Text(responseText)
                            .padding(16)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: fontSize, design: .monospaced))
                    }
                    .background(Color(.textBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
                    .padding(12)
                }
                
                // Footer with keyboard shortcuts reference
                HStack {
                    Text("⌘C to copy • ESC to close")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 700, height: 500)
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            // Parse content blocks
            contentBlocks = ContentParser.parseContent(responseText)
            
            // Animate appearance
            withAnimation(.spring(response: AppTheme.appearDuration, dampingFraction: 0.7)) {
                opacity = 1
                yOffset = 0
            }
        }
    }
}
