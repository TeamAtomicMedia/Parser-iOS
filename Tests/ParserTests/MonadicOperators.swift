//
//  MonadicOperators.swift
//  Parser
//
//  Created by Christopher Wainwright on 13/02/2026.
//

import Foundation
import Testing

import Parser

@Suite
struct MonadicOperators {
    @Suite("Functor (map)")
    struct Functor {
        @Test
        func testMapSuccess() {
            let parser: Parser = .number()
            let transformedParser = parser.map {$0 + 1}
            
            let result = try? transformedParser.run("42")
            #expect(result == 43)
        }
        
        @Test
        func testMapFailurePropagation() {
            let parser: Parser = .number()
            let transformedParser = parser.map {$0 + 1}
            
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("A24")
            }
        }
    }
    
    @Suite("Alternative (<|>)")
    struct Alternative {
        enum Cases: Equatable { case i(Int), c(Character) }
        
        var parser1: Parser<Cases> { .number().map {.i($0)} }
        var parser2: Parser<Cases> { .token("X").map {.c($0)} }
        var transformedParser: Parser<Cases> { parser1 <|> parser2 }
        
        @Test
        func testLeftSuccess() {
            let result = try? transformedParser.run("42")
            #expect(result == .i(42))
        }
        
        @Test
        func testRightSuccess() {
            let result = try? transformedParser.run("X")
            #expect(result == .c("X"))
        }
        
        @Test
        func testFailure() {
            #expect(throws: ParseError.eitherError(.expectedNumber, .expectedToken("X"))) {
                try transformedParser.run("Z")
            }
        }
        
        @Test
        func testFailuresPropagate() {
            #expect(throws: ParseError.eitherError(.expectedNumber, .expectedToken("X"))) {
                try transformedParser.run("Z")
            }
        }
    }
    
    @Suite("Monad (>>=)")
    struct Monad {
        var parser1: Parser<Int> { .number() }
        func parser2(count: Int) -> Parser<String> { .token(.init(repeating: "a", count: count)) }
        var transformedParser: Parser<String> { parser1.bind(to: parser2) }
        
        @Test
        func testBind() {
            var input: Substring = "3aaa"
            let result = try? transformedParser.run(&input)
            #expect(result == "aaa")
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindWithTrailing() {
            var input: Substring = "3aaaaa"
            let result = try? transformedParser.run(&input)
            #expect(result == "aaa")
            #expect(input == "aa")
        }
        
        @Test
        func testBindFailure() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("aaa")
            }
        }
        
        @Test
        func testBoundParserFailure() {
            #expect(throws: ParseError.expectedToken(.one("aaaa"))) {
                try transformedParser.run("4")
            }
        }
    }
    
    @Suite("BindLeft (*>)")
    struct BindLeft {
        var parser1: Parser<String> { .whitespace() }
        var parser2: Parser<Int> { .number() }
        var transformedParser: Parser<Int> { parser1 *> parser2 }
        
        @Test
        func testBindLeft() {
            var input: Substring = " 42"
            let result = try? transformedParser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindLeftFailure1() {
            #expect(throws: ParseError.expectedWhitespace) {
                try transformedParser.run("42")
            }
        }
        
        @Test
        func testBindLeftFailure2() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run("  ")
            }
        }
    }
    
    @Suite("BindRight (<*)")
    struct BindRight {
        var parser1: Parser<Int> { .number() }
        var parser2: Parser<String> { .whitespace() }
        var transformedParser: Parser<Int> { parser1 <* parser2 }
        
        @Test
        func testBindRight() {
            var input: Substring = "42 "
            let result = try? transformedParser.run(&input)
            #expect(result == 42)
            #expect(input.isEmpty)
        }
        
        @Test
        func testBindRightFailure1() {
            #expect(throws: ParseError.expectedNumber) {
                try transformedParser.run(" ")
            }
        }
        
        @Test
        func testBindRightFailure2() {
            #expect(throws: ParseError.expectedWhitespace) {
                try transformedParser.run("42")
            }
        }
    }
}
