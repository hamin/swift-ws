//
//  CWSocketServer.swift
//  CWSocketsExKit
//
//  Created by Colin Wilson on 17/06/2015.
//  Copyright © 2015 Colin Wilson. All rights reserved.
//

import Foundation

public enum CWSocketServerError: ErrorType {
    case CantStartListener (posixError: POSIXError)
    case CantCreateAcceptSource
    case NoDelegateToReceiveData

    var description: String {
        switch self {
        case CantStartListener (let posixError): return "Can't start listener: errno=" + String (posixError.rawValue)
        case CantCreateAcceptSource: return "Can't create accept source"
        case NoDelegateToReceiveData: return "No delegate to receive data"
        }
    }
}

public protocol CWServerDelegate: class {
    func connected (connection: CWServerConnection)
    func disconnected (connection: CWServerConnection)
    func hasData (connection: CWServerConnection)
    func stopped (server: CWSocketServer)
}


public class CWSocketServer {
    public let port: UInt16
    public let socketFamily: CWSocketFamily

    private var listenerSocket: CWSocket!
    private (set) public var connections : [CWServerConnection] = []
    var acceptSource: dispatch_source_t!
    var asyncQueue: dispatch_queue_t!

    public var delegate: CWServerDelegate?

    private var _delegateQueue: dispatch_queue_t?
    var delegateQueue: dispatch_queue_t {
        get {
            if _delegateQueue == nil {
                // _delegateQueue = dispatch_get_main_queue()
                _delegateQueue = dispatch_queue_create("swiftws.server.serversocketlistener", DISPATCH_QUEUE_CONCURRENT)
            }
            return _delegateQueue!
        }
    }

    public init (port: UInt16, socketFamily: CWSocketFamily, delegateQueue: dispatch_queue_t?) {
        self.port = port;
        self.socketFamily = socketFamily;
        self._delegateQueue = delegateQueue
    }

    public convenience init (port: UInt16, socketFamily: CWSocketFamily) {
        self.init (port: port, socketFamily: socketFamily, delegateQueue: nil)
    }

    deinit {
        stop ()
    }

    public var started: Bool {
        get {
            return listenerSocket != nil
        }
        set {
            if newValue {
                do {
                    try start ();
                }
                catch
                {
                    if delegate != nil {
                        dispatchDelegate() {
                            self.delegate!.stopped(self)
                        }
                    }
                }
            } else {
                stop ();
            }
        }
    }

    public func stop () {

        if !started {
            return
        }

        // nb.  Connections will remove themselves from the connection array when their cancel handler gets dispatched to the (serial) async queue.
        //      Calling 'disconnect' makes this happen.  And because the loop below is called on the async queue too, we can guarantee that
        //      the loop will finish before any connection gets removed.  So it's safe!

        dispatch_async(asyncQueue) {
            for connection in self.connections {
                connection.disconnect ()
            }
        }

        if acceptSource != nil {
            dispatch_source_cancel(acceptSource)
        }
        acceptSource = nil
        asyncQueue = nil
    }

    public func start () throws {
        if started {
            return;
        }

        listenerSocket = CWSocket (family: socketFamily, proto: CWSocketProtocol.tcp)
        do {
            try listenerSocket.bind(port, ipAddress: nil)
            try listenerSocket.listen(3)

            asyncQueue = dispatch_queue_create("serverAsyncQueue", nil)
            acceptSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt (listenerSocket.descriptor), 0, asyncQueue)
            guard acceptSource != nil else {
                throw CWSocketServerError.CantCreateAcceptSource
            }

            dispatch_source_set_event_handler(acceptSource, asyncAcceptPendingConnections)
            dispatch_source_set_cancel_handler(acceptSource, asyncCancelAccept)

            dispatch_resume(acceptSource)

        }
        catch let e as POSIXError {
            listenerSocket = nil
            asyncQueue = nil
            throw CWSocketServerError.CantStartListener(posixError: e)
        }
    }

    func removeConnection (connection: CWServerConnection) {
        var idx = -1

        for var i = 0; i < connections.count; i++ {
            if connection === connections [i] {
                idx = i;
                break
            }
        }

        if idx >= 0 {
            connections.removeAtIndex(idx)
        }

        if delegate != nil {
            dispatchDelegate() {
                self.delegate!.disconnected(connection)
            }
        }
    }

    func hasDataOnConnection (connection: CWServerConnection) throws {
        guard delegate != nil else {
            throw CWSocketServerError.NoDelegateToReceiveData
        }

        dispatchDelegate() {
            self.delegate!.hasData (connection)
        }

    }


    private func asyncAcceptPendingConnections() {
        let numPendingConnections = dispatch_source_get_data(acceptSource);
        for var i = 0; i < Int (numPendingConnections); i++ {

            do {
                let clientSocket = try listenerSocket.accept (nonblocking:true)
                let connection = CWServerConnection (server: self, socket: clientSocket)
                connections.append(connection)
                try connection.monitor (asyncQueue)
                if delegate != nil {
                    dispatchDelegate() {
                        self.delegate!.connected(connection)
                    }
                }
            }
            catch let e as POSIXError {
                print ("Error in accept:" + String(e.rawValue) + ":" + e.description)
            }
            catch let e as CWConnectionError {
                print ("Error in connection:" + e.description)
            }
            catch {
                print ("Unknown error in accept")
            }
        }
    }

    private func asyncCancelAccept () {
        listenerSocket = nil

        if delegate != nil {
            dispatchDelegate() {
                self.delegate!.stopped (self)
            }
        }
    }

    private func dispatchDelegate (block: dispatch_block_t) {
        if asyncQueue == nil || asyncQueue !== delegateQueue {
            dispatch_async (delegateQueue, block)
        } else {
            block ()
        }
    }
 }