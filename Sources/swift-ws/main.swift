import CryptoEssentials
import SHA1
import TwoHundredHelpers
import Dispatch

import SwiftSockets
import Foundation

public enum HTTPMethod: String {
    
    case GET = "GET"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case POST = "POST"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
    case UNDEFINED = "UNDEFINED" // it will never match
}

func + (lhs: NSData, rhs: NSData) -> NSData {
    
    let data = NSMutableData(data: lhs)
    data.append(rhs)
    return data
}

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

public enum HTTPStatus: Int {
    
    case OK = 200
    case Created = 201
    case Accepted = 202
    
    case MultipleChoices = 300
    case MovedPermanently = 301
    case Found = 302
    case SeeOther = 303
    
    case BadRequest = 400
    case Unauthorized = 401
    case Forbidden = 403
    case NotFound = 404
    
    case InternalServerError = 500
    case BadGateway = 502
    case ServiceUnavailable = 503
    
    func statusLine() -> String {
        switch self {
        case .OK: return "OK"
        case .Created: return "Created"
        case .Accepted: return "Accepted"
            
        case .MultipleChoices: return "Multiple Choices"
        case .MovedPermanently: return "Moved Permentantly"
        case .Found: return "Found"
        case .SeeOther: return "See Other"
            
        case .BadRequest: return "Bad Request"
        case .Unauthorized: return "Unauthorized"
        case .Forbidden: return "Forbidden"
        case .NotFound: return "Not Found"
            
        case .InternalServerError: return "Internal Server Error"
        case .BadGateway: return "Bad Gateway"
        case .ServiceUnavailable: return "Service Unavailable"
        }
    }
}

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

var wsPort = 8080

if Process.arguments.count > 1 {
    wsPort = Int(Process.arguments[1])!
}


typealias ReceivedRequestCallback = ((Request, SwiftSocket) -> Bool)
typealias WebsocketRequestCallback = ((NSData, SwiftSocket) -> Bool)

 enum SocketErrors: ErrorProtocol {
     case ListenError
     case PortUsedError
 }

 protocol SocketServer {

     func startOnPort(p: Int) throws
     func disconnect()

     var receivedRequestCallback: ReceivedRequestCallback? { get set }
 }

func ==(lhs: SwiftSocket, rhs: SwiftSocket) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

protocol Socket: Hashable {
//     func sendData(data: NSData)
    func sendData(close:Bool, data: NSData)
    
 }

// Mark: SwiftSocket Implementation of the Socket and SocketServer protocol


struct SwiftSocket: Socket {
    
    var hashValue: Int {
        get {
            return self.socket.fd.hashValue
        }
    }

    let socket: ActiveSocketIPv4

    func sendData(close:Bool = false, data: NSData) {
        let dispatchData = dispatch_data_create(data.bytes, data.length, dispatch_get_main_queue(), nil)
        socket.write(data: dispatchData)
        if close == true {
            socket.close()
        }
    }
 }

class SwiftSocketServer: SocketServer {

    var socket: PassiveSocketIPv4!

    var receivedRequestCallback: ReceivedRequestCallback?
    var websocketRequestCallBack: WebsocketRequestCallback?

    func startOnPort(p: Int) throws {

        guard let socket = PassiveSocketIPv4(address: sockaddr_in(port: p)) else { throw SocketErrors.ListenError }
        _ = socket.listen(queue: dispatch_get_global_queue(0, 0)) {
            socket in

            _ = socket.onRead {
                newsock, length in

                socket.isNonBlocking = true

                var initialData: NSData?
                var bodyData: NSData?

                let (size, data, _) = newsock.read()

                if size > 0 {
                    initialData = NSData(bytes: data, length: size)
                }
                
                guard initialData != nil else {
                    // We are dealing with disconnection or bad requests
                    connections.remove(SwiftSocket(socket: socket))
                    socket.close()
                    print("Client closed ||| Current Connections: \(connections.count)")
                    return
                }
                
                if let _ = NSString(data: initialData!, encoding: NSUTF8StringEncoding) {
                    print("should be upgrade request")
                } else {
                    _ = self.websocketRequestCallBack?( initialData!, SwiftSocket(socket: socket) )
                    return
                }

                if let initialData = initialData {
                    let request = Request(headerData: initialData)

                    // Initial data may not contain body
                    // Check if request contains a body, and that it hasn't been read yet
                    if  let lengthString = request.headers["Content-Length"],
                        let length = UInt(lengthString) where length > 0 && request.bodyString == nil {

                            let (bSize, bData, _) = newsock.read()

                            if bSize > 0 {
                                bodyData = NSData(bytes: bData, length: bSize)
                                request.parseBodyData(d: bodyData)
                            }
                    }

                    _ = self.receivedRequestCallback?(request, SwiftSocket(socket: socket))
                }
            }
        }

        self.socket = socket
     }

