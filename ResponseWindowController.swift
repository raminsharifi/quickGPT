//
//  ResponseWindowController.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-02.
//
import SwiftUI
import AppKit

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
