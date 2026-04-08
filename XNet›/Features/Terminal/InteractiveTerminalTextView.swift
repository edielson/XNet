//
//  InteractiveTerminalTextView.swift
//  XNet›
//

import SwiftUI
import AppKit

struct TerminalThemeColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    init(hex: Int, alpha: Double = 1.0) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
        self.alpha = alpha
    }
    
    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
    
    var color: Color {
        Color(nsColor: nsColor)
    }
    
    func withAlpha(_ value: Double) -> TerminalThemeColor {
        TerminalThemeColor(red: red, green: green, blue: blue, alpha: value)
    }
}

struct TerminalThemeSpec {
    let background: TerminalThemeColor
    let foreground: TerminalThemeColor
    let accent: TerminalThemeColor
    let cursor: TerminalThemeColor
    let chromeTop: TerminalThemeColor
    let chromeBottom: TerminalThemeColor
    let sidebarTop: TerminalThemeColor
    let sidebarBottom: TerminalThemeColor
    let card: TerminalThemeColor
    let cardBorder: TerminalThemeColor
    let normalANSI: [TerminalThemeColor]
    let brightANSI: [TerminalThemeColor]
}

enum TerminalTheme: String, CaseIterable, Identifiable {
    case termiusDark = "termius-dark"
    case termiusLight = "termius-light"
    case flexokiDark = "flexoki-dark"
    case flexokiLight = "flexoki-light"
    case kanagawaWave = "kanagawa-wave"
    case kanagawaDragon = "kanagawa-dragon"
    case hackerBlue = "hacker-blue"
    case hackerGreen = "hacker-green"
    case hackerRed = "hacker-red"
    case everforestDark = "everforest-dark"
    case nightOwl = "night-owl"
    case rosePineMoon = "rose-pine-moon"
    
    var id: String { rawValue }
    
    static var defaultTheme: TerminalTheme { .termiusDark }
    
    var displayName: String {
        switch self {
        case .termiusDark: "Termius Dark"
        case .termiusLight: "Termius Light"
        case .flexokiDark: "Flexoki Dark"
        case .flexokiLight: "Flexoki Light"
        case .kanagawaWave: "Kanagawa Wave"
        case .kanagawaDragon: "Kanagawa Dragon"
        case .hackerBlue: "Hacker Blue"
        case .hackerGreen: "Hacker Green"
        case .hackerRed: "Hacker Red"
        case .everforestDark: "Everforest Dark"
        case .nightOwl: "Night Owl"
        case .rosePineMoon: "Rosé Pine Moon"
        }
    }
    
    var appearanceLabel: String {
        isLight ? "Claro" : "Escuro"
    }
    
    var isLight: Bool {
        switch self {
        case .termiusLight, .flexokiLight:
            true
        default:
            false
        }
    }
    
    var backgroundColor: Color { spec.background.color }
    var foregroundColor: Color { spec.foreground.color }
    var accentColor: Color { spec.accent.color }
    var cursorColor: Color { spec.cursor.color }
    var chromeTopColor: Color { spec.chromeTop.color }
    var chromeBottomColor: Color { spec.chromeBottom.color }
    var sidebarTopColor: Color { spec.sidebarTop.color }
    var sidebarBottomColor: Color { spec.sidebarBottom.color }
    var cardBackgroundColor: Color { spec.card.color }
    var panelBorderColor: Color { spec.cardBorder.color }
    var mutedColor: Color { foregroundColor.opacity(isLight ? 0.62 : 0.58) }
    var previewSwatches: [Color] {
        [
            spec.accent.color,
            spec.normalANSI[1].color,
            spec.normalANSI[2].color,
            spec.brightANSI[4].color
        ]
    }
    
    var defaultForegroundNSColor: NSColor { spec.foreground.nsColor }
    var defaultBackgroundNSColor: NSColor { spec.background.nsColor }
    var cursorNSColor: NSColor { spec.cursor.nsColor }
    var selectionNSColor: NSColor { spec.accent.withAlpha(isLight ? 0.24 : 0.32).nsColor }
    
