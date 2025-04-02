import SwiftUI
import AppKit
import KeyboardShortcuts
import Combine
import Shimmer

// Custom NSWindow subclass to allow borderless windows to become key windows
class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

// Define keyboard shortcut extension
extension KeyboardShortcuts.Name {
    static let togglePromptWindow = Self("togglePromptWindow")
}

// Model for API response
struct GPTResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
        
        struct Message: Decodable {
            let content: String
        }
    }
}

// Main app class
@main
struct GPTMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// App delegate to handle application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate, PromptWindowDelegate {
    var statusItem: NSStatusItem?
    var promptWindowController: PromptWindowController?
    var responseWindowController: ResponseWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "GPT")
            button.action = #selector(togglePromptWindow)
        }
        
        // Set up menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open", action: #selector(togglePromptWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        // Set up keyboard shortcut
        KeyboardShortcuts.onKeyUp(for: .togglePromptWindow) { [weak self] in
            self?.togglePromptWindow()
        }
        
        // Set default keyboard shortcut if not already set
        if KeyboardShortcuts.getShortcut(for: .togglePromptWindow) == nil {
            KeyboardShortcuts.setShortcut(.init(carbonKeyCode: 49, carbonModifiers: 768), for: .togglePromptWindow) // Option-Space
        }
    }
    
    @objc func togglePromptWindow() {
        // Always create a new prompt window controller to reset state
        promptWindowController = PromptWindowController()
        promptWindowController?.delegate = self
        
        // Explicitly show and focus the window
        promptWindowController?.showWindow(nil)
        if let window = promptWindowController?.window {
            window.makeKeyAndOrderFront(nil)
        }
        
        // Bring app to front and activate it
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Ensure focus after a short delay to let the window render
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
    
    func showResponse(text: String) {
        print("Showing response: \(text.prefix(20))...")  // Debug log
        
        // Run on main thread to be safe
        DispatchQueue.main.async {
            // Always create a new response window controller for each response
            // This ensures we don't show old responses
            let responseWindowController = ResponseWindowController(responseText: text)
            
            // Keep a reference to prevent it from being deallocated
            self.responseWindowController = responseWindowController
            
            // Show the window and make it key
            responseWindowController.showWindow(nil)
            responseWindowController.window?.makeKeyAndOrderFront(nil)
            
            // Ensure app is in front
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

// Protocol for prompt window communication
protocol PromptWindowDelegate: AnyObject {
    func showResponse(text: String)
}

// Window controller for the prompt input
class PromptWindowController: NSWindowController, NSWindowDelegate, PromptWindowDelegate {
    weak var delegate: PromptWindowDelegate?
    private var promptCoordinator: PromptCoordinator!
    
    init() {
        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 60),
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
        window.makeFirstResponder(nil) // Clear first responder to ensure our text field gets focus
        
        super.init(window: window)
        
        window.delegate = self
        
        // Create a coordinator instance and set the delegate
        promptCoordinator = PromptCoordinator()
        promptCoordinator.delegate = self
        
        // Use a hosted promptView with environment object for communication
        let promptView = PromptView()
            .environmentObject(promptCoordinator)
        
        window.contentView = NSHostingView(rootView: promptView)
        
        // Force the window to become key to ensure it receives keyboard input
        window.makeKeyAndOrderFront(nil)
        
        // Add a slight delay to ensure the UI is fully loaded before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        window?.close()
    }
    
    func showResponse(text: String) {
        delegate?.showResponse(text: text)
    }
}

// Window controller for the response display
class ResponseWindowController: NSWindowController, NSWindowDelegate {
    private var eventMonitor: Any?
    
    init(responseText: String) {
        print("Creating response window with text: \(responseText.prefix(20))...")  // Debug log
        
        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
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
        
        // Set a unique identifier to help with window management
        window.identifier = NSUserInterfaceItemIdentifier("GPTResponseWindow")
        
        super.init(window: window)
        
        window.delegate = self
        
        // Get the last prompt to display in the response window
        let lastPrompt = UserDefaults.standard.string(forKey: "LastPrompt") ?? "Unknown Prompt"
        let responseView = ResponseView(responseText: responseText, promptText: lastPrompt)
        window.contentView = NSHostingView(rootView: responseView)
        
        // Set up escape key handling to close window
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // 53 is the key code for Escape
                self?.window?.close()
                return nil // Consume the event
            }
            return event
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateResponse(text: String) {
        if let contentView = window?.contentView as? NSHostingView<ResponseView> {
            contentView.rootView.responseText = text
        }
    }
    
    // Clean up event monitor when window is closed
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

// Coordinator class to handle delegation between SwiftUI and AppKit
class PromptCoordinator: ObservableObject {
    weak var delegate: PromptWindowDelegate?
    
    func showResponse(text: String) {
        delegate?.showResponse(text: text)
    }
}

// SwiftUI view for the prompt input
struct PromptView: View {
    @State private var promptText = ""
    @State private var isLoading = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    @EnvironmentObject private var coordinator: PromptCoordinator
    
    // Method to force focus from outside
    func forceFocus() {
        self.isTextFieldFocused = true
    }
    
    var body: some View {
        ZStack {
            // Background with blur and rounded corners
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.windowBackgroundColor).opacity(0.9))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
            
            VStack(spacing: 0) {
                HStack {
                    // Custom drag handle for window movement
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
                    // Move the window when dragging the handle
                    NSApplication.shared.keyWindow?.setFrameOrigin(
                        NSPoint(
                            x: NSApplication.shared.keyWindow!.frame.origin.x + value.location.x - value.startLocation.x,
                            y: NSApplication.shared.keyWindow!.frame.origin.y - value.location.y + value.startLocation.y
                        )
                    )
                })
                
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.leading, 16)
                        .shimmering(active: isLoading)
                    
                    TextField("Ask GPT something...", text: $promptText, onCommit: sendPrompt)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 12)
                        .focused($isTextFieldFocused)
                        .font(.system(size: 14))
                        .onExitCommand {
                            // Handle escape key explicitly
                            if let window = NSApplication.shared.keyWindow {
                                window.close()
                            }
                        }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .padding(.trailing, 16)
                    } else if !promptText.isEmpty {
                        Button(action: sendPrompt) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 600, height: 60)
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                opacity = 1
                yOffset = 0
            }
            
            // Focus on the text field after a short delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 0
                yOffset = -10
            }
        }
    }
    
    private func sendPrompt() {
        guard !promptText.isEmpty else { return }
        
        let prompt = promptText
        promptText = ""
        isLoading = true
        
        // Store the prompt for future reference
        UserDefaults.standard.set(prompt, forKey: "LastPrompt")
        
        // Close the prompt window immediately after submitting
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView is NSHostingView<PromptView> }) {
                window.close()
            }
        }
        
        // Make API request to GPT server
        Task {
            do {
                print("Sending prompt: \(prompt)")  // Debug log
                let response = try await requestGPTResponse(prompt: prompt)
                isLoading = false
                
                // Show response in a new window
                DispatchQueue.main.async {
                    print("Got response, sending to delegate")  // Debug log
                    coordinator.showResponse(text: response)
                }
            } catch {
                isLoading = false
                print("Error occurred: \(error.localizedDescription)")  // Debug log
                DispatchQueue.main.async {
                    coordinator.showResponse(text: "Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func requestGPTResponse(prompt: String) async throws -> String {
        // For debugging purposes, return a mock response
//        print("Simulating API response for debugging")
//        return "This is a simulated response to your prompt: \"\(prompt)\". The GPT API wasn't actually called to avoid potential API connectivity issues during development."
        
//        Comment out the real implementation for now
        // Network connectivity check
        guard let reachable = try? await checkNetworkConnectivity() else {
            return "Network connectivity issue. Please check your internet connection and try again."
        }
        
        if !reachable {
            return "No internet connection. Please check your network settings and try again."
        }
        
        // Replace with your actual API endpoint and key
        let apiKey = UserDefaults.standard.string(forKey: "GPTAPIKey") ?? ""
        if apiKey.isEmpty {
            return "API Key not configured. Please set your API key in Preferences (click the menu bar icon and select Preferences)."
        }
        
        let urlString = UserDefaults.standard.string(forKey: "GPTEndpoint") ?? "https://api.openai.com/v1/chat/completions"
        
        guard let url = URL(string: urlString) else {
            return "Invalid API endpoint URL. Please check the URL in Preferences."
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30 // Increase timeout to 30 seconds
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": UserDefaults.standard.string(forKey: "GPTModel") ?? "gpt-4",
            "messages": [
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
//        */
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
                    // Exponential backoff: wait 2^retries seconds before retrying
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retries)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
}

// SwiftUI view for displaying the response
struct ResponseView: View {
    @State var responseText: String
    @State var promptText: String
    @State private var isTextCopied = false
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 30
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
    init(responseText: String, promptText: String = "") {
        self._responseText = State(initialValue: responseText)
        self._promptText = State(initialValue: promptText)
    }
    
    var body: some View {
        ZStack {
            // Background with blur and rounded corners
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.windowBackgroundColor).opacity(0.9))
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 0) {
                // Custom title bar with grab handle
                HStack {
                    // Title area
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GPT Response")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !promptText.isEmpty {
                            Text("Prompt: \"\(promptText)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 12) {
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
                        
                        Button(action: {
                            // Find window by identifier to be more precise
                            if let window = NSApplication.shared.windows.first(where: {
                                $0.identifier == NSUserInterfaceItemIdentifier("GPTResponseWindow")
                            }) {
                                // Add animation before closing
                                withAnimation(.easeIn(duration: 0.2)) {
                                    opacity = 0
                                    yOffset = -10
                                }
                                
                                // Delay actual closing to allow animation to complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Move the window when dragging the title bar
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
                
                // Response content
                ScrollView {
                    Text(responseText)
                        .padding(16)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: responseText)
                        .font(.system(size: 14))
                }
                .background(Color(.textBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .padding(12)
            }
        }
        .frame(width: 600, height: 400)
        .opacity(opacity)
        .offset(y: yOffset)
        .onAppear {
            // Animate appearance
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                opacity = 1
                yOffset = 0
            }
        }
    }
}

// Helper view for NSVisualEffectView
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

// Preferences window controller
class PreferencesWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
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

// SwiftUI view for preferences
struct PreferencesView: View {
    @AppStorage("GPTAPIKey") private var apiKey = ""
    @AppStorage("GPTEndpoint") private var endpoint = "https://api.openai.com/v1/chat/completions"
    @AppStorage("GPTModel") private var model = "gpt-4"
    @State private var isApiKeyVisible = false
    
    var body: some View {
        TabView {
            Form {
                Section(header: Text("API Settings")) {
                    TextField("API Endpoint", text: $endpoint)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        if isApiKeyVisible {
                            TextField("API Key", text: $apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Button(action: { isApiKeyVisible.toggle() }) {
                            Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    TextField("Model", text: $model)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Shortcut")) {
                    KeyboardShortcuts.Recorder(for: .togglePromptWindow)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 300)
    }
}

// SwiftUI view for About tab
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("GPT Menu Bar")
                .font(.largeTitle)
                .bold()
            
            Text("Version 1.0")
                .foregroundColor(.secondary)
            
            Text("A simple menu bar app to interact with GPT models")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
