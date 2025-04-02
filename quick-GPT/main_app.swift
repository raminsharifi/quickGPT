import SwiftUI
import AppKit
import KeyboardShortcuts
import Combine
import Shimmer

// MARK: - Custom Window
class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

// MARK: - Keyboard Shortcuts
extension KeyboardShortcuts.Name {
    static let togglePromptWindow = Self("togglePromptWindow")
}

// MARK: - Models
struct GPTResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
        
        struct Message: Decodable {
            let content: String
        }
    }
}

// MARK: - Theme
struct AppTheme {
    static let primaryColor = Color.blue
    static let accentColor = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let backgroundOpacity = 0.95
    static let cornerRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 15
    static let fontRegular = Font.system(size: 14)
    static let fontHeadline = Font.system(size: 16, weight: .semibold)
    static let fontCaption = Font.system(size: 12)
    static let iconSize: CGFloat = 16
    
    // Animation durations
    static let appearDuration = 0.3
    static let disappearDuration = 0.2
}

// MARK: - Main App
@main
struct GPTMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, PromptWindowDelegate {
    private var statusItem: NSStatusItem?
    private var promptWindowController: PromptWindowController?
    private var responseWindowController: NSWindowController?
    private let statusBarIconConfig = (light: "brain.head.profile", dark: "brain")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupKeyboardShortcut()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Determine if we're in dark mode
            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let iconName = isDarkMode ? statusBarIconConfig.dark : statusBarIconConfig.light
            
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "GPT")
            button.action = #selector(togglePromptWindow)
            
            // Update icon when appearance changes
            DistributedNotificationCenter.default.addObserver(
                self,
                selector: #selector(updateMenuBarIcon),
                name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil
            )
        }
        
        // Set up menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Prompt", action: #selector(togglePromptWindow), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func updateMenuBarIcon() {
        if let button = statusItem?.button {
            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let iconName = isDarkMode ? statusBarIconConfig.dark : statusBarIconConfig.light
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "GPT")
        }
    }
    
    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .togglePromptWindow) { [weak self] in
            self?.togglePromptWindow()
        }
        
        // Set default keyboard shortcut if not already set
        if KeyboardShortcuts.getShortcut(for: .togglePromptWindow) == nil {
            KeyboardShortcuts.setShortcut(.init(carbonKeyCode: 49, carbonModifiers: 768), for: .togglePromptWindow) // Option-Space
        }
    }
    
    @objc func togglePromptWindow() {
        promptWindowController = PromptWindowController()
        promptWindowController?.delegate = self
        
        promptWindowController?.showWindow(nil)
        if let window = promptWindowController?.window {
            window.makeKeyAndOrderFront(nil)
        }
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let contentView = self.promptWindowController?.window?.contentView as? NSHostingView<PromptView> {
                contentView.rootView.forceFocus()
            }
        }
    }
    
    @objc func openPreferences() {
        let preferencesWindowController = PreferencesWindowController()
        preferencesWindowController.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    @objc func openAbout() {
        let aboutWindowController = AboutWindowController()
        aboutWindowController.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    // Updated to use EnhancedResponseWindowController
    func showResponse(text: String) {
        DispatchQueue.main.async {
            // Use the enhanced response window controller instead of the original
            let responseWindowController = EnhancedResponseWindowController(responseText: text)
            self.responseWindowController = responseWindowController
            
            responseWindowController.showWindow(nil)
            responseWindowController.window?.makeKeyAndOrderFront(nil)
            
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Protocols
protocol PromptWindowDelegate: AnyObject {
    func showResponse(text: String)
}

// MARK: - Prompt Window Controller
class PromptWindowController: NSWindowController, NSWindowDelegate {
    weak var delegate: PromptWindowDelegate?
    private var promptCoordinator: PromptCoordinator!
    
    init() {
        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("Prompt Window")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        
        super.init(window: window)
        
        window.delegate = self
        
        promptCoordinator = PromptCoordinator()
        promptCoordinator.delegate = self
        
        let promptView = PromptView()
            .environmentObject(promptCoordinator)
        
        window.contentView = NSHostingView(rootView: promptView)
        window.makeKeyAndOrderFront(nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        window?.close()
    }
}

extension PromptWindowController: PromptWindowDelegate {
    func showResponse(text: String) {
        delegate?.showResponse(text: text)
    }
}


// MARK: - About Window Controller
class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "About GPT Menu Bar"
        
        super.init(window: window)
        
        let aboutView = AboutView()
        window.contentView = NSHostingView(rootView: aboutView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Coordinator
class PromptCoordinator: ObservableObject {
    weak var delegate: PromptWindowDelegate?
    
    func showResponse(text: String) {
        delegate?.showResponse(text: text)
    }
}



// MARK: - Visual Effect View Helper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}





// MARK: - Code Block Model


// MARK: - Simple Highlighter View
// A simpler approach that uses native SwiftUI Text instead of NSTextView
struct SimpleHighlightedCodeView: View {
    let code: String
    let language: String
    let fontSize: CGFloat
    
    init(code: String, language: String, fontSize: CGFloat = 14) {
        self.code = code
        self.language = language.lowercased()
        self.fontSize = fontSize
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(zip(code.split(separator: "\n", omittingEmptySubsequences: false).indices,
                                  code.split(separator: "\n", omittingEmptySubsequences: false))),
                       id: \.0) { index, line in
                    HStack(alignment: .top, spacing: 0) {
                        // Line number
                        Text("\(index + 1)")
                            .font(.system(size: fontSize - 2, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .trailing)
                            .padding(.trailing, 8)
                        
                        // Line content
                        Text(String(line))
                            .font(.system(size: fontSize, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.textBackgroundColor).opacity(0.2))
        .textSelection(.enabled)
    }
}



// MARK: - Preview Provider
struct CodeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CodeView(code: """
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
            """, language: "python")
            
            FullCodeView(code: """
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
            """, language: "python")
        }
        .frame(width: 500)
        .padding()
        .preferredColorScheme(.dark)
    }
}



