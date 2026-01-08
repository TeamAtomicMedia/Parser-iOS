//
//  Parsers.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//


/// Common Parsers
public extension Parser {
    /// A convenience Parser to return a value (regardless of input)
    static func result(_ res: T) -> Self {
        Parser<T>{ _ in return res }
    }
    
    /// A convenience Parser to return an error (regardless of input)
    static func error(_ err: ParseError) -> Self {
        Parser<T>{ _ in throw err }
    }
    
    @available(*, deprecated, renamed: "token(_:)", message: "character is deprecated, use functionally identical token instead")
    static func character(_ char: Character) -> Parser<Character> {
        .init { input in
            let original = input
            guard
                let nextChar = input.popFirst(),
                nextChar == char
            else {
                input = original
                throw ParseError.expectedCharacter(char)
            }
            return char
        }
    }
    
    static func token(_ char: Character) -> Parser<Character> {
        .init { input in
            guard let nextChar = input.popFirst(), nextChar == char
            else { throw ParseError.expectedToken(.one("\(char)")) }
            return char
        }.atomic()
    }
    
    static func token(_ str: String) -> Parser<String> {
        .init { input in
            guard input.hasPrefix(str)
            else { throw ParseError.expectedToken(.one(str)) }
            input.removeFirst(str.count)
            return str
        }
    }
    
    /// A convenience Parser to return an empty void and perform no action
    static func empty() -> Parser<String> {
        .init { _ in "" }
    }
    
    static func character(where predicate: @Sendable @escaping (Character) -> Bool) -> Parser<Character> {
        .init { input in
            let original = input
            guard let nextChar = input.popFirst(), predicate(nextChar) else {
                input = original
                throw ParseError.expectedCharactersSatisfyingPredicate
            }
            return nextChar
        }
    }
    
    static func predicate(allowEmpty: Bool = false, where predicate: @Sendable @escaping (Character) -> Bool) -> Parser<String> {
        .init { input in
            let prefix = input.prefix(while: predicate)
            if prefix.isEmpty && !allowEmpty { throw ParseError.expectedCharactersSatisfyingPredicate}
            input.removeFirst(prefix.count)
            return String(prefix)
        }
    }
    
    static func until<U>(terminator: Parser<U>, allowEmpty: Bool = false, allowEOF: Bool = false, consumeTerminator: Bool = false) -> Parser<String> {
        .init { input in
            var collected = Substring()
            var remainder = input
            
            while !remainder.isEmpty {
                let original = remainder
                if let _ = try? terminator.run(&remainder) {
                    // Success: stop and return what we collected so far
                    input = consumeTerminator ? remainder : original // put terminator back into input
                    return String(collected)
                } else {
                    // Consume one character and continue
                    collected.append(remainder.removeFirst())
                }
            }
            
            if allowEOF {
                input = remainder
                return String(collected)
            }
            
            // Ran out of input without finding terminator
            throw ParseError.expectedTerminationSequence
        }
    }
    
    static func whitespace(allowEmpty: Bool = false) -> Parser<String> {
        .init { input in
            let whitespace = input.prefix(while: \.isWhitespace)
            if !allowEmpty && whitespace.isEmpty { throw ParseError.expectedWhitespace }
            input.removeFirst(whitespace.count)
            return String(whitespace)
        }
    }
    
    static func newline() -> Parser<String> {
        Parser<String>.space().optional(defaultValue: "").bind { consumedSpaces in
            Parser<Character>.character(where: \.isNewline).map { consumedSpaces + "\($0)" }
        }
    }
    
    static func space() -> Parser<String> {
        Self.predicate { $0.isWhitespace && !$0.isNewline}
    }

    static func number() -> Parser<Int> {
        .init { input in
            let numberPrefix = input
                .enumerated()
                .prefix {
                    (i, c) in c >= "0" && c <= "9"
                    || c == "-" && i == 0
                }
                .map(\.element)
            guard let intValue = Int(String(numberPrefix))
            else { throw ParseError.expectedNumber }
            input.removeFirst(numberPrefix.count)
            return intValue
        }
    }
    
    static func rawRepr(_ value: T) -> Parser<T> where T: RawRepresentable, T.RawValue == String {
        .init { input in
            let rawValue = value.rawValue
            
            guard input.hasPrefix(rawValue)
            else { throw ParseError.expectedToken(.one(rawValue)) }
            input.removeFirst(rawValue.count)
            return value
        }
    }

    static func enumeration() -> Parser<T> where T: RawRepresentable, T: CaseIterable, T.RawValue == String {
        let baseCase: Parser<T> = .error(.expectedToken(.oneOf(T.allCases.map(\.rawValue))))
        return T.allCases
            .map { rawRepr($0) }
            .reduce(baseCase) { ($0 <|> $1).firstError() }
    }
    
    static func optionalWhitespace() -> Parser<String?> {
        Parser<String>.whitespace().optional()
    }
}
