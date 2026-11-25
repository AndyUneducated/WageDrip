import SwiftUI
import WidgetKit

@main
struct WageDripWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AmountWidget()
        #if os(iOS)
        WageLiveActivity()
        #endif
    }
}
