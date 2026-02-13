//
//  CommonParsers.swift
//  Parser
//
//  Created by Christopher Wainwright on 13/02/2026.
//

import Foundation
import Testing

import Parser

@Suite
struct CommonParsers {
    @Suite
    struct ResultParser {
        @Test
        func testString() {
            var input: Substring = "abc"
            let parser: Parser = .result("hello")
            let result = try? parser.run(&input)
            #expect(result == "hello")
            #expect(input == "abc")
        }
        
        @Test
        func testInteger() {
            var input: Substring = "abc"
            let parser: Parser = .result(420)
            let result = try? parser.run(&input)
            #expect(result == 420)
            #expect(input == "abc")
        }
        
        @Test
        func emptyInputResultParser() {
            var input: Substring = ""
            let parser: Parser = .result("hello")
            let result = try? parser.run(&input)
            #expect(result == "hello")
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct ErrorParser {
        @Test
        func testThrows () {
            var input: Substring = "abc"
            let parser: Parser<String> = .error(.expectedNumber)
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            let parser: Parser<String> = .error(.expectedNumber)
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input.isEmpty)
        }
    }

    @Suite
    struct TokenParser {
        @Suite
        struct Character {
            @Test
            func testSuccess() {
                var input: Substring = "abc"
                let parser: Parser = .token("a")
                let result = try? parser.run(&input)
                #expect(result == "a")
                #expect(input == "bc")
            }
            
            @Test
            func testFailure() {
                var input: Substring = "abc"
                let parser: Parser = .token("x")
                #expect(throws: ParseError.expectedToken("x")) {
                    try parser.run(&input)
                }
                #expect(input == "abc")
            }
        }
        @Suite
        struct String {
            @Test
            func testSuccess() {
                var input: Substring = "hello world"
                let parser: Parser = .token("hello")
                let result = try? parser.run(&input)
                #expect(result == "hello")
                #expect(input == " world")
            }
            
