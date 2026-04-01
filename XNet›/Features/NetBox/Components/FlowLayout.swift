import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        
        for size in sizes {
            if currentWidth + size.width > (proposal.width ?? .infinity) {
                totalHeight += currentHeight + spacing
                totalWidth = max(totalWidth, currentWidth)
                currentWidth = size.width + spacing
                currentHeight = size.height
            } else {
                currentWidth += size.width + spacing
                currentHeight = max(currentHeight, size.height)
            }
        }
        return CGSize(width: totalWidth, height: totalHeight + currentHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
