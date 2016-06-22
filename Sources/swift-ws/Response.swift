//
//  Response.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

import Foundation
import TwoHundredHelpers

public class Response {

    public var statusLine: String {
        return status.statusLine()
    }
    public var statusCode: Int {
        return status.rawValue
    }

    public var status: HTTPStatus = .OK
    public var headers = [String:String]()

    public var body: NSData?
    public var bodyString: String? {
        didSet {
            if headers["Content-Type"] == nil {
                //                headers["Content-Type"] = FileTypes.get("txt")
                headers["Content-Type"] = "text/plain"
            }
        }
    }

    var bodyData: NSData {
        if let b = body {
            return b
        } else if bodyString != nil {
            return NSData(data: bodyString!.data(using: NSUTF8StringEncoding)!)
        }

        return NSData()
    }

    private let http_protocol: String = "HTTP/1.1"
    public func redirect(url u: String) {

        self.status = .Found
        self.headers["Location"] = u
    }


    public func setFile(url: NSURL?) {

        if let u = url, let data = NSData(contentsOf: u) {
            self.body = data
            //            self.headers["Content-Type"] = FileTypes.get(u.pathExtension ?? "")
        } else {
            self.setError(errorStatus: .NotFound)
        }
    }

    public func setError(errorStatus: HTTPStatus){
        self.status = errorStatus
    }

    func headerData() -> NSData {

        if headers["Content-Length"] == nil{
            headers["Content-Length"] = String(bodyData.length)
        }

        let startLine = "\(self.http_protocol) \(String(self.statusCode)) \(self.statusLine)\r\n"

        var headersStr = ""
        for (k, v) in self.headers {

            headersStr += "\(k): \(v)\r\n"
        }

        headersStr += "\r\n"
        let finalStr = String(format: startLine+headersStr)

        return NSMutableData(data: finalStr.data(using: NSUTF8StringEncoding, allowLossyConversion: false)!)
    }

    internal func generateResponse(method: HTTPMethod) -> NSData {

        let headerData = self.headerData()

        guard method != .HEAD else { return headerData }
        return headerData + self.bodyData

    }
}

extension Response {
    public func handshakeUpgradeMakeSocketData() {
        // var result = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        var result = "HTTP/1.1 101 Switching Protocols\r\n"
        // result.appendContentsOf("X-Powered-By: TwoHundred\r\n")
        for (headerKey, headerValue) in self.headers {
            result.append("\(headerKey): \(headerValue)\r\n")
        }
        let date = Date(timestamp: time(nil))
        result.append("Date: \(date.rfc822DateString!)\r\n")
        result.append("\r\n")
        self.bodyString = result
    }
}
