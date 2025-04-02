//
//  PromptView.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-02.
//
import AppKit
import SwiftUI

struct PromptView: View {
    enum Mode: Equatable {
        case gpt, search
        
        var icon: String {
            switch self {
            case .gpt: return "brain.head.profile"
            case .search: return "magnifyingglass"
            }
        }
        
        var color: Color {
            switch self {
            case .gpt: return AppTheme.primaryColor
            case .search: return Color.orange
            }
        }
        
        var placeholderText: String {
            switch self {
            case .gpt: return "Ask GPT something..."
            case .search: return "Search DuckDuckGo..."
            }
        }
        
        var submitIcon: String {
            switch self {
            case .gpt: return "paperplane.fill"
            case .search: return "arrow.right.circle.fill"
            }
        }
    }
    
    @State private var promptText = ""
    @State private var isLoading = false
    @State private var recentPrompts: [String] = UserDefaults.standard.stringArray(forKey: "RecentPrompts") ?? []
    @State private var showingRecentPrompts = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 20
    @State private var mode: Mode = .gpt
    @State private var previousMode: Mode = .gpt
    @State private var tabIndicatorOffset: CGFloat = 0
    @State private var iconRotation: Double = 0
    @State private var iconScale: CGFloat = 1.0
    @EnvironmentObject private var coordinator: PromptCoordinator
    
    // Constants for layout and animations
    private let tabWidth: CGFloat = 80
    private let tabPadding: CGFloat = 16
    private let tabAnimationDuration: Double = 0.3
    private let tabIndicatorHeight: CGFloat = 2
    private let iconAnimationDuration: Double = 0.25
    
    func forceFocus() {
        self.isTextFieldFocused = true
    }
    
    var body: some View {
        ZStack {
            // Background with glass effect
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
                
                // Mode selector tabs with animated indicator
                VStack(spacing: 0) {
                    // Tab buttons first
                    HStack(spacing: 0) {
                        ForEach([Mode.gpt, Mode.search], id: \.self) { tabMode in
                            ModeTabButton(title: tabMode == .gpt ? "GPT" : "Search", 
                                         systemImage: tabMode.icon,
                                         isSelected: mode == tabMode) {
                                withAnimation(.spring(response: tabAnimationDuration, dampingFraction: 0.7)) {
                                    previousMode = mode
                                    mode = tabMode
                                    // No offset manipulation here
                                    
                                    // Animate icon transition
                                    iconRotation += 180
                                    iconScale = 0.5
                                    
                                    // Reset icon scale after rotation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + iconAnimationDuration) {
                                        withAnimation(.spring(response: iconAnimationDuration, dampingFraction: 0.7)) {
                                            iconScale = 1.0
                                        }
                                    }
                                }
                            }
                            .frame(width: tabWidth)
                            .overlay(
                                // Place indicator directly under each tab
                                Rectangle()
                                    .fill(mode == tabMode ? mode.color : Color.clear)
                                    .frame(width: tabWidth * 0.7, height: tabIndicatorHeight)
                                    .offset(y: 14) // Position below the text
                                    .animation(.spring(response: tabAnimationDuration, dampingFraction: 0.7), value: mode)
                                , alignment: .bottom
                            )
                        }
                    }
                    .padding(.horizontal, tabPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
                
                // Input field area
                HStack {
                    // Animated icon with mode-specific styling
                    ZStack {
                        if previousMode != mode {
                            Image(systemName: previousMode.icon)
                                .foregroundColor(previousMode.color)
                                .font(.system(size: AppTheme.iconSize, weight: .medium))
                                .opacity(0.3)
                                .scaleEffect(1.5)
                                .rotationEffect(.degrees(-iconRotation))
                        }
                        
                        Image(systemName: mode.icon)
                            .foregroundColor(mode.color)
                            .font(.system(size: AppTheme.iconSize, weight: .medium))
                            .rotationEffect(.degrees(iconRotation))
                            .scaleEffect(iconScale)
                            .animation(.spring(response: iconAnimationDuration, dampingFraction: 0.6), value: iconRotation)
                    }
                    .padding(.leading, 16)
                    .shimmering(active: isLoading)
                    
                    // Main input field
                    ZStack(alignment: .leading) {
                        if promptText.isEmpty && !isTextFieldFocused {
                            Text(mode.placeholderText)
                                .foregroundColor(.gray)
                                .font(AppTheme.fontRegular)
                                .padding(.vertical, 12)
                                .transition(.opacity)
                        }
                        
                        TextField("", text: $promptText, onCommit: handleSubmit)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 12)
                            .focused($isTextFieldFocused)
                            .font(AppTheme.fontRegular)
                            .foregroundColor(mode == .gpt ? .primary : mode.color.opacity(0.8))
                            .onExitCommand {
                                if let window = NSApplication.shared.keyWindow {
                                    window.close()
                                }
                            }
                            .onKeyPress(.tab) {
                                withAnimation(.spring(response: tabAnimationDuration, dampingFraction: 0.7)) {
                                    previousMode = mode
                                    mode = mode == .gpt ? .search : .gpt
                                    tabIndicatorOffset = mode == .gpt ? 0 : tabWidth
                                    
                                    // Animate icon transition
                                    iconRotation += 180
                                    iconScale = 0.5
                                    
                                    // Reset icon scale after rotation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + iconAnimationDuration) {
                                        withAnimation(.spring(response: iconAnimationDuration, dampingFraction: 0.7)) {
                                            iconScale = 1.0
                                        }
                                    }
                                }
                                return .handled
                            }
                    }
                    
                    if !promptText.isEmpty {
                        // Recently used prompts button (only for GPT mode)
                        if mode == .gpt {
                            Button(action: {
                                showingRecentPrompts.toggle()
                            }) {
                                Image(systemName: "clock")
                                    .foregroundColor(.gray)
                                    .font(.system(size: AppTheme.iconSize - 2))
                            }
                            .buttonStyle(PlainButtonStyle())
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
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    if isLoading {
                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                            .padding(.trailing, 16)
                    } else if !promptText.isEmpty {
                        // Submit button with animated hover effect
                        AnimatedSubmitButton(
                            systemName: mode.submitIcon,
                            color: mode.color,
                            action: handleSubmit
                        )
                        .padding(.trailing, 16)
                        .keyboardShortcut(.return, modifiers: .command)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 14)
                .padding(.top, 2)
            }
        }
        .frame(width: 700, height: 100)
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
    
    private func handleSubmit() {
        switch mode {
        case .gpt:
            sendPrompt()
        case .search:
            performDuckDuckGoSearch()
        }
    }
    
    private func performDuckDuckGoSearch() {
        guard !promptText.isEmpty else { return }
        
        let query = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        promptText = ""
        
        // Close the prompt window
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView is NSHostingView<PromptView> }) {
                window.close()
            }
        }
        
        // Encode the query for URL
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://duckduckgo.com/?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
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

// Tab button for mode selection with enhanced visuals
struct ModeTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isSelected ? 
                                Color.gray.opacity(0.2) : 
                                (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                        )
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .primary : .gray)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Animated submit button with hover and pulse effects
struct AnimatedSubmitButton: View {
    let systemName: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Scale animation on click
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.8
            }
            
            // Delayed reset and action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                action()
            }
        }) {
            Image(systemName: systemName)
                .font(.system(size: AppTheme.iconSize, weight: .medium))
                .foregroundColor(color)
                .padding(8)
                .background(
                    Circle()
                        .fill(color.opacity(isHovered ? 0.15 : 0.0))
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                )
                .scaleEffect(scale)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
