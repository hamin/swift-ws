import CryptoEssentials
import SHA1
import TwoHundredHelpers
import Dispatch

import SwiftSockets
import Foundation


func + (lhs: NSData, rhs: NSData) -> NSData {

    let data = NSMutableData(data: lhs)
    data.append(rhs)
    return data
}

var wsPort = 8080

if Process.arguments.count > 1 {
    wsPort = Int(Process.arguments[1])!
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

