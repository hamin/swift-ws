//
//  SwiftSocket.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

import Foundation
import SwiftSockets


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
