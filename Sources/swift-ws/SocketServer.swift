//
//  SocketServer.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

import Foundation
import SwiftSockets

enum SocketErrors: ErrorProtocol {
    case ListenError
    case PortUsedError
}

typealias ReceivedRequestCallback = ((Request, SwiftSocket) -> Bool)
typealias WebsocketRequestCallback = ((NSData, SwiftSocket) -> Bool)


protocol SocketServer {
    
    func startOnPort(p: Int) throws
    func disconnect()
    
    var receivedRequestCallback: ReceivedRequestCallback? { get set }
}