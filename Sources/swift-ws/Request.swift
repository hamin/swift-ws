//
//  Request.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

import Foundation
import CryptoEssentials
import SHA1

public class Request {

    public var path: String {

        didSet {

            var comps = self.path.components(separatedBy: "/")

            //We don't care about the first element, which will always be nil since paths are like this: "/something"
            for i in 1..<comps.count {

                self.pathComponents.append(comps[i])
            }
        }
    }
    public var pathComponents: [String] = [String]()

    public var arguments = [String:String]() // ?hello=world -> arguments["hello"]
    public var parameters = [String:String]() // /:something -> parameters["something"]

    public var method: HTTPMethod = .UNDEFINED
    public var headers = [String:String]()

    //var bodyData: NSData?
    public var bodyString: String?
    public var body = [String:String]()

    internal var startTime = NSDate()
    var _protocol: String?



    init(headerData: NSData){

        self.path = String()
        self.parseHeaderData(d: headerData)
    }

    private func parseHeaderData(d: NSData){

        //TODO: Parse data line by line, so if body content is not UTF8 encoded, this doesn't crash
        let string = String(data: d, encoding: NSUTF8StringEncoding)
        var http: [String] = string!.components(separatedBy: "\r\n") as [String]

        //Parse method
        if http.count > 0 {

            // The delimiter can be any number of blank spaces
            var startLineArr: [String] = http[0].characters.split { $0 == " " }.map { String($0) }
            if startLineArr.count > 0 {

                if let m = HTTPMethod(rawValue: startLineArr[0]) {

                    self.method = m
                }
            }

            //Parse URL
            if startLineArr.count > 1 {

                let url = startLineArr[1]
                var urlElements: [String] = url.components(separatedBy: "?") as [String]

                self.path = urlElements[0]

                if urlElements.count == 2 {

                    let args = urlElements[1].components(separatedBy: "&") as [String]

                    for a in args {

                        var arg = a.components(separatedBy: "=") as [String]

                        //Would be nicer changing it to something that checks if element in array exists
                        var value = ""
                        if arg.count > 1 {
                            value = arg[1]
                        }

                        // Adding the values removing the %20 bullshit and stuff
                        self.arguments.updateValue(value.removingPercentEncoding!, forKey: arg[0].removingPercentEncoding!)
                    }
                }
            }

            //TODO: Parse HTTP version
            if startLineArr.count > 2{

                _protocol = startLineArr[2]
            }
        }

        //Parse Headers
        var i = 1

        while i < http.count {

            i += 1
            let content = http[i]

            if content == "" {
                // This newline means headers have ended and body started (New line already got parsed ("\r\n"))
                break
            }
            var header = content.components(separatedBy: ": ") as [String]
            if header.count == 2 {

                self.headers.updateValue(header[1], forKey: header[0])
            }
        }

        if i < http.count && (self.method == HTTPMethod.POST || false) { // Add other methods that support body data

            var str = ""
            i += 1
            while i < http.count {
                i += 1
                if !http[i].isEmpty {
                    str += "\(http[i])\n"
                }
            }

            self.bodyString = str.isEmpty ? nil : str
        }
    }

    func parseBodyData(d: NSData?){
        if let data = d {
            bodyString = String(data: data, encoding: NSUTF8StringEncoding)
        }
    }
}



extension Request {
    var isWebSocket: Bool {
        if let connection = self.headers["Connection"], upgrade = self.headers["Upgrade"], version = self.headers["Sec-WebSocket-Version"], _ = self.headers["Sec-WebSocket-Key"]
            where connection.lowercased() == "upgrade" && upgrade.lowercased() == "websocket" && version == "13" {
            return true
        } else {
            return false
        }
    }

    func websocketHandhsakeUpgradeReponse() -> Response {
        let resp = Response()
        resp.headers["Upgrade"] = "websocket"
        resp.headers["Connection"] = "Upgrade"

        let acceptKey = self.headers["Sec-WebSocket-Key"]!
        let hashedString = SHA1.calculate("\(acceptKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
        let encodedKey = Base64.encode(hashedString)

        resp.headers["Sec-WebSocket-Accept"] = encodedKey
        return resp
    }
}
