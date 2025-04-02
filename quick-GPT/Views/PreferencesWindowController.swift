//
//  PreferencesWindowController.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-02.
//
import AppKit
import SwiftUI
import KeyboardShortcuts

class PreferencesWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Preferences"
        window.setFrameAutosaveName("Preferences Window")
        window.minSize = NSSize(width: 550, height: 350)
        
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
    @State private var customModel = ""
    @State private var useCustomModel = false
    @State private var conversations: [ConversationEntry] = []
    @State private var selectedConversation: ConversationEntry?
    @State private var showDeleteConfirmation = false
    @State private var conversationToDelete: UUID?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // API Settings
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("API Configuration")
                        .font(.headline)
                    
                    // API Endpoint
                    HStack(alignment: .top) {
                        Text("API Endpoint")
                            .frame(width: 120, alignment: .trailing)
                            .padding(.top, 2)
                        
                        TextField("https://api.openai.com/v1/chat/completions", text: $endpoint)
                            .frame(maxWidth: .infinity)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // API Key
                    HStack(alignment: .top) {
                        Text("API Key")
                            .frame(width: 120, alignment: .trailing)
                            .padding(.top, 2)
                        
                        HStack {
                            if isApiKeyVisible {
                                TextField("Enter your API key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                SecureField("Enter your API key", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button(action: { isApiKeyVisible.toggle() }) {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                
                // Model Selection
                HStack(alignment: .top) {
                    Text("Model")
                        .frame(width: 120, alignment: .trailing)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: $useCustomModel) {
                            Text("Preset model").tag(false)
                            Text("Custom model").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.bottom, 4)
                        
                        if useCustomModel {
                            TextField("Enter custom model identifier", text: $model)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onAppear {
                                    if !modelOptions.contains(model) {
                                        customModel = model
                                    }
                                }
                        } else {
                            Picker("", selection: $model) {
                                ForEach(modelOptions, id: \.self) { modelOption in
                                    Text(modelOption).tag(modelOption)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .labelsHidden()
                        }
                    }
                }
                
                // System Prompt
                HStack(alignment: .top) {
                    Text("System Prompt")
                        .frame(width: 120, alignment: .trailing)
                        .padding(.top, 2)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 13))
                            .frame(height: 80)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .background(Color(NSColor.textBackgroundColor))
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                // Keyboard Shortcut
                Text("Keyboard Shortcut")
                    .font(.headline)
                
                HStack {
                    Text("Toggle App")
                        .frame(width: 120, alignment: .trailing)
                    
                    KeyboardShortcuts.Recorder(for: .togglePromptWindow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
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
            VStack(spacing: 0) {
                HStack {
                    Text("Conversation History")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Clear All", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(conversations.isEmpty)
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Clear All History"),
                            message: Text("Are you sure you want to delete all conversation history? This cannot be undone."),
                            primaryButton: .destructive(Text("Delete All")) {
                                ConversationHistoryManager.shared.clearHistory()
                                conversations = []
                                selectedConversation = nil
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Main content
                if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No conversation history")
                            .font(.headline)
                        
                        Text("Your conversations with GPT will appear here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HSplitView {
                        // Conversations list - Fixed implementation
                        List {
                            ForEach(conversations) { conversation in
                                ConversationListItem(conversation: conversation)
                                    .contentShape(Rectangle()) // Make entire row clickable
                                    .onTapGesture {
                                        selectedConversation = conversation
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedConversation?.id == conversation.id ? 
                                                  Color.blue.opacity(0.1) : Color.clear)
                                    )
                                    .contextMenu {
                                        Button(action: {
                                            conversationToDelete = conversation.id
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(SidebarListStyle())
                        .frame(minWidth: 250)
                        
                        // Conversation detail
                        if let selected = selectedConversation {
                            ConversationDetailView(conversation: selected)
                        } else {
                            VStack {
                                Spacer()
                                Text("Select a conversation to view details")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .alert(isPresented: Binding<Bool>(
                        get: { conversationToDelete != nil },
                        set: { if !$0 { conversationToDelete = nil } }
                    )) {
                        Alert(
                            title: Text("Delete Conversation"),
                            message: Text("Are you sure you want to delete this conversation?"),
                            primaryButton: .destructive(Text("Delete")) {
                                if let id = conversationToDelete {
                                    ConversationHistoryManager.shared.deleteConversation(id: id)
                                    conversations = ConversationHistoryManager.shared.conversations
                                    if selectedConversation?.id == id {
                                        selectedConversation = nil
                                    }
                                }
                                conversationToDelete = nil
                            },
                            secondaryButton: .cancel {
                                conversationToDelete = nil
                            }
                        )
                    }
                }
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(2)
            .onAppear {
                conversations = ConversationHistoryManager.shared.conversations
            }
            
            // About tab
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .onAppear {
            // Check if current model is a custom one
            useCustomModel = !modelOptions.contains(model)
            if useCustomModel {
                customModel = model
            }
            
            // Load conversations
            conversations = ConversationHistoryManager.shared.conversations
        }
    }
}

// Component for displaying a conversation in the list
struct ConversationListItem: View {
    let conversation: ConversationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .lineLimit(1)
                .font(.system(size: 13, weight: .medium))
            
            HStack {
                Text(formattedDate(conversation.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(conversation.model)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Component for displaying conversation details
struct ConversationDetailView: View {
    let conversation: ConversationEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate(conversation.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("Model: \(conversation.model)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Get all message content for copying
                        let conversationText = conversation.messages
                            .filter { $0.role != "system" } // Exclude system message
                            .map { "\($0.role == "user" ? "User: " : "Assistant: ")\($0.content)" }
                            .joined(separator: "\n\n")
                        
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(conversationText, forType: .string)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.bottom, 8)
                
                // Display message history instead of single prompt/response
                ForEach(Array(conversation.messages.enumerated()), id: \.offset) { index, message in
                    if message.role != "system" { // Don't show system messages
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.role == "user" ? "User" : "Assistant")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text(message.content)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? 
                                    Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
