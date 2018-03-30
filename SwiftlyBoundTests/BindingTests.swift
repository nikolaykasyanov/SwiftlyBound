import XCTest
import SwiftlyBound

class BindingTests: XCTestCase {

    class ObjectA: NSObject {
        @objc
        dynamic var property = 0
    }

    class ObjectB: NSObject {
        @objc
        dynamic var property = 0
    }

    class Control: UIControl {
        private var _property = 0

        @objc
        var property: Int {
            set {
                let key = \Control.property
                willChangeValue(for: key)
                _property = newValue
                didChangeValue(for: key)
            }
            get {
                return _property
            }
        }

        func triggerValueChangedEvent(newValue: Int) {
            _property = newValue
            sendActions(for: .valueChanged)
        }

        func triggerEditingChangedEvent(newValue: Int) {
            _property = newValue
            sendActions(for: .editingChanged)
        }
    }

    var binding: Binding?
    var observations: [NSKeyValueObservation] = []

    override func tearDown() {
        binding = nil
        observations = []
        super.tearDown()
    }
    
    func test_oneWay_SetsFirstAndSubsequentValuesToSecondObject() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        let expectedValues = [3, 2, 1, 6, 7]

        firstObject.property = expectedValues[0]

        var observedValues: [Int] = []
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { secondObject, _ in
            observedValues.append(secondObject.property)
        })

        binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        for index in 1..<expectedValues.endIndex {
            firstObject.property = expectedValues[index]
        }

        XCTAssertEqual(observedValues, expectedValues)
    }

    func test_oneWay_BindingInvalidated_NoMoreUpdates() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        firstObject.property = 65

        var observedValues: [Int] = []
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { secondObject, _ in
            observedValues.append(secondObject.property)
        })

        binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        firstObject.property = -1
        firstObject.property = 12
        binding?.invalidate()
        firstObject.property = 48
        firstObject.property = 1365

        XCTAssertEqual(observedValues, [65, -1, 12])
    }

    func test_oneWay_SecondObjectDeallocated_NothingBadHappens() {
        let firstObject = ObjectA()
        do {
            let secondObject = ObjectB()

            binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)
        }

        firstObject.property = 1;
        firstObject.property = 13;
    }

    func test_oneWay_DoesNotRetainObjects() {
        weak var weakFirstObject: ObjectA?
        weak var weakSecondObject: ObjectB?

        do {
            let firstObject = ObjectA()
            let secondObject = ObjectB()
            weakFirstObject = firstObject
            weakSecondObject = secondObject

            binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

            firstObject.property = 1;
            firstObject.property = 13;
        }

        XCTAssertNil(weakFirstObject)
        XCTAssertNil(weakSecondObject)
    }

    func test_twoWay_SetsInitialValueToSecondObjectUponBinding() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        firstObject.property = Int(arc4random())
        secondObject.property = Int(arc4random())

        var observed = false
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { secondObject, _ in
            XCTAssertFalse(observed)
            observed = true
            XCTAssertEqual(secondObject.property, firstObject.property)
        })

        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { _, _ in
            XCTFail("First object's property changed unexpectedly")
        })

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        XCTAssertTrue(observed)
    }

    func test_twoWay_FirstObjectChanges_UpdatesSecondObjectAndDoesNotLoopForeverAndNoExtraneousFirstObjectChanges() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        let expectedValues = [3, 2, 1, 6, 7]

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        var observedSecondValues: [Int] = []
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { secondObject, _ in
            observedSecondValues.append(secondObject.property)
        })

        var observedFirstValues: [Int] = []
        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { firstObject, _ in
            observedFirstValues.append(firstObject.property)
        })

        for index in 0..<expectedValues.endIndex {
            firstObject.property = expectedValues[index]
        }

        XCTAssertEqual(observedSecondValues, expectedValues)
        XCTAssertEqual(observedFirstValues, expectedValues)
    }

    func test_twoWay_SecondObjectChanged_UpdatesFirstObjectAndDoesNotLoopForeverAndNoExtraneousSecondObjectChanges() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        let expectedValues = [3, 2, 1, 6, 7]

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        var observedSecondValues: [Int] = []
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { secondObject, _ in
            observedSecondValues.append(secondObject.property)
        })

        var observedFirstValues: [Int] = []
        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { firstObject, _ in
            observedFirstValues.append(firstObject.property)
        })

        for index in 0..<expectedValues.endIndex {
            secondObject.property = expectedValues[index]
        }

        XCTAssertEqual(observedSecondValues, expectedValues)
        XCTAssertEqual(observedFirstValues, expectedValues)
    }

    func test_twoWay_SecondObjectIsUIControl_UpdatesFirstObjectOnControlValueChanged() {
        let firstObject = ObjectA()
        let secondObject = Control()

        let expectedValues = [3, 2, 1, 6, 7]

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \Control.property)

        var observedFirstValues: [Int] = []
        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { firstObject, _ in
            observedFirstValues.append(firstObject.property)
        })

        for index in 0..<expectedValues.endIndex {
            if index % 2 == 0 {
                secondObject.triggerValueChangedEvent(newValue: expectedValues[index])
            } else {
                secondObject.triggerEditingChangedEvent(newValue: expectedValues[index])
            }
        }

        XCTAssertEqual(observedFirstValues, expectedValues)
    }

    func test_twoWay_BindingInvalidated_NoMoreUpdates() {
        let firstObject = ObjectA()
        let secondObject = ObjectB()

        firstObject.property = 65

        var firstObservedValues: [Int] = []
        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { object, _ in
            firstObservedValues.append(object.property)
        })

        var secondObservedValues: [Int] = []
        observations.append(secondObject.observe(\ObjectB.property, options: [.new]) { object, _ in
            secondObservedValues.append(object.property)
        })

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

        firstObject.property = -1
        secondObject.property = 88
        firstObject.property = 12
        binding?.invalidate()
        secondObject.property = 48
        firstObject.property = 1365

        XCTAssertEqual(firstObservedValues, [-1, 88, 12, 1365])
        XCTAssertEqual(secondObservedValues, [65, -1, 88, 12, 48])
    }

    func test_twoWay_BindingInvalidatedAndSecondObjectIsUIControl_NoMoreUpdates() {
        let firstObject = ObjectA()
        let secondObject = Control()

        firstObject.property = 65

        var firstObservedValues: [Int] = []
        observations.append(firstObject.observe(\ObjectA.property, options: [.new]) { object, _ in
            firstObservedValues.append(object.property)
        })

        var secondObservedValues: [Int] = []
        observations.append(secondObject.observe(\Control.property, options: [.new]) { object, _ in
            secondObservedValues.append(object.property)
        })

        binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \Control.property)

        firstObject.property = -1
        secondObject.triggerValueChangedEvent(newValue: 88)
        firstObject.property = 12
        binding?.invalidate()
        secondObject.triggerEditingChangedEvent(newValue: 48)
        firstObject.property = 1365

        XCTAssertEqual(firstObservedValues, [-1, 88, 12, 1365])
        XCTAssertEqual(secondObservedValues, [65, -1, 12])
    }

    func test_twoWay_FirstObjectDeallocated_NothingBadHappens() {
        let secondObject = ObjectB()

        do {
            let firstObject = ObjectA()

            binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)
        }

        secondObject.property = 1;
        secondObject.property = 13;
    }

    func test_twoWay_SecondObjectDeallocated_NothingBadHappens() {
        let firstObject = ObjectA()
        do {
            let secondObject = ObjectB()

            binding = Binding.oneWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)
        }

        firstObject.property = 1;
        firstObject.property = 13;
    }

    func test_twoWay_DoesNotRetainObjects() {
        weak var weakFirstObject: ObjectA?
        weak var weakSecondObject: ObjectB?

        do {
            let firstObject = ObjectA()
            let secondObject = ObjectB()
            weakFirstObject = firstObject
            weakSecondObject = secondObject

            binding = Binding.twoWay(first: firstObject, firstKeyPath: \ObjectA.property, second: secondObject, secondKeyPath: \ObjectB.property)

            firstObject.property = 1;
            secondObject.property = 5;
            firstObject.property = 13;
        }

        XCTAssertNil(weakFirstObject)
        XCTAssertNil(weakSecondObject)
    }
}
