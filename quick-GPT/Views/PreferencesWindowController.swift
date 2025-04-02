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
