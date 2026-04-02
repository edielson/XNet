//
//  InteractiveTerminalTextView.swift
//  XNet›
//

import SwiftUI
import AppKit

struct InteractiveTerminalTextView: NSViewRepresentable {
    @Binding var text: String
    var onInput: (String) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .black
        
        let textView = CustomTerminalTextView()
        textView.autoresizingMask = [.width, .height]
        textView.backgroundColor = .black
        textView.drawsBackground = true
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 15, height: 15) // Padding elegante
        textView.focusRingType = .none // Remove borda azul ao clicar
        
        textView.onInput = { input in
            self.onInput(input)
        }
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTerminalTextView else { return }
        
        // Only update if the text actually changed to prevent resetting cursor
        if textView.string != text {
            textView.string = text
            textView.scrollToEndOfDocument(nil)
        }
    }
}

class CustomTerminalTextView: NSTextView {
    var onInput: ((String) -> Void)?
    
    override func keyDown(with event: NSEvent) {
        // Intercept keys and send them to the delegate instead of putting them into the view natively.
        // We rely on the server (like SSH or Telnet) to echo characters back to us.
        
        if let chars = event.characters {
            let keyCode = event.keyCode
            
            // Handle some specific control keys directly
            switch keyCode {
            case 36: // Return
                onInput?("\n")
            case 48: // Tab
                onInput?("\t")
            case 51: // Delete/Backspace
                // We send the backspace character \u{0008} or \x7F (DEL). Network gear usually likes DEL
                onInput?("\u{7F}")
            case 123: // Left Arrow
                onInput?("\u{1B}[D")
            case 124: // Right Arrow
                onInput?("\u{1B}[C")
            case 125: // Down Arrow
                onInput?("\u{1B}[B")
            case 126: // Up Arrow
                onInput?("\u{1B}[A")
            default:
                // If it's a standard character like '?', letters, numbers, etc.
                if !chars.isEmpty && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) {
                    onInput?(chars)
                } else if event.modifierFlags.contains(.control) && !chars.isEmpty {
                    // Provide basic support for Control-C etc (not robust but usually works by converting character to 1-26 ASCII)
                    let firstChar = chars.utf16.first!
                    if firstChar >= 97 && firstChar <= 122 {
                        let ctrlChar = String(describing: UnicodeScalar(firstChar - 96)!)
                        onInput?(ctrlChar)
                    }
                }
            }
        }
        
        // Prevent default macOS behavior (we do not call super)
        // This ensures characters only appear if the remote server echoes them back.
    }
    
    // We want to force the cursor to visually look like it's at the end
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: flag)
    }
}
