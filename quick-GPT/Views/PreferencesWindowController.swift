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
    @State private var customModel = ""
    @State private var useCustomModel = false
    
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
        .onAppear {
            // Check if current model is a custom one
            useCustomModel = !modelOptions.contains(model)
            if useCustomModel {
                customModel = model
            }
        }
    }
}
