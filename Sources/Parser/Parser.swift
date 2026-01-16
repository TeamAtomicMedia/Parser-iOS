//
//  Parser.swift
//  NetMock
//
//  Created by Christopher Wainwright on 24/09/2025.
//


public protocol Parsable : Sendable {
    static var parser: Parser<Self> { get }
}

public extension Parsable {
    static func parse(_ substring: inout Substring) throws -> Self {
        try self.parser.run(&substring)
    }
    
    static func parse(_ string: inout String) throws -> Self {
        try self.parser.run(&string)
    }
}

public typealias Parse<T> = @Sendable (inout Substring) throws -> T

public struct Parser<T: Sendable> : Sendable {
    /// Perform the actions defined inside the parser
    private let _run: Parse<T>
    
    public func run(_ substring: inout Substring) throws -> T { try _run(&substring) }

    public func run(_ string: inout String) throws -> T {
        var substring = string[...]
        defer  { string = String(substring) }
        return try self.run(&substring)
    }
    
    public func run(_ substring: Substring) throws -> T {
        var substring = substring
        return try _run(&substring)
    }
    
    public func run(_ string: String) throws -> T {
        var string = string
        return try self.run(&string)
    }
    
    /// Define a parser
    public init(_ run: @escaping Parse<T>) { self._run = run }
}
