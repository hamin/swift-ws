import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

internal extension RequestHeader {
    internal var isWebSocket: Bool {
        if let connection = self.headers["Connection"], upgrade = self.headers["Upgrade"], version = self.headers["Sec-WebSocket-Version"], _ = self.headers["Sec-WebSocket-Key"]
            where connection.lowercaseString == "upgrade" && upgrade.lowercaseString == "websocket" && version == "13" {
                return true
        } else {
            return false
        }
    }

    internal func websocketHandhsakeUpgradeReponse() -> HTTPResponse {
    	let resp = HTTPResponse(.Ok)
	    resp.headers.append( HTTPHeader("Upgrade", "websocket") )
	    resp.headers.append( HTTPHeader("Connection", "Upgrade") )

	    let acceptKey = self.headers["Sec-WebSocket-Key"]!
	    let encodedKey = Base64.encodeString(bytes: SHA1.bytes("\(acceptKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	    resp.headers.append( HTTPHeader("Sec-WebSocket-Accept", "\(encodedKey)") )
	    return resp
    }
}

public class WebSocketServer: CWServerDelegate {
	var socketServer: CWSocketServer?
    var websocketConnections: [CWServerConnection] = []

    init(port:Int = 8080) {
        socketServer = CWSocketServer (port: UInt16(port), socketFamily: CWSocketFamily.v4)
        socketServer?.delegate = self
    }

    public func startWS(){
    	do {
			try self.socketServer!.start()
			}
		catch {
			print(error)
		}
    }

    // MARK: - CWServerDelegate
    public func connected(connection: CWServerConnection){
    	print("CONNECTED: \(connection)")
    }
    public func disconnected(connection: CWServerConnection){
    	print("DISCONNECTED: \(connection)")
        // TODO need to remove object, needs CWServerConnection needs to conform to either Equatable/Hashable
    }
    public func hasData(connection: CWServerConnection){
    	print("hasData: \(connection)")

    	let data: NSMutableData = NSMutableData()
    	connection.readData(data)

    	if let datastring = NSString(data: data, encoding:NSUTF8StringEncoding),
    	   	let requestHeader = RequestHeader(data:datastring as String){
    	   	if requestHeader.isWebSocket {
    			print("requestheaders: \(requestHeader.headers)")

    			do {
	    			let resp = requestHeader.websocketHandhsakeUpgradeReponse()
					let hsSockData = resp.handshakeUpgradeMakeSocketData()
					let hsSockString = hsSockData.stringValue()
    				try connection.write(hsSockString!)
                    websocketConnections.append(connection)
    			}
    			catch {
    				print("Failed to make HandShake")
    			}
    		}else{
    			print("Request is not websocket: \(requestHeader)")
    		}
    	} else{
            let count = data.length / sizeof(UInt8)
            var dataArray = [UInt8](count: count, repeatedValue: 0)
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


                let str = String.fromBytes(_textFramePayload)
                let textFrame = WebSocketFrame(opCode: .Text, data: Array(str.utf8))
                let frameData = textFrame.getData()
                let textData = NSData(bytes: frameData, length: frameData.count)
                do {
                    for con in websocketConnections {
                        try con.writeData(textData)
                    }
                }
                catch {
                    print("Failed to make SEND MESSAGE")
                }
            case .Continuation:
                print("*** WE HAVE Continuation FRAME ***")
            case .Binary:
                print("***WE HAVE Binary FRAME")
            case .Ping:
                print("*** WE HAVE PING FRAME ***")
            case .Pong:
                print("*** WE HAVE PONG FRAME ***")
            case .Close:
                print("*** WE HAVE CLOSE FRAME ***")
            default:
                print("*** WE HAVE SOM OTHER FRAME ***")
            }
    	}
    }
    public func stopped(server: CWSocketServer){
    	print("stopped: \(server)")
    }

    // private func sendFrame(data: NSData, opcode: WebSocketFrame.OpCode) -> NSMutableData {
    //     print("************************** COME HERE *********************************")
    //     var headerBytes = [UInt8](count: 2, repeatedValue: 0)
    //     headerBytes[0] |= WebSocketFrame.FinMask
    //     headerBytes[0] |= (WebSocketFrame.OpCodeMask & opcode.rawValue)

    //     if data.length < 126 {
    //         headerBytes[1] |= UInt8(data.length)
    //     } else if UInt(data.length) <= UInt(UInt16.max) {
    //         headerBytes[1] |= UInt8(126)
    //         var length = UInt16(bigEndian: UnsafePointer<UInt16>(data.bytes)[0])
    //         let nsData = NSData(bytes: &length, length: sizeof(UInt16))
    //         var bytes = [UInt8](count: sizeof(UInt16), repeatedValue: 0)
    //         nsData.getBytes(&bytes, length: bytes.count)
    //         headerBytes.appendContentsOf(bytes)
    //     } else {
    //         headerBytes[1] |= UInt8(127)
    //         var length = UInt64(bigEndian: UnsafePointer<UInt64>(data.bytes)[0])
    //         let nsData = NSData(bytes: &length, length: sizeof(UInt64))
    //         var bytes = [UInt8](count: sizeof(UInt64), repeatedValue: 0)
    //         nsData.getBytes(&bytes, length: bytes.count)
    //         headerBytes.appendContentsOf(bytes)
    //     }

    //     headerBytes[1] |= WebSocketFrame.MaskMask
    //     var maskKey = [UInt8](count: 4, repeatedValue: 0)
    //     // SecRandomCopyBytes(kSecRandomDefault, UInt(maskKey.count), &maskKey)
    //     headerBytes.appendContentsOf(maskKey)

    //     var payloadBytes = [UInt8](count: data.length, repeatedValue: 0)
    //     data.getBytes(&payloadBytes, length: payloadBytes.count)

    //     var realBytes = [UInt8](count: 9, repeatedValue: 0)
    //     var i = 0
    //     for index in 6..<payloadBytes.count {
    //         realBytes[i] = payloadBytes[index] ^ maskKey[index % 4]
    //         print("did \(i)")
    //         i += 1
    //     }
    //     // write(NSData(bytes: &headerBytes, length: headerBytes.count))
    //     // write(NSData(bytes: &payloadBytes, length: payloadBytes.count))
    //     let frameData: NSMutableData = NSMutableData()
    //     frameData.appendBytes(&headerBytes, length: headerBytes.count)
    //     // frameData.appendBytes(&payloadBytes, length: payloadBytes.count)
    //     frameData.appendBytes(&realBytes, length: realBytes.count)

    //     // if let str = NSString(bytes: payloadBytes, length: payloadBytes.count, encoding: NSUTF8StringEncoding) as? String {
    //     //     print("THIS IS STRING: \(str)")
    //     // } else {
    //     //     print("not a valid UTF-8 sequence")
    //     // }
    //     // var str = String(bytes: payloadBytes, encoding: NSUTF8StringEncoding)
    //     print(" *** payloadBytes: \(payloadBytes)")
    //     print(" *** realBytes: \(realBytes)")
    //     // print("**** OK THIS IS STRING: \(str) *****")
    //     return frameData
    // }
}

let wsServer = WebSocketServer()
wsServer.startWS()



while (true){
	// print("started server")
}