            @Test
            func testFailure() {
                var input: Substring = "hey"
                let parser: Parser = .token("hello")
                #expect(throws: ParseError.expectedToken("hello")) {
                    try parser.run(&input)
                }
                #expect(input == "hey")
            }
        }
    }
    
    @Suite
    struct PredicateParser {
        @Test
        func testConsumesWhileTrue() {
            var input: Substring = "abc123"
            let parser: Parser = .predicate(where: \.isLetter)
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == "123")
        }
        
        @Test
        func testFailsWhenNoMatch() {
            var input: Substring = "123"
            let parser: Parser = .predicate(where: \.isLetter)
            #expect(throws: ParseError.expectedCharactersSatisfyingPredicate) {
                try parser.run(&input)
            }
            #expect(input == "123")
        }
        
        @Test
        func testAllowEmptySucceeds() {
            var input: Substring = "123"
            let parser: Parser = .predicate(allowEmpty: true, where: \.isLetter)
            let result = try? parser.run(&input)
            #expect(result?.isEmpty ?? false)
            #expect(input == "123")
        }
    }
    
    @Suite
    struct UntilParser {
        
        
        @Test
        func testStopsBeforeTerminator() {
            var input: Substring = "abc;def"
            let parser: Parser = .until(terminator: .token(";"))
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == ";def")
        }
        
        @Test
        func testConsumesTerminatorWhenConfigured() {
            var input: Substring = "abc;def"
            let parser: Parser = .until(
                terminator: .token(";"),
                consumeTerminator: true
            )
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input == "def")
        }
        
        @Test
        func testFailsWithoutTerminator() {
            var input: Substring = "abc"
            let parser: Parser = .until(terminator: .token(";"))
            #expect(throws: ParseError.expectedTerminationSequence) {
                try parser.run(&input)
            }
        }
        
        @Test
        func testAllowsEOFWhenConfigured() {
            var input: Substring = "abc"
            let parser: Parser = .until(
                terminator: .token(";"),
                allowEOF: true
            )
            let result = try? parser.run(&input)
            #expect(result == "abc")
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct NumberParser {
        var parser: Parser<Int> { .number() }
        
        @Test
        func testSuccess() {
            var input: Substring = "123abc"
            let result = try? parser.run(&input)
            #expect(result == 123)
            #expect(input == "abc")
        }
        
        @Test
        func testFailsOnNonDigit() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
        
        @Test
        func testAllowsEmptyInput() {
            var input: Substring = ""
            #expect(throws: ParseError.expectedNumber) {
                try parser.run(&input)
            }
            #expect(input.isEmpty)
        }
    }
    
    @Suite
    struct EnumParser {
        enum Kind: String, CaseIterable { case foo, bar }
        
        @Test
        func testRawValueSuccess() {
            var input: Substring = "foo123"
            let parser: Parser<Kind> = .rawRepr(.foo)
            let result = try? parser.run(&input)
            #expect(result == .foo)
            #expect(input == "123")
        }
        
        @Test
        func testEnumerationMatchesAnyCase() {
            var input: Substring = "bar!"
            let parser: Parser<Kind> = .enumeration()
            let result = try? parser.run(&input)
            #expect(result == .bar)
            #expect(input == "!")
        }
        
        @Test
        func testEnumerationParserThrowsForUnknown() {
            var input: Substring = "baz"
            #expect(throws: ParseError.expectedToken(.oneOf(["foo", "bar"]))) {
                try Parser<Kind>.enumeration().run(&input)
            }
            #expect(input == "baz")
        }
    }
    
    
    @Suite
    struct WhitespaceParser {
        var parser: Parser<String> { .whitespace() }
        
        @Test
        func testConsumesSpaces() {
            var input: Substring = "   abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testThrowsWhenNoSpaces() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedWhitespace) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }
    }
     
    @Suite
    struct OptionalWhitespaceParser {
        var parser: Parser<String?> { .optionalWhitespace() }
        
        @Test
        func testConsumesSpaces() {
            var input: Substring = "   abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
        
        @Test
        func testDoesNotThrowWhenNoSpaces() {
            var input: Substring = "abc"
            _ = try? parser.run(&input)
            #expect(input == "abc")
        }
    }
    
    @Suite
    struct SpaceParser {
        var parser: Parser<String> { .space() }

        @Test
        func testConsumesSingleSpace() throws {
            var input: Substring = " abc"
            let result = try parser.run(&input)
            #expect(result == " ")
            #expect(input == "abc")
        }

        @Test
        func testConsumesMultipleSpaces() throws {
            var input: Substring = "    abc"
            let result = try parser.run(&input)
            #expect(result == "    ")
            #expect(input == "abc")
        }

        @Test
        func testStopsBeforeNewline() throws {
            var input: Substring = " \nabc"
            let result = try parser.run(&input)
            #expect(result == " ")
            #expect(input == "\nabc")
        }

        @Test
        func testTabsAreConsideredSpaces() throws {
            var input: Substring = "\t\tabc"
            let result = try parser.run(&input)
            #expect(result == "\t\t")
            #expect(input == "abc")
        }

        @Test
        func testNoSpacesDoesNotConsumeAnything() {
            var input: Substring = "abc"
            #expect(throws: ParseError.expectedCharactersSatisfyingPredicate) {
                try parser.run(&input)
            }
            #expect(input == "abc")
        }

        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
        }
    }
    
    @Suite
    struct NewlineParser {
        var parser: Parser<String> { .newline() }

        @Test
        func testConsumesSingleNewline() throws {
            var input: Substring = "\nabc"
            let result = try parser.run(&input)
            #expect(result == "\n")
            #expect(input == "abc")
        }

        @Test
        func testConsumesSpacesThenNewline() throws {
            var input: Substring = "   \nabc"
            let result = try parser.run(&input)
            #expect(result == "   \n")
            #expect(input == "abc")
        }

        @Test
        func testNoNewlineThrows() {
            var input: Substring = "   abc"
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
            #expect(input == "   abc")
        }

        @Test
        func testEmptyInputThrows() {
            var input: Substring = ""
            #expect(throws: Error.self) {
                _ = try parser.run(&input)
            }
        }
    }
}
