import SwiftUI
import Shimmer

// MARK: - Shimmer Extensions
extension View {
    /// Add a shimmering effect to any view, typically for a loading state.
    ///
    /// - Parameters:
    ///   - active: Binding determining whether the shimmer is active
    ///   - duration: The duration of a shimmer cycle
    ///   - bounce: Whether to bounce (reverse) the animation back and forth
    ///   - delay: An optional delay before starting the animation
    @ViewBuilder func shimmering(
        active: Bool = true,
        duration: Double = 1.5,
        bounce: Bool = false,
        delay: Double = 0
    ) -> some View {
        if active {
            self.modifier(ShimmerModifier(duration: duration, bounce: bounce, delay: delay))
        } else {
            self
        }
    }
}

// MARK: - Code Highlight Shimmer
struct ShimmerModifier: ViewModifier {
    let duration: Double
    let bounce: Bool
    let delay: Double
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    ZStack {
                        Color.white.opacity(0.1)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geo.size.width * 0.6, height: geo.size.height)
                            .blur(radius: 7)
                            .rotationEffect(.degrees(20))
                            .offset(x: isAnimating ? geo.size.width * 1.2 : -geo.size.width * 1.2)
                    }
                }
                .mask(content)
                .blendMode(.overlay)
            )
            .onAppear {
                withAnimation(
                    Animation
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: bounce)
                        .delay(delay)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Code Highlighting Extension
extension String {
    /// Extracts code blocks with language specifications from a string
    func extractCodeBlocks() -> [(language: String, code: String)] {
        let pattern = "```([a-zA-Z0-9+#]*)\\s*\\n([\\s\\S]*?)```"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let nsString = self as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: self, options: [], range: fullRange)
        
        return matches.compactMap { match in
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            guard codeRange.location != NSNotFound else { return nil }
            
            let language = languageRange.location != NSNotFound ? nsString.substring(with: languageRange) : ""
            let code = nsString.substring(with: codeRange)
            
            return (language: language.isEmpty ? "text" : language, code: code)
        }
    }
}
