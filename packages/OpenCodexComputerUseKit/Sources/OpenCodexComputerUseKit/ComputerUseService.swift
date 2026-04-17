import AppKit
import ApplicationServices
import Foundation

public final class ComputerUseService {
    private var snapshotsByApp: [String: AppSnapshot] = [:]

    public init() {}

    public func listApps() -> String {
        AppDiscovery.listApps()
            .map { descriptor in
                let bundle = descriptor.bundleIdentifier ?? "no-bundle-id"
                return "\(descriptor.name) — \(bundle) [running, pid=\(descriptor.pid)]"
            }
            .joined(separator: "\n")
    }

    public func getAppState(app query: String) throws -> String {
        try refreshSnapshot(for: query).renderedText
    }

    public func click(app query: String, elementIndex: String?, x: Double?, y: Double?, clickCount: Int, mouseButton: String) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        let button = MouseButtonKind(rawValue: mouseButton.lowercased()) ?? .left
        if snapshot.mode == .fixture {
            if let elementIndex {
                let record = try lookupElement(snapshot: snapshot, index: elementIndex)
                guard let identifier = record.identifier else {
                    throw ComputerUseError.invalidArguments("fixture click requires an identifier-backed element")
                }
                try FixtureBridge.post(FixtureCommand(kind: "click", identifier: identifier))
            } else if let x, let y {
                let identifier = try fixtureIdentifier(at: CGPoint(x: x, y: y), snapshot: snapshot)
                try FixtureBridge.post(FixtureCommand(kind: "click", identifier: identifier, x: x, y: y))
            } else {
                throw ComputerUseError.invalidArguments("click requires either element_index or x/y")
            }

            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        InputSimulation.activate(snapshot.app)

        if let elementIndex {
            let record = try lookupElement(snapshot: snapshot, index: elementIndex)

            if button == .left,
               clickCount == 1,
               let element = record.element,
               record.rawActions.contains(kAXPressAction as String),
               AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                Thread.sleep(forTimeInterval: 0.15)
            } else if let point = try globalPoint(for: record, snapshot: snapshot) {
                try InputSimulation.click(at: point, button: button, clickCount: clickCount)
            } else {
                throw ComputerUseError.stateUnavailable("element \(elementIndex) has no clickable frame")
            }
        } else if let x, let y {
            try InputSimulation.click(at: try screenshotToGlobalPoint(snapshot: snapshot, x: x, y: y), button: button, clickCount: clickCount)
        } else {
            throw ComputerUseError.invalidArguments("click requires either element_index or x/y")
        }

