import Foundation
import TwoHundredHelpers
import CryptoEssentials
import SHA1

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

// public class WebSocketServer: CWServerDelegate {
//     var socketServer: CWSocketServer?
//     var websocketConnections: [CWServerConnection] = []

//     init(port:Int = 8080) {
//         socketServer = CWSocketServer (port: UInt16(port), socketFamily: CWSocketFamily.v4)
//         socketServer?.delegate = self
//     }

//     public func startWS(){
//         do {
//             try self.socketServer!.start()
//         }
//         catch {
//             print(error)
//         }
//     }

//     // MARK: - CWServerDelegate
//     public func connected(connection: CWServerConnection){
//         print("CONNECTED: \(connection)")
//     }
//     public func disconnected(connection: CWServerConnection){
//         print("DISCONNECTED: \(connection)")
//         // TODO need to remove object, needs CWServerConnection needs to conform to either Equatable/Hashable
//     }
//     public func hasData(connection: CWServerConnection){
//         print("hasData: \(connection)")

//         let data: NSMutableData = NSMutableData()
//         connection.readData(data: data)

//         if let datastring = NSString(data: data, encoding:NSUTF8StringEncoding),
//             let requestHeader = RequestHeader(data:datastring as String){
//             if requestHeader.isWebSocket {
//                 print("requestheaders: \(requestHeader.headers)")

//                 do {
//                     let resp = requestHeader.websocketHandhsakeUpgradeReponse()
//                     let hsSockData = resp.handshakeUpgradeMakeSocketData()
//                     let hsSockString = hsSockData.stringValue()
//                     try connection.write(st: hsSockString!)
//                     websocketConnections.append(connection)
//                 }
//                 catch {
//                     print("Failed to make HandShake")
//                 }
//             }else{
//                 print("Request is not websocket: \(requestHeader)")
//             }
//         } else{
//             let count = data.length / sizeof(UInt8)
//             var dataArray = [UInt8](repeating:0, count: count)
//             // copy bytes into array
//             data.getBytes(&dataArray, length:count * sizeof(UInt8))

//             let fin = dataArray[0] & WebSocketFrame.FinMask != 0
//             let rsv1 = dataArray[0] & WebSocketFrame.Rsv1Mask != 0
//             let rsv2 = dataArray[0] & WebSocketFrame.Rsv2Mask != 0
//             let rsv3 = dataArray[0] & WebSocketFrame.Rsv3Mask != 0

//             // guard let opCode = WebSocketFrame.OpCode(rawValue: dataArray[0] & WebSocketFrame.OpCodeMask) else { print("WE DO NOT HAVE PROPER FRAME!!!") }
//             let opCode = WebSocketFrame.OpCode(rawValue: dataArray[0] & WebSocketFrame.OpCodeMask)

//             let masked = dataArray[1] & WebSocketFrame.MaskMask != 0
//             let payloadLength = dataArray[1] & WebSocketFrame.PayloadLenMask

//             var headerExtraLength = masked ? sizeof(UInt32) : 0
//             if payloadLength == 126 {
//                 headerExtraLength += sizeof(UInt16)
//             } else if payloadLength == 127 {
//                 headerExtraLength += sizeof(UInt64)
//             }

//             if opCode!.isControl {
//                 print("**** WE HAVE A CONTROL FRAME!!!!")
//             } else {
//                 print("** WE DO NOT HAVE A CONTROL FRAME!!!!")
//             }

//             switch opCode! {
//             case .Text:
//                 print("*** WE HAVE TEXT FRAME ***")
//                 var _textFramePayload: [UInt8]
//                 // guard let maskKey = frame.maskKey else { return -1 }
//                 let maskOffset = max(Int(headerExtraLength) - 4, 2)
//                 print("maskOffset: \(maskOffset)")
//                 let maskKey = Array(dataArray[maskOffset ..< maskOffset+4])

//                 // guard maskKey.count == 4 else { return fail("maskKey wrong length") }

//                 let consumeLength = min(UInt64(payloadLength), UInt64(dataArray.count))
//                 _textFramePayload = []
//                 var maskKeyIndex = 0
//                 var idx = 0
//                 for byte in dataArray {
//                     if idx < 6 {
//                         idx += 1
//                         continue
//                     }
//                     _textFramePayload.append(byte ^ maskKey[maskKeyIndex])
//                     if (maskKeyIndex + 1) < maskKey.count {
//                         maskKeyIndex += 1
//                     } else {
//                         maskKeyIndex = 0
//                     }
//                 }


//                 //                let str = String.fromBytes(bytes: _textFramePayload)
//                 let str = String(bytes: _textFramePayload, encoding: NSUTF8StringEncoding)
//                 let textFrame = WebSocketFrame(opCode: .Text, data: Array(str!.utf8))
//                 let frameData = textFrame.getData()
//                 let textData = NSData(bytes: frameData, length: frameData.count)
//                 do {
//                     for con in websocketConnections {
//                         try con.writeData(data: textData)
//                     }
//                 }
//                 catch {
//                     print("Failed to make SEND MESSAGE")
//                 }
//             case .Continuation:
//                 print("*** WE HAVE Continuation FRAME ***")
//             case .Binary:
//                 print("***WE HAVE Binary FRAME")
//             case .Ping:
//                 print("*** WE HAVE PING FRAME ***")

//                 // let count = data.length / sizeof(UInt8)
//                 // var dataArray = [UInt8](count: count, repeatedValue: 0)
//                 // // copy bytes into array
//                 // data.getBytes(&dataArray, length:count * sizeof(UInt8))

//                 // let pongFrame = WebSocketFrame(opCode: .Pong, data: dataArray)
//                 // let frameData = pongFrame.getData()
//                 // let pongData =  NSData(bytes: frameData, length: frameData.count)
//                 do {
//                     try connection.writeData(data: data)
//                     print("Sent Pong Message!")
//                 }
//                 catch {
//                     print("Failed to make SEND PONG")
//                 }
//             case .Pong:
//                 print("*** WE HAVE PONG FRAME ***")
//             case .Close:
//                 print("*** WE HAVE CLOSE FRAME ***")
//             default:
//                 print("*** WE HAVE SOM OTHER FRAME ***")
//             }
//         }
//     }
//     public func stopped(server: CWSocketServer){
//         print("stopped: \(server)")
//     }
// }
