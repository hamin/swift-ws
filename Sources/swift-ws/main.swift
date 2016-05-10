import CryptoEssentials
import SHA1
import TwoHundredHelpers

internal extension RequestHeader {
    internal var isWebSocket: Bool {
        if let connection = self.headers["Connection"], upgrade = self.headers["Upgrade"], version = self.headers["Sec-WebSocket-Version"], _ = self.headers["Sec-WebSocket-Key"]
            where connection.lowercased() == "upgrade" && upgrade.lowercased() == "websocket" && version == "13" {
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
        let hashedString = SHA1.calculate("\(acceptKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
//	    let encodedKey = Base64.encodeString(bytes: SHA1.bytes(string: "\(acceptKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        let encodedKey = Base64.encode(hashedString)
	    resp.headers.append( HTTPHeader("Sec-WebSocket-Accept", "\(encodedKey)") )
	    return resp
    }
}

var wsPort = 8080

if Process.arguments.count > 1 {
    wsPort = Int(Process.arguments[1])!
}

let wsServer = WebSocketServer(port:wsPort)
wsServer.startWS()

while (true){
	// print("started server")
}