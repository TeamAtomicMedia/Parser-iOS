//
//  ParserTests.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//

import Foundation
import Testing

import Parser

@Suite
struct ParserModifiers {
    @Suite
    struct Atomic {
        var parser: Parser<(Character, Int)> { .init { input in
            let parser1: Parser<Character> = .token("a")
            let parser2: Parser = .number()
            
            let result1 = try parser1.run(&input)
            let result2 = try parser2.run(&input)
            
            return (result1, result2)
        } }
        
        @Test
        func testDestructiveParser() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            // Note that without usage of .atomic(), input is partially consumed
            #expect(input == "bc")
        }
        
        @Test
        func testSuccessConsumesInput() throws {
            var input: Substring = "a1c"
            let result = try parser.atomic().run(&input)
            #expect(result == ("a", 1))
            #expect(input == "c")
        }
        
        @Test
        func testFailureRestoresInput() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedNumber) {
                try parser.atomic().run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testSuccessDoesNotRollback() {
            var input: Substring = "abc"
            let parser: Parser = .token("a").atomic()
            let result = try! parser.run(&input)
            #expect(result == "a")
            #expect(input == "bc")
        }
        
        @Test
        func testFailureRollsBack() {
            var input: Substring = "abc"
            let parser: Parser = .token("z").atomic()
            #expect(throws: ParseError.expectedToken("z")) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testNonConsumingAtomic() {
            var input: Substring = "abc"
            let parser: Parser = .result("res").atomic()
            let result = try? parser.run(&input)
            #expect(result == "res")
            #expect(input == "abc")
        }
        
        @Test
        func testNestedAtomicRestoresInput() {
            var input: Substring = "abc"
            let inner: Parser = .token("a").atomic()
            let outer: Parser = (inner *> .token("z")).atomic()
            #expect(throws: ParseError.expectedToken("z")) {
                try outer.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testEOFRestoresInput() {
            var input: Substring = "a"
            #expect(throws: ParseError.expectedNumber) {
                try parser.atomic().run(&input)
            }
            #expect(input == "a")
        }
        
        @Test
        func testEmptyInput() {
            var input: Substring = ""
            #expect(throws: ParseError.expectedToken("a")) {
                try parser.atomic().run(&input)
            }
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Optional {
        @Test
        func testSuccessReturnsValue() {
            var input: Substring = "a"
            let parser: Parser = .token("a").optional()
            let result = try! parser.run(&input)
            #expect(result == "a")
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailureReturnsNilAndRestoresInput() {
            var input: Substring = "b"
            let parser: Parser = .token("a").optional()
            let result = try! parser.run(&input)
            #expect(result == nil)
            #expect(input == "b")
        }
        
        @Test
        func testSuccessConsumesInput() {
            var input: Substring = "420"
            let parser: Parser = .number().optional()
            let result = try! parser.run(&input)
            #expect(result == 420)
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailureRestoresInput() {
            var input: Substring = "abc"
            let parser = Parser<Int>.number().optional()
            let result = try! parser.run(&input)
            #expect(result == nil)
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultSuccessReturnsParsedValue() {
            var input: Substring = "42"
            let parser: Parser = .number().optional(defaultValue: 99)
            let result = try! parser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testDefaultFailureReturnsDefault() {
            var input: Substring = "abc"
            let parser: Parser = .number().optional(defaultValue: 99)
            let result = try! parser.run(&input)
            #expect(result == 99)
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultFailureDoesNotConsumeInput() {
            var input: Substring = "abc"
            let parser: Parser = .token("z").optional(defaultValue: "x")
            let result = try! parser.run(&input)
            #expect(result == "x")
            #expect(input == "abc")
        }
        
        @Test
        func testDefaultEmptyInput() {
            var input: Substring = ""
            let parser: Parser = .number().optional(defaultValue: 420)
            let result = try! parser.run(&input)
            #expect(result == 420)
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Discard {
        @Test
        func testDiscardConsumesInputOnSuccess() {
            var input: Substring = "abc"
            let parser: Parser = .token("a").discard()
            try! parser.run(&input)
            #expect(input == "bc")
        }
        
        @Test
        func testDiscardLeavesInputOnFailure() {
            var input: Substring = "abc"
            let parser: Parser = .token("z").discard()
            try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDiscardReturnsVoid() {
            var input: Substring = "123"
            let parser: Parser = .number().discard()
            let result: Void? = try? parser.run(&input)
            #expect(result != nil)
            #expect(input.isEmpty)
        }
        
        @Test
        func testDiscardFailureDoesNotConsumeInput() {
            var input: Substring = "abc"
            let parser: Parser = .number().discard()
            try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDiscardOnEmptyInputFails() {
            var input: Substring = ""
            let parser: Parser = .token("a").discard()
            let result: Void? = try? parser.run(&input)
            #expect(result != nil)
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct Context {
        @Test
        func testSuccessPassthrough() {
            let parser: Parser = .result(42).context("should never appear")
            let result = try? parser.run("")
            #expect(result == 42)
        }
        
        @Test
        func testFailureWrapsError() {
            let parser: Parser<Void> = .error(.expectedNumber).context("Context Label")
            #expect(throws: ParseError.contextualError("Context Label", .expectedNumber)) {
                try parser.run("")
            }
        }
        
        @Test
        func testNestedContextError() {
            let parser: Parser<Void> = .error(.expectedNumber).context("Inner Context").context("Outer Context")
            #expect(throws: ParseError.contextualError("Outer Context", .contextualError("Inner Context", .expectedNumber))) {
                try parser.run("")
            }
        }
    }
    
    @Suite
    struct Complete {
        var parser: Parser<Int> { .number().complete() }
        
        @Test
        func testSuccess() {
            var input: Substring = "42"
            let result = try? parser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailure() {
            var input: Substring = "42a"
            #expect(throws: ParseError.incompleteParse("a")) {
                try parser.run(&input)
            }
            #expect(input == "a")
        }
        
        @Test
        func testFailureWithWhitespace() {
            var input: Substring = "42 "
            #expect(throws: ParseError.incompleteParse(" ")) {
                try parser.run(&input)
            }
            #expect(input == " ")
        }
    }
    
    @Suite
    struct Separated {
        @Test
        func testSingleElement() {
            var input: Substring = "a"
            let parser: Parser = .token("a").separated(by: .token(","))
            let result = try? parser.run(&input)
            #expect(result == ["a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testMultipleElements() {
            var input: Substring = "a,a,a"
            let parser: Parser = .token("a").separated(by: .token(","))
            let result = try? parser.run(&input)
            #expect(result == ["a", "a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testEmptyAllowed() {
            var input: Substring = ""
            let parser: Parser = .token("a").separated(by: .token(","), allowEmpty: true)
            let result = try! parser.run(&input)
            #expect(result.isEmpty)
            #expect(input.isEmpty)
        }
        
        @Test
        func testEmptyDisallowed() {
            var input: Substring = ""
            let parser: Parser = .token("a").separated(by: .token(","))
            #expect(throws: ParseError.expectedSequence(.expectedToken("a"))) {
                try parser.run(&input)
            }
        }
        
        @Test
        func testTrailingSeparatorAllowed() throws {
            var input: Substring = "a,a,"
            let parser: Parser = .token("a").separated(by: .token(","), consumeTrailingSeparator: true)
            let result = try parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testTrailingSeparatorDisallowed() throws {
            var input: Substring = "a,a,"
            let parser: Parser = .token("a").separated(by: .token(","), consumeTrailingSeparator: false)
            let result = try parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == ",")
        }
        
        @Test
        func testCustomSeparator() throws {
            var input: Substring = "a|a|a"
            let separator: Parser = .token("|").discard()
            let parser: Parser = .token("a").separated(by: separator)
            let result = try parser.run(&input)
            #expect(result == ["a", "a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testStopsOnUnrecognisedElement() throws {
            var input: Substring = "a,a,b"
            let parser: Parser = .token("a").separated(by: .token(","), consumeTrailingSeparator: true)
            let result = try parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "b")
        }
        
        @Test
        func testFailsAndReturnsElementParseError() {
            enum TestElements: String, CaseIterable { case a, b, c}
            
            var input: Substring = "1,2,3"
            let parser: Parser = Parser<TestElements>.enumeration().separated(by: .token(","))
            #expect(throws: ParseError.expectedSequence(.expectedToken(.oneOf(["a", "b", "c"])))) {
                try parser.run(&input)
            }
            #expect(input == "1,2,3")
        }
    }
    
    @Suite
    struct RepeatCount {
        @Test
        func testExactCount() {
            var input: Substring = "aaa"
            let parser: Parser = .token("a").repeat(for: 3)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testExactCountStopsWithExtra() {
            var input: Substring = "aaa"
            let parser: Parser = .token("a").repeat(for: 2)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "a")
        }
        
        @Test
        func testEmpty() {
            var input: Substring = "aaa"
            let parser: Parser = .token("a").repeat(for: 0)
            let result = try? parser.run(&input)
            #expect(result == [])
            #expect(input == "aaa")
        }
        
        @Test
        func testEmptyNonAllowed() {
            var input: Substring = "aaa"
            let parser: Parser = .token("a").repeat(for: 0, allowEmpty: false)
            #expect(throws: ParseError.expectedNonZeroRepeatingSequence) {
                try parser.run(&input)
            }
        }
    }
    
    @Suite
    struct RepeatRange {
        @Test
        func testExactCount() {
            var input: Substring = "aa"
            let parser: Parser = .token("a").repeat(in: 2...2)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testExactCountStopsWithExtra() {
            var input: Substring = "aaa"
            let parser: Parser = .token("a").repeat(in: 2...2)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "a")
        }
        
        @Test
        func testMinToMax() {
            var input: Substring = "aa"
            let parser: Parser = .token("a").repeat(in: 1...3)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input.isEmpty)
        }
        
        @Test
        func testFailsWhenBelowMin() {
            var input: Substring = ""
            let parser: Parser = .token("a").repeat(in: 1...3)
            #expect(throws: ParseError.expectedRepeatingSequence(1, 0, .expectedToken(.one("a")))) {
                try parser.run(&input)
            }
        }
        
        @Test
        func testRangeStopsWithExtra() {
            var input: Substring = "aaaa"
            let parser: Parser = .token("a").repeat(in: 1...2)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "aa")
        }
        
        @Test
        func testZero() {
            var input: Substring = "b"
            let parser: Parser = .token("a").repeat(in: 0...2)
            let result = try? parser.run(&input)
            #expect(result?.isEmpty ?? false)
            #expect(input == "b")
        }
        
        @Test
        func testStopsAtMaxWithoutExtra() {
            var input: Substring = "aab"
            let parser: Parser = .token("a").repeat(in: 1...2)
            let result = try? parser.run(&input)
            #expect(result == ["a", "a"])
            #expect(input == "b")
        }
    }
}

