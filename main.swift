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
    		print("NO DATA STRING FROM TCP: \(data)")
	        let frame = WebSocketFrame(opCode: .Text, data: Array("ALT WS: WILL THIS WORK!!!".utf8) )
	        let frameData = frame.getData()

	        let data = NSData(bytes: frameData, length: frameData.count)

            do {
				// try connection.writeData(data)
                for con in websocketConnections {
                    try con.writeData(data)
                }
			}
			catch {
				print("Failed to make SEND MESSAGE")
			}
    	}
    }
    public func stopped(server: CWSocketServer){
    	print("stopped: \(server)")
    }
}

let wsServer = WebSocketServer()
wsServer.startWS()



while (true){
	// print("started server")
}