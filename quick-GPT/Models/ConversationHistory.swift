//
//  ConversationHistory.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-04.
//

import Foundation

// Updated model for conversation entries with message history
struct ConversationEntry: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var messages: [Message]
    var timestamp: Date
    var model: String
    var title: String
    
    struct Message: Codable, Equatable, Hashable {
        var role: String // "system", "user", or "assistant"
        var content: String
        var timestamp: Date
        
        init(role: String, content: String) {
            self.role = role
            self.content = content
            self.timestamp = Date()
        }
    }
    
    init(systemPrompt: String, userPrompt: String, response: String, model: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.model = model
        self.title = userPrompt.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Initialize with messages
        self.messages = [
            Message(role: "system", content: systemPrompt),
            Message(role: "user", content: userPrompt),
            Message(role: "assistant", content: response)
        ]
    }
    
    // Add a message to the conversation
    mutating func addMessage(role: String, content: String) {
        messages.append(Message(role: role, content: content))
        timestamp = Date() // Update timestamp to most recent interaction
    }
    
    // Get the latest user prompt
    var lastUserPrompt: String? {
        messages.last(where: { $0.role == "user" })?.content
    }
    
    // Get the latest assistant response
    var lastAssistantResponse: String? {
        messages.last(where: { $0.role == "assistant" })?.content
    }
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable implementation
    static func == (lhs: ConversationEntry, rhs: ConversationEntry) -> Bool {
        return lhs.id == rhs.id
    }
}

// Updated class to manage conversation history
class ConversationHistoryManager {
    static let shared = ConversationHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "ConversationHistory"
    
    // Current conversation in progress
    private var _currentConversation: ConversationEntry?
    
    var currentConversation: ConversationEntry? {
        get { return _currentConversation }
        set { _currentConversation = newValue }
    }
    
    var conversations: [ConversationEntry] {
        get {
            if let data = userDefaults.data(forKey: historyKey) {
                do {
                    return try JSONDecoder().decode([ConversationEntry].self, from: data)
                } catch {
                    print("Error decoding conversation history: \(error)")
                    return []
                }
            }
            return []
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                userDefaults.set(data, forKey: historyKey)
            } catch {
                print("Error encoding conversation history: \(error)")
            }
        }
    }
    
    // Start a new conversation
    func startNewConversation(systemPrompt: String, userPrompt: String, response: String) {
        let model = userDefaults.string(forKey: "GPTModel") ?? "gpt-4"
        let entry = ConversationEntry(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            response: response,
            model: model
        )
        
        // Set as current conversation
        _currentConversation = entry
        
        // Add to history
        var current = conversations
        current.insert(entry, at: 0)
        conversations = current
    }
    
    // Continue existing conversation
    func continueConversation(conversationId: UUID, userPrompt: String, response: String) {
        var current = conversations
        
        if let index = current.firstIndex(where: { $0.id == conversationId }) {
            // Add new messages to existing conversation
            current[index].addMessage(role: "user", content: userPrompt)
            current[index].addMessage(role: "assistant", content: response)
            
            // Update current conversation reference
            _currentConversation = current[index]
            
            // Move this conversation to the top (most recent)
            let conversation = current.remove(at: index)
            current.insert(conversation, at: 0)
            
            conversations = current
        }
    }
    
    // Add to the current conversation or start a new one
    func addInteraction(systemPrompt: String, userPrompt: String, response: String) {
        if let current = _currentConversation {
            continueConversation(conversationId: current.id, userPrompt: userPrompt, response: response)
        } else {
            startNewConversation(systemPrompt: systemPrompt, userPrompt: userPrompt, response: response)
        }
    }
    
    func clearHistory() {
        conversations = []
        _currentConversation = nil
    }
    
    func deleteConversation(id: UUID) {
        var current = conversations
        current.removeAll { $0.id == id }
        conversations = current
        
        // Clear current conversation if it was deleted
        if _currentConversation?.id == id {
            _currentConversation = nil
        }
    }
    
    // Get a specific conversation by ID
    func getConversation(id: UUID) -> ConversationEntry? {
        return conversations.first(where: { $0.id == id })
    }
} 