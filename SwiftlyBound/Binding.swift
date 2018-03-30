import UIKit

public class Binding {

    fileprivate let invalidationTokens: [Invalidatable]

    fileprivate init(invalidationTokens: [Invalidatable]) {
        self.invalidationTokens = invalidationTokens
    }

    public func invalidate() {
        invalidationTokens.forEach { $0.invalidate() }
    }

    public static func oneWay<Value, First: NSObject, Second: NSObject>(first: First, firstKeyPath: KeyPath<First, Value>, second: Second, secondKeyPath: ReferenceWritableKeyPath<Second, Value>) -> Binding {
        let observation = first.observe(firstKeyPath, options: [.initial, .new]) { [weak second] first, _ in
            guard let second = second else { return }
            second[keyPath: secondKeyPath] = first[keyPath: firstKeyPath]
        }

        return Binding(invalidationTokens: [observation])
    }

    public static func twoWay<Value, First: NSObject, Second: NSObject>(first: First, firstKeyPath: ReferenceWritableKeyPath<First, Value>, second: Second, secondKeyPath: ReferenceWritableKeyPath<Second, Value>) -> Binding {
        var updating = false
        let firstObservation = first.observe(firstKeyPath, options: [.initial, .new]) { [weak second] first, _ in
            guard let second = second else { return }
            if (updating) { return }
            updating = true
            second[keyPath: secondKeyPath] = first[keyPath: firstKeyPath]
            updating = false
        }

        let secondObjectChangeHandler: (Second) -> Void = { [weak first] second in
            guard let first = first else { return }
            if (updating) { return }
            updating = true
            first[keyPath: firstKeyPath] = second[keyPath: secondKeyPath]
            updating = false
        }

        let secondObservation = second.observe(secondKeyPath, options: [.new]) { second, _ in
            secondObjectChangeHandler(second)
        }

        if let control = second as? UIControl {
            let subscription = ControlEvenSubscription(control: control, event: [.valueChanged, .editingChanged]) { control in
                secondObjectChangeHandler(control as! Second)
            }

            return Binding(invalidationTokens: [firstObservation, secondObservation, subscription])
        }

        return Binding(invalidationTokens: [firstObservation, secondObservation])
    }
}

private class ControlEvenSubscription: NSObject, Invalidatable {
    weak var control: UIControl?
    let event: UIControlEvents
    let block: (UIControl) -> Void

    init(control: UIControl, event: UIControlEvents, block: @escaping (UIControl) -> Void) {
        self.control = control
        self.event = event
        self.block = block
        super.init()
        control.addTarget(self, action: #selector(ControlEvenSubscription.handleControlEvent(_:)), for: event)
    }

    func invalidate() {
        control?.removeTarget(self, action: #selector(ControlEvenSubscription.handleControlEvent(_:)), for: event)
    }

    @objc
    func handleControlEvent(_ control: UIControl) {
        block(control)
    }
}

private protocol Invalidatable {
    func invalidate()
}

extension NSKeyValueObservation: Invalidatable {

}
