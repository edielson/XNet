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
        
        var i = 0
        while i < values.count {
            let value = values[i]
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
            case 38:
                if i + 1 < values.count {
                    let mode = values[i + 1]
                    if mode == 5, i + 2 < values.count {
                        fg = ansi256Color(values[i + 2])
                        i += 2
                    } else if mode == 2, i + 4 < values.count {
                        let r = values[i + 2]
                        let g = values[i + 3]
                        let b = values[i + 4]
                        fg = rgbColor(r: r, g: g, b: b)
                        i += 4
                    }
                }
            case 48:
                if i + 1 < values.count {
                    let mode = values[i + 1]
                    if mode == 5, i + 2 < values.count {
                        bg = ansi256Color(values[i + 2])
                        i += 2
                    } else if mode == 2, i + 4 < values.count {
                        let r = values[i + 2]
                        let g = values[i + 3]
                        let b = values[i + 4]
                        bg = rgbColor(r: r, g: g, b: b)
                        i += 4
                    }
                }
            default:
                break
            }
            i += 1
        }
    }
    
    private func ansiColor(for index: Int, bright: Bool) -> NSColor {
        let base: [(CGFloat, CGFloat, CGFloat)] = bright
        ? [(0.33, 0.36, 0.39), (0.95, 0.37, 0.36), (0.58, 0.80, 0.39), (0.95, 0.76, 0.32), (0.38, 0.68, 0.94), (0.73, 0.54, 0.91), (0.34, 0.84, 0.83), (0.96, 0.96, 0.96)]
        : [(0.10, 0.12, 0.16), (0.80, 0.25, 0.28), (0.43, 0.69, 0.29), (0.76, 0.60, 0.24), (0.36, 0.54, 0.85), (0.61, 0.43, 0.79), (0.29, 0.67, 0.67), (0.77, 0.79, 0.82)]
        
        guard index >= 0, index < base.count else { return NSColor.white.withAlphaComponent(0.9) }
        let (r, g, b) = base[index]
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }
    
    private func ansi256Color(_ value: Int) -> NSColor {
        let code = max(0, min(255, value))
        if code < 8 {
            return ansiColor(for: code, bright: false)
        }
        if code < 16 {
            return ansiColor(for: code - 8, bright: true)
        }
        if code >= 232 {
            let level = CGFloat(code - 232) / 23.0
            let v = 0.08 + (0.84 * level)
            return NSColor(calibratedRed: v, green: v, blue: v, alpha: 1.0)
        }
        
        let idx = code - 16
        let r = idx / 36
        let g = (idx % 36) / 6
        let b = idx % 6
        
        func map(_ n: Int) -> CGFloat {
            if n == 0 { return 0.0 }
            return CGFloat(55 + n * 40) / 255.0
        }
        
        return NSColor(calibratedRed: map(r), green: map(g), blue: map(b), alpha: 1.0)
    }
    
    private func rgbColor(r: Int, g: Int, b: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(max(0, min(255, r))) / 255.0,
            green: CGFloat(max(0, min(255, g))) / 255.0,
            blue: CGFloat(max(0, min(255, b))) / 255.0,
            alpha: 1.0
        )
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