    func ansiColor(index: Int, bright: Bool) -> NSColor {
        let palette = bright ? spec.brightANSI : spec.normalANSI
        guard index >= 0, index < palette.count else {
            return defaultForegroundNSColor
        }
        return palette[index].nsColor
    }
    
    private var spec: TerminalThemeSpec {
        switch self {
        case .termiusDark:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x121826),
                foreground: TerminalThemeColor(hex: 0xE5E9F0),
                accent: TerminalThemeColor(hex: 0x27D796),
                cursor: TerminalThemeColor(hex: 0x6EF7C8),
                chromeTop: TerminalThemeColor(hex: 0x1A2235),
                chromeBottom: TerminalThemeColor(hex: 0x111725),
                sidebarTop: TerminalThemeColor(hex: 0x182134),
                sidebarBottom: TerminalThemeColor(hex: 0x121826),
                card: TerminalThemeColor(hex: 0x1C2740),
                cardBorder: TerminalThemeColor(hex: 0x2C3A59),
                normalANSI: [
                    TerminalThemeColor(hex: 0x1B2438),
                    TerminalThemeColor(hex: 0xE05F65),
                    TerminalThemeColor(hex: 0x48C774),
                    TerminalThemeColor(hex: 0xE5C07B),
                    TerminalThemeColor(hex: 0x61AFEF),
                    TerminalThemeColor(hex: 0xC678DD),
                    TerminalThemeColor(hex: 0x56B6C2),
                    TerminalThemeColor(hex: 0xC8D1E3)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x5A6680),
                    TerminalThemeColor(hex: 0xFF7A82),
                    TerminalThemeColor(hex: 0x7FFFB2),
                    TerminalThemeColor(hex: 0xFFD479),
                    TerminalThemeColor(hex: 0x7FC8FF),
                    TerminalThemeColor(hex: 0xE1A6FF),
                    TerminalThemeColor(hex: 0x7EE7E7),
                    TerminalThemeColor(hex: 0xF5F7FB)
                ]
            )
        case .termiusLight:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0xF5F7FB),
                foreground: TerminalThemeColor(hex: 0x223046),
                accent: TerminalThemeColor(hex: 0x4F6EF7),
                cursor: TerminalThemeColor(hex: 0x3451E6),
                chromeTop: TerminalThemeColor(hex: 0xFFFFFF),
                chromeBottom: TerminalThemeColor(hex: 0xE9EEF7),
                sidebarTop: TerminalThemeColor(hex: 0xF8FAFE),
                sidebarBottom: TerminalThemeColor(hex: 0xEBF0F9),
                card: TerminalThemeColor(hex: 0xFFFFFF),
                cardBorder: TerminalThemeColor(hex: 0xCFD8E8),
                normalANSI: [
                    TerminalThemeColor(hex: 0x5A6475),
                    TerminalThemeColor(hex: 0xD64550),
                    TerminalThemeColor(hex: 0x258A55),
                    TerminalThemeColor(hex: 0xB37A0B),
                    TerminalThemeColor(hex: 0x3556C5),
                    TerminalThemeColor(hex: 0x8B4FC9),
                    TerminalThemeColor(hex: 0x147A86),
                    TerminalThemeColor(hex: 0xDCE3EF)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x7A879B),
                    TerminalThemeColor(hex: 0xF05C67),
                    TerminalThemeColor(hex: 0x31B56E),
                    TerminalThemeColor(hex: 0xD9A634),
                    TerminalThemeColor(hex: 0x5E7CFF),
                    TerminalThemeColor(hex: 0xAF7AF3),
                    TerminalThemeColor(hex: 0x2AA9B7),
                    TerminalThemeColor(hex: 0x1B2435)
                ]
            )
        case .flexokiDark:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x100F0F),
                foreground: TerminalThemeColor(hex: 0xCECDC3),
                accent: TerminalThemeColor(hex: 0xD14D41),
                cursor: TerminalThemeColor(hex: 0xCECDC3),
                chromeTop: TerminalThemeColor(hex: 0x1A1818),
                chromeBottom: TerminalThemeColor(hex: 0x121111),
                sidebarTop: TerminalThemeColor(hex: 0x181616),
                sidebarBottom: TerminalThemeColor(hex: 0x100F0F),
                card: TerminalThemeColor(hex: 0x1C1B1A),
                cardBorder: TerminalThemeColor(hex: 0x343331),
                normalANSI: [
                    TerminalThemeColor(hex: 0x403E3C),
                    TerminalThemeColor(hex: 0xAF3029),
                    TerminalThemeColor(hex: 0x66800B),
                    TerminalThemeColor(hex: 0xAD8301),
                    TerminalThemeColor(hex: 0x205EA6),
                    TerminalThemeColor(hex: 0xA02F6F),
                    TerminalThemeColor(hex: 0x24837B),
                    TerminalThemeColor(hex: 0x878580)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x575653),
                    TerminalThemeColor(hex: 0xD14D41),
                    TerminalThemeColor(hex: 0x879A39),
                    TerminalThemeColor(hex: 0xD0A215),
                    TerminalThemeColor(hex: 0x4385BE),
                    TerminalThemeColor(hex: 0xCE5D97),
                    TerminalThemeColor(hex: 0x3AA99F),
                    TerminalThemeColor(hex: 0xFFFCF0)
                ]
            )
        case .flexokiLight:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0xFFFCF0),
                foreground: TerminalThemeColor(hex: 0x100F0F),
                accent: TerminalThemeColor(hex: 0xD14D41),
                cursor: TerminalThemeColor(hex: 0x100F0F),
                chromeTop: TerminalThemeColor(hex: 0xFFFDF7),
                chromeBottom: TerminalThemeColor(hex: 0xF2EDE1),
                sidebarTop: TerminalThemeColor(hex: 0xFFF9EB),
                sidebarBottom: TerminalThemeColor(hex: 0xF4EFE2),
                card: TerminalThemeColor(hex: 0xFFFDF7),
                cardBorder: TerminalThemeColor(hex: 0xD8D1C0),
                normalANSI: [
                    TerminalThemeColor(hex: 0x6F6E69),
                    TerminalThemeColor(hex: 0xAF3029),
                    TerminalThemeColor(hex: 0x66800B),
                    TerminalThemeColor(hex: 0xAD8301),
                    TerminalThemeColor(hex: 0x205EA6),
                    TerminalThemeColor(hex: 0xA02F6F),
                    TerminalThemeColor(hex: 0x24837B),
                    TerminalThemeColor(hex: 0xE6E0D1)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x878580),
                    TerminalThemeColor(hex: 0xD14D41),
                    TerminalThemeColor(hex: 0x879A39),
                    TerminalThemeColor(hex: 0xD0A215),
                    TerminalThemeColor(hex: 0x4385BE),
                    TerminalThemeColor(hex: 0xCE5D97),
                    TerminalThemeColor(hex: 0x3AA99F),
                    TerminalThemeColor(hex: 0x1C1B1A)
                ]
            )
        case .kanagawaWave:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x1F1F28),
                foreground: TerminalThemeColor(hex: 0xDCD7BA),
                accent: TerminalThemeColor(hex: 0x7E9CD8),
                cursor: TerminalThemeColor(hex: 0xC8C093),
                chromeTop: TerminalThemeColor(hex: 0x252532),
                chromeBottom: TerminalThemeColor(hex: 0x1B1B24),
                sidebarTop: TerminalThemeColor(hex: 0x242531),
                sidebarBottom: TerminalThemeColor(hex: 0x1F1F28),
                card: TerminalThemeColor(hex: 0x2A2A37),
                cardBorder: TerminalThemeColor(hex: 0x3A3A4C),
                normalANSI: [
                    TerminalThemeColor(hex: 0x090618),
                    TerminalThemeColor(hex: 0xC34043),
                    TerminalThemeColor(hex: 0x76946A),
                    TerminalThemeColor(hex: 0xC0A36E),
                    TerminalThemeColor(hex: 0x7E9CD8),
                    TerminalThemeColor(hex: 0x957FB8),
                    TerminalThemeColor(hex: 0x6A9589),
                    TerminalThemeColor(hex: 0xC8C093)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x727169),
                    TerminalThemeColor(hex: 0xE82424),
                    TerminalThemeColor(hex: 0x98BB6C),
                    TerminalThemeColor(hex: 0xE6C384),
                    TerminalThemeColor(hex: 0x7FB4CA),
                    TerminalThemeColor(hex: 0x938AA9),
                    TerminalThemeColor(hex: 0x7AA89F),
                    TerminalThemeColor(hex: 0xDCD7BA)
                ]
            )
        case .kanagawaDragon:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x181616),
                foreground: TerminalThemeColor(hex: 0xC5C9C5),
                accent: TerminalThemeColor(hex: 0x8BA4B0),
                cursor: TerminalThemeColor(hex: 0xC5C9C5),
                chromeTop: TerminalThemeColor(hex: 0x211F1F),
                chromeBottom: TerminalThemeColor(hex: 0x181616),
                sidebarTop: TerminalThemeColor(hex: 0x201E1E),
                sidebarBottom: TerminalThemeColor(hex: 0x181616),
                card: TerminalThemeColor(hex: 0x262323),
                cardBorder: TerminalThemeColor(hex: 0x3E3B3B),
                normalANSI: [
                    TerminalThemeColor(hex: 0x0D0C0C),
                    TerminalThemeColor(hex: 0xC4746E),
                    TerminalThemeColor(hex: 0x8A9A7B),
                    TerminalThemeColor(hex: 0xC4B28A),
                    TerminalThemeColor(hex: 0x8BA4B0),
                    TerminalThemeColor(hex: 0xA292A3),
                    TerminalThemeColor(hex: 0x8EA4A2),
                    TerminalThemeColor(hex: 0xC5C9C5)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x7A8382),
                    TerminalThemeColor(hex: 0xE46876),
                    TerminalThemeColor(hex: 0x87A987),
                    TerminalThemeColor(hex: 0xE6C384),
                    TerminalThemeColor(hex: 0x7FB4CA),
                    TerminalThemeColor(hex: 0x938AA9),
                    TerminalThemeColor(hex: 0x7AA89F),
                    TerminalThemeColor(hex: 0xE6E9E6)
                ]
            )
        case .hackerBlue:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x03121F),
                foreground: TerminalThemeColor(hex: 0x7CDFFF),
                accent: TerminalThemeColor(hex: 0x00B8FF),
                cursor: TerminalThemeColor(hex: 0x39D5FF),
                chromeTop: TerminalThemeColor(hex: 0x081D30),
                chromeBottom: TerminalThemeColor(hex: 0x03121F),
                sidebarTop: TerminalThemeColor(hex: 0x081A2A),
                sidebarBottom: TerminalThemeColor(hex: 0x04111D),
                card: TerminalThemeColor(hex: 0x082034),
                cardBorder: TerminalThemeColor(hex: 0x16405A),
                normalANSI: [
                    TerminalThemeColor(hex: 0x03283A),
                    TerminalThemeColor(hex: 0x0F9BDD),
                    TerminalThemeColor(hex: 0x00C2A8),
                    TerminalThemeColor(hex: 0x16A6FF),
                    TerminalThemeColor(hex: 0x0A84FF),
                    TerminalThemeColor(hex: 0x45B8FF),
                    TerminalThemeColor(hex: 0x00D1FF),
                    TerminalThemeColor(hex: 0xC6F6FF)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x1D536A),
                    TerminalThemeColor(hex: 0x44C7FF),
                    TerminalThemeColor(hex: 0x42F8D2),
                    TerminalThemeColor(hex: 0x6BD0FF),
                    TerminalThemeColor(hex: 0x69B8FF),
                    TerminalThemeColor(hex: 0x8DD6FF),
                    TerminalThemeColor(hex: 0x78EBFF),
                    TerminalThemeColor(hex: 0xE7FCFF)
                ]
            )
        case .hackerGreen:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x08140A),
                foreground: TerminalThemeColor(hex: 0x7BFFA0),
                accent: TerminalThemeColor(hex: 0x15F05D),
                cursor: TerminalThemeColor(hex: 0x7BFFA0),
                chromeTop: TerminalThemeColor(hex: 0x102014),
                chromeBottom: TerminalThemeColor(hex: 0x08140A),
                sidebarTop: TerminalThemeColor(hex: 0x102014),
                sidebarBottom: TerminalThemeColor(hex: 0x09140A),
                card: TerminalThemeColor(hex: 0x122617),
                cardBorder: TerminalThemeColor(hex: 0x244D2E),
                normalANSI: [
                    TerminalThemeColor(hex: 0x0D1F10),
                    TerminalThemeColor(hex: 0x12B44B),
                    TerminalThemeColor(hex: 0x0DD45A),
                    TerminalThemeColor(hex: 0x58E77B),
                    TerminalThemeColor(hex: 0x24C67D),
                    TerminalThemeColor(hex: 0x4AEF9A),
                    TerminalThemeColor(hex: 0x58F7BE),
                    TerminalThemeColor(hex: 0xD4FFE0)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x3D6846),
                    TerminalThemeColor(hex: 0x38EA76),
                    TerminalThemeColor(hex: 0x6FFF9D),
                    TerminalThemeColor(hex: 0x9BFFBF),
                    TerminalThemeColor(hex: 0x7DFFB9),
                    TerminalThemeColor(hex: 0xA2FFD0),
                    TerminalThemeColor(hex: 0xB8FFE5),
                    TerminalThemeColor(hex: 0xF1FFF5)
                ]
            )
        case .hackerRed:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x190506),
                foreground: TerminalThemeColor(hex: 0xFF8A8A),
                accent: TerminalThemeColor(hex: 0xFF3B3B),
                cursor: TerminalThemeColor(hex: 0xFF7575),
                chromeTop: TerminalThemeColor(hex: 0x260B0D),
                chromeBottom: TerminalThemeColor(hex: 0x190506),
                sidebarTop: TerminalThemeColor(hex: 0x240A0C),
                sidebarBottom: TerminalThemeColor(hex: 0x180506),
                card: TerminalThemeColor(hex: 0x2B0E11),
                cardBorder: TerminalThemeColor(hex: 0x5D1E25),
                normalANSI: [
                    TerminalThemeColor(hex: 0x2D1115),
                    TerminalThemeColor(hex: 0xE03131),
                    TerminalThemeColor(hex: 0xFF6961),
                    TerminalThemeColor(hex: 0xFF8C5A),
                    TerminalThemeColor(hex: 0xC93C50),
                    TerminalThemeColor(hex: 0xFF5C7A),
                    TerminalThemeColor(hex: 0xFF7B72),
                    TerminalThemeColor(hex: 0xFFD7D7)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x6A3137),
                    TerminalThemeColor(hex: 0xFF6B6B),
                    TerminalThemeColor(hex: 0xFF8A80),
                    TerminalThemeColor(hex: 0xFFA06B),
                    TerminalThemeColor(hex: 0xFF7285),
                    TerminalThemeColor(hex: 0xFF91A4),
                    TerminalThemeColor(hex: 0xFFADA7),
                    TerminalThemeColor(hex: 0xFFF2F2)
                ]
            )
        case .everforestDark:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x232A2E),
                foreground: TerminalThemeColor(hex: 0xD3C6AA),
                accent: TerminalThemeColor(hex: 0xA7C080),
                cursor: TerminalThemeColor(hex: 0xE69875),
                chromeTop: TerminalThemeColor(hex: 0x293235),
                chromeBottom: TerminalThemeColor(hex: 0x202729),
                sidebarTop: TerminalThemeColor(hex: 0x283034),
                sidebarBottom: TerminalThemeColor(hex: 0x232A2E),
                card: TerminalThemeColor(hex: 0x2F383E),
                cardBorder: TerminalThemeColor(hex: 0x475258),
                normalANSI: [
                    TerminalThemeColor(hex: 0x374145),
                    TerminalThemeColor(hex: 0xE67E80),
                    TerminalThemeColor(hex: 0xA7C080),
                    TerminalThemeColor(hex: 0xDBBC7F),
                    TerminalThemeColor(hex: 0x7FBBB3),
                    TerminalThemeColor(hex: 0xD699B6),
                    TerminalThemeColor(hex: 0x83C092),
                    TerminalThemeColor(hex: 0xD3C6AA)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x859289),
                    TerminalThemeColor(hex: 0xF0959B),
                    TerminalThemeColor(hex: 0xB8D39C),
                    TerminalThemeColor(hex: 0xF0D399),
                    TerminalThemeColor(hex: 0x9ACFC5),
                    TerminalThemeColor(hex: 0xE6B4CD),
                    TerminalThemeColor(hex: 0xA6D6A7),
                    TerminalThemeColor(hex: 0xFFF9E8)
                ]
            )
        case .nightOwl:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x011627),
                foreground: TerminalThemeColor(hex: 0xD6DEEB),
                accent: TerminalThemeColor(hex: 0x7FDBCA),
                cursor: TerminalThemeColor(hex: 0x80A4C2),
                chromeTop: TerminalThemeColor(hex: 0x0B2137),
                chromeBottom: TerminalThemeColor(hex: 0x051321),
                sidebarTop: TerminalThemeColor(hex: 0x0A1E32),
                sidebarBottom: TerminalThemeColor(hex: 0x041421),
                card: TerminalThemeColor(hex: 0x10243D),
                cardBorder: TerminalThemeColor(hex: 0x24405E),
                normalANSI: [
                    TerminalThemeColor(hex: 0x01111D),
                    TerminalThemeColor(hex: 0xEF5350),
                    TerminalThemeColor(hex: 0x22DA6E),
                    TerminalThemeColor(hex: 0xC5E478),
                    TerminalThemeColor(hex: 0x82AAFF),
                    TerminalThemeColor(hex: 0xC792EA),
                    TerminalThemeColor(hex: 0x21C7A8),
                    TerminalThemeColor(hex: 0xFFFFFF)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x575656),
                    TerminalThemeColor(hex: 0xFF869A),
                    TerminalThemeColor(hex: 0x7FE089),
                    TerminalThemeColor(hex: 0xD6DEEB),
                    TerminalThemeColor(hex: 0xB2C5FF),
                    TerminalThemeColor(hex: 0xD4BFFF),
                    TerminalThemeColor(hex: 0x7FE7D8),
                    TerminalThemeColor(hex: 0xFFFFFF)
                ]
            )
        case .rosePineMoon:
            TerminalThemeSpec(
                background: TerminalThemeColor(hex: 0x232136),
                foreground: TerminalThemeColor(hex: 0xE0DEF4),
                accent: TerminalThemeColor(hex: 0xC4A7E7),
                cursor: TerminalThemeColor(hex: 0xEA9A97),
                chromeTop: TerminalThemeColor(hex: 0x2A273F),
                chromeBottom: TerminalThemeColor(hex: 0x201E31),
                sidebarTop: TerminalThemeColor(hex: 0x2A273F),
                sidebarBottom: TerminalThemeColor(hex: 0x232136),
                card: TerminalThemeColor(hex: 0x2F2B46),
                cardBorder: TerminalThemeColor(hex: 0x4A446B),
                normalANSI: [
                    TerminalThemeColor(hex: 0x393552),
                    TerminalThemeColor(hex: 0xEB6F92),
                    TerminalThemeColor(hex: 0x3E8FB0),
                    TerminalThemeColor(hex: 0xF6C177),
                    TerminalThemeColor(hex: 0x9CCFD8),
                    TerminalThemeColor(hex: 0xC4A7E7),
                    TerminalThemeColor(hex: 0xEA9A97),
                    TerminalThemeColor(hex: 0xE0DEF4)
                ],
                brightANSI: [
                    TerminalThemeColor(hex: 0x6E6A86),
                    TerminalThemeColor(hex: 0xFF8BA7),
                    TerminalThemeColor(hex: 0x6FB4D8),
                    TerminalThemeColor(hex: 0xFFD08F),
                    TerminalThemeColor(hex: 0xB8E5EE),
                    TerminalThemeColor(hex: 0xD9C3F6),
                    TerminalThemeColor(hex: 0xF6B8B3),
                    TerminalThemeColor(hex: 0xF6F3FF)
                ]
            )
        }
    }
}

