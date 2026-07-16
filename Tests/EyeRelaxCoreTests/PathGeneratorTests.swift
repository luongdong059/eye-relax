import XCTest
@testable import EyeRelaxCore

final class PathGeneratorTests: XCTestCase {

    /// Mọi quỹ đạo phải nằm trong biên [0,1]² ở mọi phase/vòng.
    func testAllPathsStayInBounds() {
        for type in PathType.allCases {
            for lap in 0..<4 {
                for i in 0...200 {
                    let phase = Double(i) / 200
                    let s = PathGenerator.sample(type, phase: phase, lapIndex: lap, seed: 42)
                    XCTAssertTrue((0...1).contains(s.x), "\(type) x=\(s.x) ngoài biên tại phase \(phase)")
                    XCTAssertTrue((0...1).contains(s.y), "\(type) y=\(s.y) ngoài biên tại phase \(phase)")
                    XCTAssertGreaterThan(s.scale, 0)
                    XCTAssertTrue((0...1).contains(s.opacity))
                }
            }
        }
    }

    /// Quỹ đạo mượt: bước thời gian nhỏ → bước di chuyển nhỏ (liên tục).
    func testSmoothPathsAreContinuous() {
        let smooth: [PathType] = [.horizontal, .vertical, .diagonal, .circle,
                                  .figureEight, .sineWave, .spiral]
        for type in smooth {
            var prev = PathGenerator.sample(type, phase: 0, lapIndex: 0)
            for i in 1...1000 {
                let phase = Double(i) / 1000
                let cur = PathGenerator.sample(type, phase: phase, lapIndex: 0)
                let dist = hypot(cur.x - prev.x, cur.y - prev.y)
                XCTAssertLessThan(dist, 0.05, "\(type) nhảy \(dist) tại phase \(phase)")
                prev = cur
            }
        }
    }

    /// Ping-pong: đầu và cuối vòng trùng nhau → lặp nhiều vòng không giật.
    func testLapBoundariesMatchForCyclicPaths() {
        let cyclic: [PathType] = [.horizontal, .vertical, .circle, .figureEight,
                                  .sineWave, .spiral, .nearFar, .blink]
        for type in cyclic {
            let start = PathGenerator.sample(type, phase: 0, lapIndex: 0)
            let end = PathGenerator.sample(type, phase: 0.99999, lapIndex: 0)
            let dist = hypot(end.x - start.x, end.y - start.y)
            XCTAssertLessThan(dist, 0.05, "\(type) đầu-cuối vòng lệch \(dist)")
        }
    }

    /// Saccade ngẫu nhiên: tất định theo seed và các bước nhảy đủ xa.
    func testSaccadeRandomIsDeterministicAndJumpsFar() {
        for step in 0..<20 {
            let a = PathGenerator.randomPoint(step: step, seed: 7)
            let b = PathGenerator.randomPoint(step: step, seed: 7)
            XCTAssertEqual(a, b, "cùng seed phải cho cùng vị trí")
        }
        for step in 1..<20 {
            let prev = PathGenerator.randomPoint(step: step - 1, seed: 7)
            let cur = PathGenerator.randomPoint(step: step, seed: 7)
            let dist = hypot(cur.x - prev.x, cur.y - prev.y)
            XCTAssertGreaterThanOrEqual(dist, 0.25, "bước \(step) nhảy quá gần (\(dist))")
        }
    }

    func testSaccadeDwellsOnDiscretePoints() {
        // Trong nửa đầu vòng, saccade 2 điểm phải đứng yên ở điểm trái.
        let s1 = PathGenerator.sample(.saccadeHorizontal, phase: 0.1)
        let s2 = PathGenerator.sample(.saccadeHorizontal, phase: 0.4)
        XCTAssertEqual(s1, s2)
        let s3 = PathGenerator.sample(.saccadeHorizontal, phase: 0.6)
        XCTAssertNotEqual(s1, s3)
    }
}

final class ExerciseRunnerTests: XCTestCase {

    private func makeExercise(_ type: PathType = .horizontal, laps: Int = 2,
                              speed: Double = 1) -> Exercise {
        Exercise(name: "test", pathType: type, speed: speed, laps: laps)
    }

    func testSessionTimelineAndFrames() {
        let runner = ExerciseRunner()
        let ex1 = makeExercise(.horizontal, laps: 2) // 8s + 2s chuẩn bị
        let ex2 = makeExercise(.circle, laps: 1)     // 5s + 2s chuẩn bị
        let t0 = Date()
        runner.start(exercises: [ex1, ex2], at: t0)

        guard let session = runner.session else { return XCTFail("chưa có session") }
        XCTAssertEqual(session.items.count, 2)
        XCTAssertEqual(session.totalDuration, 2 + 8 + 2 + 5, accuracy: 0.001)

        // 1s: đang intermission bài 1.
        if case .intermission(let ex, let remaining)? = runner.frame(at: t0.addingTimeInterval(1)) {
            XCTAssertEqual(ex.id, ex1.id)
            XCTAssertEqual(remaining, 1, accuracy: 0.001)
        } else { XCTFail("phải là intermission") }

        // 3s: bài 1 đang chạy.
        if case .active(let ex, _, _)? = runner.frame(at: t0.addingTimeInterval(3)) {
            XCTAssertEqual(ex.id, ex1.id)
        } else { XCTFail("phải là active") }

        // 11s: sang intermission bài 2.
        if case .intermission(let ex, _)? = runner.frame(at: t0.addingTimeInterval(11)) {
            XCTAssertEqual(ex.id, ex2.id)
        } else { XCTFail("phải là intermission bài 2") }

        // Quá tổng thời lượng: hết frame.
        XCTAssertNil(runner.frame(at: t0.addingTimeInterval(18)))
    }

