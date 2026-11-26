import Foundation
import Testing
@testable import WageDripCore

@Suite struct WatchPayloadTests {
    @Test func roundTripsThroughDictionary() {
        var settings = Settings.defaults(for: .us)
        settings.onboardingDone = true
        let file = Data(#"{"days":[{"name":"x","date":"2028-01-26","isOffDay":true}]}"#.utf8)
        let payload = WatchPayload(settings: settings, payToDisplayRate: Decimal(string: "7.1234")!, holidayFiles: [2028: file])
        #expect(WatchPayload(dictionary: payload.dictionary) == payload)
    }

    @Test func rejectsMissingOrBrokenParts() {
        let good = WatchPayload(settings: .defaults(for: .cn), payToDisplayRate: 1).dictionary
        #expect(WatchPayload(dictionary: [:]) == nil)
        var noSettings = good; noSettings["settings"] = Data("garbage".utf8)
        #expect(WatchPayload(dictionary: noSettings) == nil)
        var zeroRate = good; zeroRate["rate"] = "0"
        #expect(WatchPayload(dictionary: zeroRate) == nil)
    }

    @Test func downloadedFilesAreListedByYear() {
        let store = MemoryStore()
        #expect(CNHolidays.downloadedFiles(storage: store).isEmpty)
        let file = Data(#"{"days":[{"name":"x","date":"2028-01-26","isOffDay":true}]}"#.utf8)
        #expect(CNHolidays.storeDownloaded(file, year: 2028, storage: store))
        #expect(CNHolidays.downloadedFiles(storage: store) == [2028: file])
    }
}
