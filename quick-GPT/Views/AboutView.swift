//
//  AboutView.swift
//  quick-GPT
//
//  Created by Ramin Sharifi on 2025-04-02.
//
import AppKit
import SwiftUI

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
