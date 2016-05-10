//
//  response.swift
//  twohundred
//
//  Created by Johannes Schriewer on 01/11/15.
//  Copyright © 2015 Johannes Schriewer. All rights reserved.
//
import Foundation

/// HTTP Header
public struct HTTPHeader {
    /// Name of the header
    var name: String

    /// Value of the header
    var value: String

    /// Quick initialize without parameter names
    ///
    /// - parameter name: name of the header
    /// - parameter value: value of the header
    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}

/// HTTP Response class, subclass to make specialized responses (TemplateResponse, JSONResponse, etc.)
public class HTTPResponse {
    /// Body data to send, array to support building multipart responses, will be concatenated on execution
    var body = [SocketData]()

    /// Headers to send, autogenerated: X-Powered-By, Content-Length, Connection, Date, Set-Cookie
    var headers = [HTTPHeader]()

    /// The status code to send
    let statusCode: HTTPStatusCode

    /// Set a cookie for the response
    ///
    /// - parameter name: name of the cookie
    /// - parameter value: value of the cookie
    /// - parameter domain: cookie domain
    /// - parameter path: path, defaults to /
    /// - parameter expires: expiry date or nil for permanent cookies
    /// - parameter secure: only send cookie over HTTPS, defaults to secure cookies
    /// - parameter httpOnly: only use cookie for HTTP/S queries, will be unaccessible by javascript when set to true
    public func setCookie(name: String, value: String, domain: String, path: String = "/", expires: Date? = nil, secure: Bool = true, httpOnly: Bool = true) {
        var value = "\(name)=\(value); Domain=\(domain); Path=\(path)"
        if expires != nil {
            value.append("; Expires=\(expires!.rfc822DateString)")
        }
        if secure {
            value.append("; Secure")
        }
        if (httpOnly) {
            value.append("; HttpOnly")
        }

        let header = HTTPHeader("Set-Cookie", value)
        self.headers.append(header)
    }

    /// Initialize HTTP Response
    ///
    /// - parameter statusCode: HTTP status code to send
    /// - parameter body: (optional) body parts to send
    /// - parameter headers: (optional) additional headers to send
    /// - parameter contentType: (optional) content type to set
    public init(_ statusCode: HTTPStatusCode, body: [SocketData]? = nil, headers: [HTTPHeader]? = nil, contentType: String? = nil) {
        self.statusCode = statusCode
        if let body = body {
            self.body.append(contentsOf: body)
        }
        if let headers = headers {
            self.headers.append(contentsOf: headers)
        }
        if let contentType = contentType {
            self.headers.append(HTTPHeader("Content-Type", contentType))
        }
    }

    // MARK: - Internal

    /// Render header part for the response
    ///
    /// - returns: SocketData instance to prepend to body parts
    func makeSocketData() -> SocketData {
        var result = "HTTP/1.1 " + self.statusCode.rawValue + "\r\n"
        // result.appendContentsOf("X-Powered-By: TwoHundred\r\n")
        for header in self.headers {
            result.append("\(header.name): \(header.value)\r\n")
        }
        if self.body.count > 0 {
            var size = 0
            for item in body {
                size += item.calculateSize()
            }
            result.append("Content-Length: \(size)\r\n")
        }
        result.append("Connection: keep-alive\r\n")
        let date = Date(timestamp: time(nil))
        result.append("Date: \(date.rfc822DateString!)\r\n")
        result.append("\r\n")
        return .StringData(result)
    }

    func handshakeUpgradeMakeSocketData() -> SocketData {
        // var result = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        var result = "HTTP/1.1 101 Switching Protocols\r\n"
        // result.appendContentsOf("X-Powered-By: TwoHundred\r\n")
        for header in self.headers {
            result.append("\(header.name): \(header.value)\r\n")
        }
        let date = Date(timestamp: time(nil))
        result.append("Date: \(date.rfc822DateString!)\r\n")
        result.append("\r\n")
        return .StringData(result)
    }
}