struct InteractiveTerminalTextView: NSViewRepresentable {
    @Binding var text: String
    var theme: TerminalTheme = .defaultTheme
    var onInput: (String) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.defaultBackgroundNSColor
        
        let textView = CustomTerminalTextView()
        textView.autoresizingMask = [.width, .height]
        textView.backgroundColor = theme.defaultBackgroundNSColor
        textView.drawsBackground = true
        textView.textColor = theme.defaultForegroundNSColor
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.insertionPointColor = theme.cursorNSColor
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainerInset = NSSize(width: 15, height: 15)
        textView.focusRingType = .none
        textView.appliedThemeID = theme.id
        textView.selectedTextAttributes = [.backgroundColor: theme.selectionNSColor]
        textView.typingAttributes = terminalTypingAttributes(for: theme)
        
        textView.onInput = { input in
            self.onInput(input)
        }
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTerminalTextView else { return }
        applyTheme(theme, to: scrollView, textView: textView)
        
        if textView.renderedSource != text || textView.appliedThemeID != theme.id {
            textView.textStorage?.setAttributedString(ansiAttributedString(from: text))
            textView.renderedSource = text
            textView.appliedThemeID = theme.id
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func ansiAttributedString(from source: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var fg = theme.defaultForegroundNSColor
        var bg = theme.defaultBackgroundNSColor
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
            fg = theme.defaultForegroundNSColor
            bg = theme.defaultBackgroundNSColor
            bold = false
            return
        }
        
        var i = 0
        while i < values.count {
            let value = values[i]
            switch value {
            case 0:
                fg = theme.defaultForegroundNSColor
                bg = theme.defaultBackgroundNSColor
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
                fg = theme.defaultForegroundNSColor
            case 40...47:
                bg = ansiColor(for: value - 40, bright: false)
            case 100...107:
                bg = ansiColor(for: value - 100, bright: true)
            case 49:
                bg = theme.defaultBackgroundNSColor
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
        theme.ansiColor(index: index, bright: bright)
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
    
    private func applyTheme(_ theme: TerminalTheme, to scrollView: NSScrollView, textView: CustomTerminalTextView) {
        scrollView.backgroundColor = theme.defaultBackgroundNSColor
        textView.backgroundColor = theme.defaultBackgroundNSColor
        textView.textColor = theme.defaultForegroundNSColor
        textView.insertionPointColor = theme.cursorNSColor
        textView.selectedTextAttributes = [.backgroundColor: theme.selectionNSColor]
        textView.typingAttributes = terminalTypingAttributes(for: theme)
    }
    
    private func terminalTypingAttributes(for theme: TerminalTheme) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: theme.defaultForegroundNSColor,
            .backgroundColor: theme.defaultBackgroundNSColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]
    }
}

class CustomTerminalTextView: NSTextView {
    var onInput: ((String) -> Void)?
    var renderedSource = ""
    var appliedThemeID = TerminalTheme.defaultTheme.id
    
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