    func testSkipJumpsToNextExercise() {
        let runner = ExerciseRunner()
        let ex1 = makeExercise(.horizontal, laps: 2)
        let ex2 = makeExercise(.circle, laps: 1)
        let t0 = Date()
        runner.start(exercises: [ex1, ex2], at: t0)

        runner.skipCurrent(at: t0.addingTimeInterval(3))
        // Ngay sau skip, thời gian hiệu dụng = end của bài 1 → intermission bài 2.
        if case .intermission(let ex, _)? = runner.frame(at: t0.addingTimeInterval(3.01)) {
            XCTAssertEqual(ex.id, ex2.id)
        } else { XCTFail("skip phải nhảy sang bài 2") }
    }

    func testDisabledExercisesAreExcluded() {
        let runner = ExerciseRunner()
        var ex1 = makeExercise(.horizontal)
        ex1.isEnabled = false
        let ex2 = makeExercise(.circle)
        runner.start(exercises: [ex1, ex2])
        XCTAssertEqual(runner.session?.items.count, 1)
        XCTAssertEqual(runner.session?.items.first?.exercise.id, ex2.id)
    }

    func testTrailOnlyForSmoothPaths() {
        let runner = ExerciseRunner()
        let t0 = Date()
        runner.start(exercises: [makeExercise(.saccadeHorizontal, laps: 4)], at: t0)
        if case .active(_, _, let trail)? = runner.frame(at: t0.addingTimeInterval(4), trailCount: 10) {
            XCTAssertTrue(trail.isEmpty, "saccade không có trail")
        } else { XCTFail("phải là active") }

        runner.start(exercises: [makeExercise(.circle, laps: 2)], at: t0)
        if case .active(_, _, let trail)? = runner.frame(at: t0.addingTimeInterval(4), trailCount: 10) {
            XCTAssertEqual(trail.count, 10)
        } else { XCTFail("phải là active") }
    }

    func testExerciseDurationScalesWithSpeed() {
        XCTAssertEqual(makeExercise(.horizontal, laps: 2, speed: 2).duration, 4, accuracy: 0.001)
        XCTAssertEqual(makeExercise(.horizontal, laps: 2, speed: 0.5).duration, 16, accuracy: 0.001)
    }
}

final class ExerciseSchedulerTests: XCTestCase {

    func testSnoozePushesNextFireDate() {
        let scheduler = ExerciseScheduler()
        let now = Date()
        scheduler.schedule(at: now.addingTimeInterval(60))
        scheduler.snooze(300, from: now)
        XCTAssertEqual(scheduler.nextFireDate!.timeIntervalSince(now), 360, accuracy: 1)
        scheduler.cancel()
        XCTAssertNil(scheduler.nextFireDate)
    }

    func testHandleWakeReschedulesMissedFire() {
        let scheduler = ExerciseScheduler()
        let now = Date()
        scheduler.schedule(at: now.addingTimeInterval(3600))
        // Chưa quá hạn → giữ nguyên.
        scheduler.handleWake(now: now)
        XCTAssertEqual(scheduler.nextFireDate!.timeIntervalSince(now), 3600, accuracy: 1)
        // Giả lập ngủ quên qua mốc hẹn → dời lại ~30s sau khi thức.
        let later = now.addingTimeInterval(7200)
        scheduler.handleWake(now: later)
        XCTAssertEqual(scheduler.nextFireDate!.timeIntervalSince(later), 30, accuracy: 1)
        scheduler.cancel()
    }
}

final class ExerciseLibraryTests: XCTestCase {

    func testBuiltinGroupsAreValid() {
        let groups = ExerciseLibrary.builtinGroups()
        XCTAssertEqual(groups.count, 4)
        for group in groups {
            XCTAssertFalse(group.exercises.isEmpty)
            for ex in group.exercises {
                XCTAssertGreaterThan(ex.duration, 0)
                XCTAssertTrue((0.5...3).contains(ex.speed))
            }
        }
    }

    func testPersistenceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("eyerelax-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let lib = ExerciseLibrary(storageURL: url)
        var ex = lib.groups[0].exercises[0]
        ex.speed = 2.5
        ex.isEnabled = false
        lib.updateExercise(ex)

        let reloaded = ExerciseLibrary(storageURL: url)
        let loaded = reloaded.groups[0].exercises[0]
        XCTAssertEqual(loaded.speed, 2.5)
        XCTAssertFalse(loaded.isEnabled)
        XCTAssertEqual(loaded.id, ex.id)
    }

    func testPlaylistSkipsDisabledGroups() {
        let lib = ExerciseLibrary(storageURL: nil)
        lib.groups[1].isEnabled = false
        let playlist = lib.playlist()
        let disabledIDs = Set(lib.groups[1].exercises.map(\.id))
        XCTAssertFalse(playlist.contains { disabledIDs.contains($0.id) })
        XCTAssertFalse(playlist.isEmpty)
    }
}
