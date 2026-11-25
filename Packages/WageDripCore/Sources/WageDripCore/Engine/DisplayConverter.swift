import Foundation

/// Converts a gross pay-currency amount into what the user sees: after the deduction if they
/// asked for after-tax figures, then into the display currency.
public struct DisplayConverter: Sendable {
    private let factor: Decimal

    /// - Parameter rate: 1 pay currency = `rate` display currency.
    public init(settings: Settings, rate: Decimal) {
        let keep: Decimal = settings.showAfterTax ? 1 - settings.deductionRate : 1
        factor = keep * rate
    }

    public func display(_ gross: Decimal) -> Decimal {
        gross * factor
    }
}
