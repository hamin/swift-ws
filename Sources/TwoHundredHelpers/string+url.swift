////
////  string+url.swift
////  twohundred
////
////  Created by Johannes Schriewer on 24/11/15.
////  Copyright © 2015 Johannes Schriewer. All rights reserved.
////
//import Foundation
//
///// URL encoding and decoding support
//public extension String {
//
//    /// URL-encode string
//    ///
//    /// - returns: URL-Encoded version of the string
//    public func urlEncodedString() -> String {
//        var result = ""
//        var gen = self.unicodeScalars.makeIterator()
//
//        while let c = gen.next() {
//            switch c {
//            case " ": // Space
//                result.append("%20")
//            case "!": // !
//                result.append("%21")
//            case "\"": // "
//                result.append("%22")
//            case "#": // #
//                result.append("%23")
//            case "$": // $
//                result.append("%24")
//            case "%": // %
//                result.append("%25")
//            case "&": // &
//                result.append("%26")
//            case "'": // '
//                result.append("%27")
//            case "(": // (
//                result.append("%28")
//            case ")": // )
//                result.append("%29")
//            case "*": // *
//                result.append("%2A")
//            case "+": // +
//                result.append("%2B")
//            case ",": // ,
//                result.append("%2C")
//            case "/": // /
//                result.append("%2F")
//            case ":": // :
//                result.append("%3A")
//            case ";": // ;
//                result.append("%3B")
//            case "=": // =
//                result.append("%3D")
//            case "?": // ?
//                result.append("%3F")
//            case "@": // @
//                result.append("%40")
//            case "[": // [
//                result.append("%5B")
//            case "\\": // \
//                result.append("%5C")
//            case "]": // ]
//                result.append("%5D")
//            case "{": // {
//                result.append("%7B")
//            case "|": // |
//                result.append("%7C")
//            case "}": // }
//                result.append("%7D")
//            default:
//                result.append(c)
//            }
//        }
//        return result
//    }
//
//    /// URL-decode string
//    ///
//    /// - returns: Decoded version of the URL-Encoded string
//    public func urlDecodedString() -> String {
//        var result = ""
//        var gen = self.unicodeScalars.makeIterator()
//
//        while let c = gen.next() {
//            switch c {
//            case "%":
//                // get 2 chars
//                if let c1 = gen.next() {
//                    if let c2 = gen.next() {
//                        if let c = UInt32("\(c1)\(c2)", radix: 16) {
//                            result.append(UnicodeScalar(c))
//                        } else {
//                            result.append("%\(c1)\(c2)")
//                        }
//                    }
//                }
//            default:
//                result.append(c)
//            }
//        }
//
//        return result
//    }
//}