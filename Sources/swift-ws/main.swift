import Foundation

var wsPort = 8080

if Process.arguments.count > 1 {
    wsPort = Int(Process.arguments[1])!
}

let wsServer = WebSocketServer(port: wsPort)

try wsServer.start()

print("started server")

while (true){
//  print("started server")
}

