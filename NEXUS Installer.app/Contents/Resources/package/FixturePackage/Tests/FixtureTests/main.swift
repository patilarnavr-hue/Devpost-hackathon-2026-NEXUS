// FixtureTests — self-test runner for FixturePackage
// Exit code 0 = all pass, 1 = any fail
// Run with: swift run FixtureTests

import Foundation
import FixturePackage

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) -> TestResult {
    let passed = actual == expected
    return TestResult(name: name, passed: passed, message: passed ? "OK" : "Expected \(expected), got \(actual)")
}

func assertTrue(_ condition: Bool, _ name: String, message: String = "") -> TestResult {
    let passed = condition
    return TestResult(name: name, passed: passed, message: passed ? "OK" : message.isEmpty ? "Expected true" : message)
}

var results: [TestResult] = []

// Test 1: calculateTotal returns correct sum (after Defect A fixed)
var ledger = Ledger()
ledger.add(Ledger.Entry(amount: 100.0, description: "Income"))
ledger.add(Ledger.Entry(amount: -25.50, description: "Expense"))
ledger.add(Ledger.Entry(amount: 10.0, description: "Refund"))

let total = ledger.calculateTotal()
let totalDouble = Double(total) ?? 0
results.append(assertEqual(totalDouble, 84.5, "calculateTotal returns correct sum"))

// Test 2: roundHalfEven implements banker's rounding (after Defect B fixed)
var ledger2 = Ledger()
results.append(assertEqual(Ledger().roundHalfEven(0.5), 0, "roundHalfEven(0.5) == 0 (banker's rounding)"))
results.append(assertEqual(Ledger().roundHalfEven(1.5), 2, "roundHalfEven(1.5) == 2 (banker's rounding)"))
results.append(assertEqual(Ledger().roundHalfEven(2.5), 2, "roundHalfEven(2.5) == 2 (banker's rounding)"))
results.append(assertEqual(Ledger().roundHalfEven(3.5), 4, "roundHalfEven(3.5) == 4 (banker's rounding)"))
results.append(assertEqual(Ledger().roundHalfEven(0.4), 0, "roundHalfEven(0.4) == 0"))
results.append(assertEqual(Ledger().roundHalfEven(0.6), 1, "roundHalfEven(0.6) == 1"))

// Test 3: average calculation
var ledger3 = Ledger()
results.append(assertTrue(ledger3.average() == nil, "average() returns nil for empty ledger"))
ledger3.add(Ledger.Entry(amount: 10, description: "a"))
ledger3.add(Ledger.Entry(amount: 20, description: "b"))
results.append(assertEqual(ledger3.average()!, 15.0, "average() returns correct mean"))

// Test 4: Entry timestamp is set
let entry = Ledger.Entry(amount: 5, description: "test")
results.append(assertTrue(entry.timestamp <= Date(), "Entry timestamp is set to now"))

// Print results
var allPassed = true
for r in results {
    let status = r.passed ? "✓ PASS" : "✗ FAIL"
    print("\(status) \(r.name): \(r.message)")
    if !r.passed { allPassed = false }
}

print("\n--- SUMMARY ---")
let passed = results.filter { $0.passed }.count
let totalTests = results.count
print("\(passed)/\(totalTests) tests passed")

if allPassed {
    print("RESULT: ALL TESTS PASSED")
    exit(0)
} else {
    print("RESULT: SOME TESTS FAILED")
    exit(1)
}