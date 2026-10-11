// NEXUS Visual Language — red hierarchy palette
// White: current information. Gray: background/context.
// Dim red: activity. Bright red: attention. Pulsing red: critical.

import SwiftUI

enum Palette {
    static let background = Color.black
    static let white = Color.white
    static let gray = Color(white: 0.55)
    static let grayDim = Color(white: 0.28)

    static let accent = Color(red: 1.0, green: 0.27, blue: 0.22)      // bright red — attention
    static let activity = Color(red: 1.0, green: 0.27, blue: 0.22).opacity(0.45) // dim red
    static let critical = Color(red: 1.0, green: 0.16, blue: 0.13)    // pulsing red — critical
    static let seal = Color.white                                     // verified = white seal

    static let red = Color(red: 1.0, green: 0.27, blue: 0.22)
}