        return try refreshSnapshot(for: query).renderedText
    }

    public func performSecondaryAction(app query: String, elementIndex: String, action: String) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        let record = try lookupElement(snapshot: snapshot, index: elementIndex)

        if snapshot.mode == .fixture {
            guard action.caseInsensitiveCompare("Raise") == .orderedSame else {
                throw ComputerUseError.invalidArguments("fixture mode only supports the Raise secondary action")
            }

            InputSimulation.activate(snapshot.app)
            return try refreshSnapshot(for: query).renderedText
        }

        guard let rawAction = matchingAction(requested: action, record: record) else {
            throw ComputerUseError.invalidArguments("element \(elementIndex) does not expose action '\(action)'")
        }

        guard let element = record.element else {
            throw ComputerUseError.stateUnavailable("element \(elementIndex) has no backing accessibility object")
        }

        let result = AXUIElementPerformAction(element, rawAction as CFString)
        guard result == .success else {
            throw ComputerUseError.message("AXUIElementPerformAction failed with \(result.rawValue)")
        }

        Thread.sleep(forTimeInterval: 0.15)
        return try refreshSnapshot(for: query).renderedText
    }

    public func scroll(app query: String, direction: String, elementIndex: String, pages: Int) throws -> String {
        let normalized = direction.lowercased()
        guard ["up", "down", "left", "right"].contains(normalized) else {
            throw ComputerUseError.invalidArguments("scroll direction must be one of up/down/left/right")
        }

        let snapshot = try currentSnapshot(for: query)
        let record = try lookupElement(snapshot: snapshot, index: elementIndex)

        if snapshot.mode == .fixture {
            guard let identifier = record.identifier else {
                throw ComputerUseError.invalidArguments("fixture scroll requires an identifier-backed element")
            }
            try FixtureBridge.post(FixtureCommand(kind: "scroll", identifier: identifier, direction: normalized, pages: pages))
            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        InputSimulation.activate(snapshot.app)

        if let rawAction = record.rawActions.first(where: { $0.caseInsensitiveCompare("AXScroll\(normalized.capitalized)ByPage") == .orderedSame }), let element = record.element {
            for _ in 0..<max(pages, 1) {
                _ = AXUIElementPerformAction(element, rawAction as CFString)
                Thread.sleep(forTimeInterval: 0.05)
            }
        } else if let point = try globalPoint(for: record, snapshot: snapshot) {
            try InputSimulation.scroll(at: point, direction: normalized, pages: pages)
        } else {
            throw ComputerUseError.stateUnavailable("element \(elementIndex) has no scrollable frame")
        }

        return try refreshSnapshot(for: query).renderedText
    }

    public func drag(app query: String, fromX: Double, fromY: Double, toX: Double, toY: Double) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        if snapshot.mode == .fixture {
            try FixtureBridge.post(FixtureCommand(kind: "drag", identifier: "fixture-drag-pad", x: fromX, y: fromY, toX: toX, toY: toY))
            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        InputSimulation.activate(snapshot.app)
        try InputSimulation.drag(
            from: try screenshotToGlobalPoint(snapshot: snapshot, x: fromX, y: fromY),
            to: try screenshotToGlobalPoint(snapshot: snapshot, x: toX, y: toY)
        )
        return try refreshSnapshot(for: query).renderedText
    }

    public func typeText(app query: String, text: String) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        if snapshot.mode == .fixture {
            try FixtureBridge.post(FixtureCommand(kind: "type_text", identifier: "fixture-input", value: text))
            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        InputSimulation.activate(snapshot.app)
        try InputSimulation.typeText(text)
        return try refreshSnapshot(for: query).renderedText
    }

    public func pressKey(app query: String, key: String) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        if snapshot.mode == .fixture {
            try FixtureBridge.post(FixtureCommand(kind: "press_key", identifier: "fixture-key-capture", value: key))
            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        InputSimulation.activate(snapshot.app)
        try InputSimulation.pressKey(key)
        return try refreshSnapshot(for: query).renderedText
    }

    public func setValue(app query: String, elementIndex: String, value: String) throws -> String {
        let snapshot = try currentSnapshot(for: query)
        let record = try lookupElement(snapshot: snapshot, index: elementIndex)

        if snapshot.mode == .fixture {
            guard let identifier = record.identifier else {
                throw ComputerUseError.invalidArguments("fixture set_value requires a known element identifier")
            }

            try FixtureBridge.post(FixtureCommand(kind: "set_value", identifier: identifier, value: value))
            Thread.sleep(forTimeInterval: 0.15)
            return try refreshSnapshot(for: query).renderedText
        }

        guard let element = record.element else {
            throw ComputerUseError.stateUnavailable("element \(elementIndex) has no backing accessibility object")
        }

        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFString)
        guard result == .success else {
            throw ComputerUseError.message("AXUIElementSetAttributeValue failed with \(result.rawValue)")
        }

        Thread.sleep(forTimeInterval: 0.1)
        return try refreshSnapshot(for: query).renderedText
    }

    private func currentSnapshot(for query: String) throws -> AppSnapshot {
        if let snapshot = snapshotsByApp[query.lowercased()] {
            return snapshot
        }

        return try refreshSnapshot(for: query)
    }

    @discardableResult
    private func refreshSnapshot(for query: String) throws -> AppSnapshot {
        let app = try AppDiscovery.resolve(query)
        let snapshot = try SnapshotBuilder.build(for: app)

        let keys = Set([
            query.lowercased(),
            app.name.lowercased(),
            (app.bundleIdentifier ?? "").lowercased(),
        ].filter { !$0.isEmpty })

        for key in keys {
            snapshotsByApp[key] = snapshot
        }

        return snapshot
    }

    private func lookupElement(snapshot: AppSnapshot, index: String) throws -> ElementRecord {
        guard let parsedIndex = Int(index), let record = snapshot.elements[parsedIndex] else {
            throw ComputerUseError.invalidArguments("unknown element_index '\(index)'")
        }

        return record
    }

    private func matchingAction(requested: String, record: ElementRecord) -> String? {
        if let exact = record.rawActions.first(where: { $0.caseInsensitiveCompare(requested) == .orderedSame }) {
            return exact
        }

        if let pretty = zip(record.rawActions, record.prettyActions).first(where: { $0.1.caseInsensitiveCompare(requested) == .orderedSame }) {
            return pretty.0
        }

        return nil
    }

    private func globalPoint(for record: ElementRecord, snapshot: AppSnapshot) throws -> CGPoint? {
        guard let frame = record.localFrame else {
            return nil
        }

        return try screenshotToGlobalPoint(snapshot: snapshot, x: frame.midX, y: frame.midY)
    }

    private func screenshotToGlobalPoint(snapshot: AppSnapshot, x: Double, y: Double) throws -> CGPoint {
        guard let windowBounds = snapshot.windowBounds else {
            throw ComputerUseError.stateUnavailable("No window bounds are available for \(snapshot.app.name). Run get_app_state after bringing the app on screen.")
        }

        return CGPoint(x: windowBounds.minX + x, y: windowBounds.minY + y)
    }

    private func fixtureIdentifier(at point: CGPoint, snapshot: AppSnapshot) throws -> String {
        let candidates = snapshot.elements.values
            .filter { $0.identifier != nil && ($0.localFrame?.contains(point) ?? false) }
            .sorted { lhs, rhs in
                let lhsArea = (lhs.localFrame?.width ?? 0) * (lhs.localFrame?.height ?? 0)
                let rhsArea = (rhs.localFrame?.width ?? 0) * (rhs.localFrame?.height ?? 0)
                return lhsArea < rhsArea
            }

        guard let identifier = candidates.first?.identifier else {
            throw ComputerUseError.invalidArguments("No fixture element contains coordinate (\(Int(point.x)), \(Int(point.y)))")
        }

        return identifier
    }
}
