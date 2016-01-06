 //
//  CWSocketClient.swift
//  CWEXSockets
//
//  Created by Colin Wilson on 10/11/2015.
//  Copyright © 2015 Colin Wilson. All rights reserved.
//

import Foundation

public enum CWSocketClientError: ErrorType {
    case CantConnect (posixError: POSIXError)
    case NoDelegateToReceiveData

    var description: String {
        switch self {
        case CantConnect (let posixError): return "Can't connect: errno=" + String (posixError.rawValue)
        case NoDelegateToReceiveData: return "No delegate to receive data"
        }
    }
}


public protocol CWClientDelegate: class {
    func connected (client: CWSocketClient)
    func disconnected (client: CWSocketClient)
    func hasData (client: CWSocketClient)
}


public class CWSocketClient {
    public let port: UInt16
    public let socketFamily: CWSocketFamily
    public let host: String
    public var delegate: CWClientDelegate?
    private var _delegateQueue: dispatch_queue_t?
    var delegateQueue: dispatch_queue_t {
        get {
            if _delegateQueue == nil {
                // _delegateQueue = dispatch_get_main_queue()
                _delegateQueue = dispatch_queue_create("swiftws.client.socketlistener", DISPATCH_QUEUE_CONCURRENT)
            }
            return _delegateQueue!
        }
    }

    var asyncQueue: dispatch_queue_t!


    private (set) public var connection: CWClientConnection!

    public init (host: String, port: UInt16, socketFamily: CWSocketFamily) {
        self.host = host
        self.port = port
        self.socketFamily = socketFamily
    }

    public var connected: Bool {
        get {
            return connection != nil
        }
        set {
            if (newValue) {
                do {
                    try connect()
                } catch {
                    if delegate != nil {
                        dispatchDelegate() {
                            self.delegate!.disconnected(self)
                        }
                    }

                }
            } else {
                disconnect()
            }
        }
    }

    public func connect () throws {
        if connected {
            return;
        }

        let socket = CWSocket (family: socketFamily, proto: CWSocketProtocol.tcp)
        do {
            try socket.connect(port, ipAddress: host, nonblocking: true)
            asyncQueue = dispatch_queue_create("clientAsyncQueue", nil)
            connection = CWClientConnection (client: self, socket: socket)
            try connection.monitor(asyncQueue)

            if delegate != nil {
                dispatchDelegate () {
                    self.delegate!.connected(self)
                }
            }
        }
        catch let e as POSIXError {
            asyncQueue = nil
            throw CWSocketClientError.CantConnect(posixError: e)
        }
    }

    public func disconnect () {
        if !connected {
            return
        }

        dispatch_async(asyncQueue) {
            self.connection.disconnect()
        }
    }

    private func dispatchDelegate (block: dispatch_block_t) {
        if asyncQueue == nil || asyncQueue !== delegateQueue {
            dispatch_async (delegateQueue, block)
        } else {
            block ()
        }
    }

    func hasData () throws {
        guard delegate != nil else {
            throw CWSocketClientError.NoDelegateToReceiveData
        }

        dispatchDelegate() {
            self.delegate!.hasData (self)
        }

    }

    func disconnected () {
        connection = nil
        asyncQueue = nil

        if (delegate != nil) {
            dispatchDelegate() {
                self.delegate!.disconnected (self)
            }
        }
    }

}
