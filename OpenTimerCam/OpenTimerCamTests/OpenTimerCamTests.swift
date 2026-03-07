import Testing
@testable import OpenTimerCam

struct OpenTimerCamTests {

    @Test func formatTimeIncludesMilliseconds() {
        #expect(TimerManager.formatTime(65.432) == "1:05.432")
        #expect(TimerManager.formatTime(0) == "0:00.000")
    }

    @Test func formatCountUpRespectsDurationWithMilliseconds() {
        #expect(TimerManager.formatCountUp(elapsed: 12.987, duration: 0) == "0:12.987")
        #expect(TimerManager.formatCountUp(elapsed: 99.999, duration: 61.120) == "1:01.120")
    }
}
