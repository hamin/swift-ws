//
//  POSIXError.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 7/22/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public extension POSIXError {
    
    /// Creates error from C ```errno```.
    static var fromErrorNumber: POSIXError? { return self.init(rawValue: errno) }
}

#if os(Linux)
    
    /// Enumeration describing POSIX error codes.
    public enum POSIXError: ErrorProtocol, RawRepresentable {
        
        case Value(CInt)
        
        public init?(rawValue: CInt) {
            
            self = .Value(rawValue)
        }
        
        public var rawValue: CInt {
            
            switch self {
                
            case let .Value(rawValue): return rawValue
            }
        }
    }
    
#endif

