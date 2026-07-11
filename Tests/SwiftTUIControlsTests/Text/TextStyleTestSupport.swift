import Foundation
import Observation
import Testing
@testable import SwiftTUIControls
@testable import SwiftTUIEssentials

nonisolated struct CustomShapeStyle: Color, ShapeStyle {

    let background = "48;5;24"

    let foreground = "38;5;42"
}

nonisolated struct CustomErasedShapeStyle: ShapeStyle {

    let _swiftTUIAnyColor = AnyColor(Color16.brightMagenta)
}
