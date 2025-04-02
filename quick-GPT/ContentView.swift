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
    private var responseWindowController: ResponseWindowController?
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
    
    func showResponse(text: String) {
        DispatchQueue.main.async {
            let responseWindowController = ResponseWindowController(responseText: text)
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

// MARK: - Response Window Controller
class ResponseWindowController: NSWindowController, NSWindowDelegate {
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
        let responseView = ResponseView(responseText: responseText, promptText: lastPrompt)
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

// MARK: - Prompt View
struct PromptView: View {
    @State private var promptText = ""
    @State private var isLoading = false
    @State private var recentPrompts: [String] = UserDefaults.standard.stringArray(forKey: "RecentPrompts") ?? []
    @State private var showingRecentPrompts = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    @EnvironmentObject private var coordinator: PromptCoordinator
    
    func forceFocus() {
        self.isTextFieldFocused = true
    }
    
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
            
            VStack(spacing: 0) {
                // Drag handle
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .cornerRadius(2)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture().onChanged { value in
                    NSApplication.shared.keyWindow?.setFrameOrigin(
                        NSPoint(
                            x: NSApplication.shared.keyWindow!.frame.origin.x + value.location.x - value.startLocation.x,
                            y: NSApplication.shared.keyWindow!.frame.origin.y - value.location.y + value.startLocation.y
                        )
                    )
                })
                
                HStack {
                    // Icon with pulsing animation when loading
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(AppTheme.primaryColor)
                        .font(.system(size: AppTheme.iconSize, weight: .medium))
                        .padding(.leading, 16)
                        .shimmering(active: isLoading)
                    
                    // Main prompt input field
                    ZStack(alignment: .leading) {
                        if promptText.isEmpty && !isTextFieldFocused {
                            Text("Ask GPT something...")
                                .foregroundColor(.gray)
                                .font(AppTheme.fontRegular)
                                .padding(.vertical, 12)
                        }
                        
                        TextField("", text: $promptText, onCommit: sendPrompt)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 12)
                            .focused($isTextFieldFocused)
                            .font(AppTheme.fontRegular)
                            .onExitCommand {
                                if let window = NSApplication.shared.keyWindow {
                                    window.close()
                                }
                            }
                    }
                    
                    if !promptText.isEmpty {
                        // Recently used prompts button
                        Button(action: {
                            showingRecentPrompts.toggle()
                        }) {
                            Image(systemName: "clock")
                                .foregroundColor(.gray)
                                .font(.system(size: AppTheme.iconSize - 2))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .popover(isPresented: $showingRecentPrompts) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent Prompts")
                                    .font(AppTheme.fontHeadline)
                                    .padding()
                                
                                Divider()
                                
                                if recentPrompts.isEmpty {
                                    Text("No recent prompts")
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 4) {
                                            ForEach(recentPrompts, id: \.self) { prompt in
                                                Button(action: {
                                                    promptText = prompt
                                                    showingRecentPrompts = false
                                                }) {
                                                    Text(prompt)
                                                        .lineLimit(1)
                                                        .truncationMode(.tail)
                                                        .foregroundColor(.primary)
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 10)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .contentShape(Rectangle())
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.1))
                                                        .padding(.horizontal, 2)
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .frame(width: 300, height: min(CGFloat(recentPrompts.count * 40), 200))
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    
                    if isLoading {
                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .padding(.trailing, 16)
                    } else if !promptText.isEmpty {
                        // Send button
                        Button(action: sendPrompt) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(AppTheme.primaryColor)
                                .font(.system(size: AppTheme.iconSize, weight: .medium))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 700, height: 60)
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            withAnimation(.spring(response: AppTheme.appearDuration, dampingFraction: 0.7)) {
                opacity = 1
                yOffset = 0
            }
            
            // Load recent prompts
            recentPrompts = UserDefaults.standard.stringArray(forKey: "RecentPrompts") ?? []
            
            // Focus on the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            withAnimation(.easeIn(duration: AppTheme.disappearDuration)) {
                opacity = 0
                yOffset = -10
            }
        }
    }
    
    private func sendPrompt() {
        guard !promptText.isEmpty else { return }
        
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        promptText = ""
        isLoading = true
        
        // Save to recent prompts
        saveToRecentPrompts(prompt: prompt)
        
        // Store the prompt for reference
        UserDefaults.standard.set(prompt, forKey: "LastPrompt")
        
        // Close the prompt window
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView is NSHostingView<PromptView> }) {
                window.close()
            }
        }
        
        // Make API request
        Task {
            do {
                let response = try await requestGPTResponse(prompt: prompt)
                isLoading = false
                
                DispatchQueue.main.async {
                    coordinator.showResponse(text: response)
                }
            } catch {
                isLoading = false
                DispatchQueue.main.async {
                    coordinator.showResponse(text: "Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveToRecentPrompts(prompt: String) {
        var prompts = UserDefaults.standard.stringArray(forKey: "RecentPrompts") ?? []
        
        // Remove if already exists to avoid duplicates
        prompts.removeAll(where: { $0 == prompt })
        
        // Add to the beginning
        prompts.insert(prompt, at: 0)
        
        // Keep only the 15 most recent
        if prompts.count > 15 {
            prompts = Array(prompts.prefix(15))
        }
        
        UserDefaults.standard.set(prompts, forKey: "RecentPrompts")
        self.recentPrompts = prompts
    }
    
    private func requestGPTResponse(prompt: String) async throws -> String {
        // Network connectivity check
        guard let reachable = try? await checkNetworkConnectivity() else {
            return "Network connectivity issue. Please check your internet connection and try again."
        }
        
        if !reachable {
            return "No internet connection. Please check your network settings and try again."
        }
        
        // Get API credentials
        let apiKey = UserDefaults.standard.string(forKey: "GPTAPIKey") ?? ""
        if apiKey.isEmpty {
            return "API Key not configured. Please set your API key in Preferences."
        }
        
        let urlString = UserDefaults.standard.string(forKey: "GPTEndpoint") ?? "https://api.openai.com/v1/chat/completions"
        
        guard let url = URL(string: urlString) else {
            return "Invalid API endpoint URL. Please check the URL in Preferences."
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45 // Increased timeout
        
        // Request body with system message for better responses
        let requestBody: [String: Any] = [
            "model": UserDefaults.standard.string(forKey: "GPTModel") ?? "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant responding to queries from a menu bar app."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Send request with retries
            let (data, response) = try await sendRequestWithRetry(request: request, maxRetries: 2)
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success, continue processing
                    break
                case 401:
                    return "Authorization failed. Please check your API key in Preferences."
                case 429:
                    return "Rate limit exceeded. Please try again later."
                case 500...599:
                    return "Server error. The GPT service might be experiencing issues."
                default:
                    return "HTTP Error: Status \(httpResponse.statusCode)"
                }
            }
            
            // Parse response
            let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)
            return gptResponse.choices.first?.message.content ?? "No response content received"
        } catch let decodingError as DecodingError {
            return "Error parsing response: \(decodingError.localizedDescription)"
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network settings."
                case .timedOut:
                    return "Request timed out. The server might be busy or unreachable."
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    return "Cannot connect to the API server. Please check your network connection and try again."
                default:
                    return "Network error: \(urlError.localizedDescription)"
                }
            }
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // Helper function to check network connectivity
    private func checkNetworkConnectivity() async throws -> Bool {
        let url = URL(string: "https://www.apple.com")!
        let request = URLRequest(url: url, timeoutInterval: 5)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // Helper function for retry logic
    private func sendRequestWithRetry(request: URLRequest, maxRetries: Int) async throws -> (Data, URLResponse) {
        var retries = 0
        var lastError: Error? = nil
        
        while retries <= maxRetries {
            do {
                return try await URLSession.shared.data(for: request)
            } catch {
                lastError = error
                retries += 1
                
                if retries <= maxRetries {
                    // Exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retries)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
}

// MARK: - Response View
struct ResponseView: View {
    @State var responseText: String
    @State var promptText: String
    @State private var isTextCopied = false
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 30
    @State private var selectedMarkdownView = true
    @State private var fontSize: CGFloat = 14
    
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
                // Title bar with controls
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
                
                // Response content with conditional view based on selected view mode
                if selectedMarkdownView {
                    ScrollView {
                        Text(LocalizedStringKey(responseText))
                            .padding(16)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.system(size: fontSize))
                    }
                    .background(Color(.textBackgroundColor).opacity(0.3))
                    .cornerRadius(12)
                    .padding(12)
                } else {
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
            // Animate appearance
            withAnimation(.spring(response: AppTheme.appearDuration, dampingFraction: 0.7)) {
                opacity = 1
                yOffset = 0
            }
        }
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

// MARK: - Preferences
class PreferencesWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Preferences"
        window.setFrameAutosaveName("Preferences Window")
        
        super.init(window: window)
        
        let preferencesView = PreferencesView()
        window.contentView = NSHostingView(rootView: preferencesView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PreferencesView: View {
    @AppStorage("GPTAPIKey") private var apiKey = ""
    @AppStorage("GPTEndpoint") private var endpoint = "https://api.openai.com/v1/chat/completions"
    @AppStorage("GPTModel") private var model = "gpt-4"
    @AppStorage("SystemPrompt") private var systemPrompt = "You are a helpful assistant responding to queries from a menu bar app."
    @State private var isApiKeyVisible = false
    @State private var selectedTab = 0
    @State private var modelOptions = ["gpt-4", "gpt-4o", "gpt-3.5-turbo", "claude-3-opus", "claude-3-sonnet"]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // API Settings
            Form {
                Section(header: Text("API Configuration").font(.headline)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Endpoint")
                            .font(.system(size: 12, weight: .medium))
                        
                        TextField("API Endpoint", text: $endpoint)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.system(size: 12, weight: .medium))
                        
                        HStack {
                            if isApiKeyVisible {
                                TextField("API Key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 14))
                            } else {
                                SecureField("API Key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 14))
                            }
                            
                            Button(action: { isApiKeyVisible.toggle() }) {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.system(size: 12, weight: .medium))
                        
                        HStack {
                            Picker("", selection: $model) {
                                ForEach(modelOptions, id: \.self) { modelOption in
                                    Text(modelOption).tag(modelOption)
                                }
                            }
                            .labelsHidden()
                            
                            TextField("Custom model", text: $model)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Prompt")
                            .font(.system(size: 12, weight: .medium))
                        
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 14))
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.2))
                    }
                }
                
                Section(header: Text("Keyboard Shortcut").font(.headline)) {
                    HStack {
                        Text("Toggle App")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .togglePromptWindow)
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(0)
            
            // Appearance tab
            VStack(spacing: 20) {
                Text("Appearance settings will be added in a future update.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            .tag(1)
            
            // History tab
            VStack(spacing: 20) {
                Text("Conversation history will be added in a future update.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(2)
            
            // About tab
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .padding(20)
        .frame(width: 550, height: 350)
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.primaryColor)
                
                Text("GPT Menu Bar")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Version 1.1.0")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            
            VStack(spacing: 10) {
                Text("A sleek menu bar app for quick access to AI assistants")
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Works with OpenAI GPT models and compatible API endpoints")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 10)
            
            Text("© 2025 • All Rights Reserved")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