    func disconnect() {
        self.socket.close()
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


//var connections: [SwiftSocket] = []
var connections: Set<SwiftSocket> = Set()

func handleUpgradeRequest(socket: SwiftSocket, request: Request) {
    print("GONNA HANDLE REQUEST")
    if request.isWebSocket == true {
        let resp = request.websocketHandhsakeUpgradeReponse()
        resp.handshakeUpgradeMakeSocketData()
        let respData = resp.bodyData
        socket.sendData(close:false, data: respData)
        print("WE HAVE WEBSOCKET UPGRADE!!!!")
//        connections.append(socket)
        connections.insert(socket)
    } else {
        print("Request is not websocket!!!")
    }
}



let server = SwiftSocketServer()

server.receivedRequestCallback = {
    request, socket in
    handleUpgradeRequest(socket: socket, request: request)
    return true
}

server.websocketRequestCallBack = {
    data, socket in
    
    let count = data.length / sizeof(UInt8)
    var dataArray = [UInt8](repeating:0, count: count)
    // copy bytes into array
    data.getBytes(&dataArray, length:count * sizeof(UInt8))
    
    let fin = dataArray[0] & WebSocketFrame.FinMask != 0
    let rsv1 = dataArray[0] & WebSocketFrame.Rsv1Mask != 0
    let rsv2 = dataArray[0] & WebSocketFrame.Rsv2Mask != 0
    let rsv3 = dataArray[0] & WebSocketFrame.Rsv3Mask != 0
    
    // guard let opCode = WebSocketFrame.OpCode(rawValue: dataArray[0] & WebSocketFrame.OpCodeMask) else { print("WE DO NOT HAVE PROPER FRAME!!!") }
    let opCode = WebSocketFrame.OpCode(rawValue: dataArray[0] & WebSocketFrame.OpCodeMask)
    
    let masked = dataArray[1] & WebSocketFrame.MaskMask != 0
    let payloadLength = dataArray[1] & WebSocketFrame.PayloadLenMask
    
    var headerExtraLength = masked ? sizeof(UInt32) : 0
    if payloadLength == 126 {
        headerExtraLength += sizeof(UInt16)
    } else if payloadLength == 127 {
        headerExtraLength += sizeof(UInt64)
    }
    
    if opCode!.isControl {
        print("**** WE HAVE A CONTROL FRAME!!!!")
    } else {
        print("** WE DO NOT HAVE A CONTROL FRAME!!!!")
    }
    
    switch opCode! {
    case .Text:
        print("*** WE HAVE TEXT FRAME ***")
        var _textFramePayload: [UInt8]
        // guard let maskKey = frame.maskKey else { return -1 }
        let maskOffset = max(Int(headerExtraLength) - 4, 2)
        print("maskOffset: \(maskOffset)")
        let maskKey = Array(dataArray[maskOffset ..< maskOffset+4])
        
        // guard maskKey.count == 4 else { return fail("maskKey wrong length") }
        
        let consumeLength = min(UInt64(payloadLength), UInt64(dataArray.count))
        _textFramePayload = []
        var maskKeyIndex = 0
        var idx = 0
        for byte in dataArray {
            if idx < 6 {
                idx += 1
                continue
            }
            _textFramePayload.append(byte ^ maskKey[maskKeyIndex])
            if (maskKeyIndex + 1) < maskKey.count {
                maskKeyIndex += 1
            } else {
                maskKeyIndex = 0
            }
        }
        
        
        //                let str = String.fromBytes(bytes: _textFramePayload)
        let str = String(bytes: _textFramePayload, encoding: NSUTF8StringEncoding)
        let textFrame = WebSocketFrame(opCode: .Text, data: Array(str!.utf8))
        let frameData = textFrame.getData()
        let textData = NSData(bytes: frameData, length: frameData.count)

        for con in connections {
            con.sendData(close: false, data: textData)
        }
    case .Continuation:
        print("*** WE HAVE Continuation FRAME ***")
    case .Binary:
        print("***WE HAVE Binary FRAME")
    case .Ping:
        print("*** WE HAVE PING FRAME ***")
        socket.sendData(close: false, data: data)
    case .Pong:
        print("*** WE HAVE PONG FRAME ***")
    case .Close:
        print("*** WE HAVE CLOSE FRAME ***")
    }

    
    return true
}

try server.startOnPort(p: wsPort)

print("started server")

while (true){
//  print("started server")
}

