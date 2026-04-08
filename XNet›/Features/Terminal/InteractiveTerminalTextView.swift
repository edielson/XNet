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
        scrollView.hasHorizontalScroller = false
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
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.insertionPointColor = .white
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainerInset = NSSize(width: 15, height: 15)
        textView.focusRingType = .none
        
        textView.onInput = { input in
            self.onInput(input)
        }
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTerminalTextView else { return }
        
        if textView.string != text {
            textView.textStorage?.setAttributedString(ansiAttributedString(from: text))
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func ansiAttributedString(from source: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var fg = NSColor.white.withAlphaComponent(0.9)
        var bg = NSColor.black
        var bold = false
        var current = ""
        var index = source.startIndex
        
        func flush() {
            guard !current.isEmpty else { return }
            let fontWeight: NSFont.Weight = bold ? .semibold : .regular
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: fg,
                .backgroundColor: bg,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: fontWeight)
            ]
            output.append(NSAttributedString(string: current, attributes: attrs))
            current.removeAll(keepingCapacity: true)
        }
        
        while index < source.endIndex {
            let char = source[index]
            if char == "\u{1B}" {
                let next = source.index(after: index)
                if next < source.endIndex, source[next] == "[" {
                    flush()
                    var cursor = source.index(after: next)
                    var code = ""
                    while cursor < source.endIndex {
                        let c = source[cursor]
                        if c == "m" {
                            applySGR(code, fg: &fg, bg: &bg, bold: &bold)
                            index = source.index(after: cursor)
                            break
                        }
                        if c.isLetter {
                            index = source.index(after: cursor)
                            break
                        }
                        code.append(c)
                        cursor = source.index(after: cursor)
                    }
                    if cursor >= source.endIndex {
                        index = source.endIndex
                    }
                    continue
                }
            }
            current.append(char)
            index = source.index(after: index)
        }
        
        flush()
        return output
    }
    
    private func applySGR(_ payload: String, fg: inout NSColor, bg: inout NSColor, bold: inout Bool) {
        let values = payload.split(separator: ";").compactMap { Int($0) }
        if values.isEmpty {
            fg = NSColor.white.withAlphaComponent(0.9)
            bg = NSColor.black
            bold = false
            return
        }
        
        for value in values {
            switch value {
            case 0:
                fg = NSColor.white.withAlphaComponent(0.9)
                bg = NSColor.black
                bold = false
            case 1:
                bold = true
            case 22:
                bold = false
            case 30...37:
                fg = ansiColor(for: value - 30, bright: false)
            case 90...97:
                fg = ansiColor(for: value - 90, bright: true)
            case 39:
                fg = NSColor.white.withAlphaComponent(0.9)
            case 40...47:
                bg = ansiColor(for: value - 40, bright: false)
            case 100...107:
                bg = ansiColor(for: value - 100, bright: true)
            case 49:
                bg = NSColor.black
            default:
                break
            }
        }
    }
    
    private func ansiColor(for index: Int, bright: Bool) -> NSColor {
        let base: [(CGFloat, CGFloat, CGFloat)] = bright
        ? [(0.35, 0.35, 0.35), (1.00, 0.40, 0.40), (0.45, 0.95, 0.45), (1.00, 0.88, 0.35), (0.45, 0.62, 1.00), (1.00, 0.50, 0.95), (0.45, 0.95, 0.95), (0.95, 0.95, 0.95)]
        : [(0.00, 0.00, 0.00), (0.80, 0.24, 0.24), (0.23, 0.73, 0.23), (0.80, 0.66, 0.20), (0.23, 0.46, 0.80), (0.74, 0.29, 0.71), (0.20, 0.72, 0.72), (0.78, 0.78, 0.78)]
        
        guard index >= 0, index < base.count else { return NSColor.white.withAlphaComponent(0.9) }
        let (r, g, b) = base[index]
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
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
                } else if event.modifierFlags.contains(.control) && !chars.isEmpty, let firstChar = chars.utf16.first {
                    if firstChar >= 97 && firstChar <= 122 {
                        if let scalar = UnicodeScalar(firstChar - 96) {
                            onInput?(String(scalar))
                        }
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
