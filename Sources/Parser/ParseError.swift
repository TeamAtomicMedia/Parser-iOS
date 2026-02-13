//
//  ParseError.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//


fileprivate extension String {
    func indent(_ size: Int) -> String {
        self.split { $0 == "\n" }.map { String(repeating: " ", count: size) + $0 }.joined(separator: "\n")
    }
}

public enum ParseError: Error, CustomStringConvertible, Equatable {
    public var description: String {
        switch self {
        case .expectedToken(let token): "Expected Token \(token)"
        case .expectedType(let typeName): "Expected Type '\(typeName)'"
        case .expectedWhitespace: "Expected Whitespace"
        case .expectedTerminationSequence: "Expected Termination Sequence"
        case .expectedNumber: "Expected Number"
        case .expectedAlphaNumericString: "Expected AlphaNumericString"
        case .expectedCharactersSatisfyingPredicate: "Expected Characters Satisfying Predicate"
        case .negativeLookaheadSucceeded: "Negative Lookahead Succeeded"
        case .expectedSeparatedSequence(let error): "Expected Separated Sequence:\n\(error.description.indent(2))"
        case .expectedNonZeroRepeatingSequence: "Expected Non-Zero Repetition Sequence"
        case .expectedRepeatingSequence(let expected, let got, let error): "Expected \(expected) Repetitions, Got \(got):\n\(error.description.indent(2))"
        case .incompleteParse(let remaining): "Incomplete Parse - Remaining: \n\(remaining)"
        case .contextualError(let context, let error): "- Parsing Error in \(context):\n\(error.description.indent(2))"
        case .eitherError(let firstError, let secondError): "Parsing Failed in Either:\n\("1. \(firstError.description)\n2. \(secondError.description)".indent(2))"
        }
    }
    
    public enum ExpectedToken: Sendable, Equatable, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
        case one(String)
        case oneOf([String])
        
        public init(stringLiteral value: String) {
            self = .one(value)
        }
        
        public init(arrayLiteral elements: String...) {
            self = .oneOf(elements)
        }
        
        public var description: String {
            switch (self) {
            case .one(let str): return "'\(str)'"
            case .oneOf(let strs): return "one of [\(strs.joined(separator: ", "))]"
            }
        }
    }

    case expectedWhitespace
    case expectedTerminationSequence
    case expectedToken(ExpectedToken)
    case expectedType(String)
    case expectedNumber
    case expectedAlphaNumericString
    case expectedCharactersSatisfyingPredicate
    case negativeLookaheadSucceeded
    case expectedNonZeroRepeatingSequence
    case incompleteParse(Substring)
    indirect case contextualError(String, ParseError)
    indirect case eitherError(ParseError, ParseError)
    indirect case expectedSeparatedSequence(ParseError)
    indirect case expectedRepeatingSequence(Int, Int, ParseError)
}
