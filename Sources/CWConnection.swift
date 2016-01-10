//==============================================================//
//  CWEXConnection.swift                                        //
//  CWEXSockets                                                 //
//                                                              //
//  Created by Colin Wilson on 09/07/2015.                      //
//  Copyright © 2015 Colin Wilson. All rights reserved.         //
//////////////////////////////////////////////////////////////////

import Foundation

//--------------------------------------------------------------
// CWConnectionError
//--------------------------------------------------------------
public enum CWConnectionError: ErrorType {
    case CantCreateDispatchSource
    case CantEncodeStringToUTF8
    case BufferTooSmall

    var description: String {
        switch self {
        case CantCreateDispatchSource: return "Can't create dispatch source"
        case CantEncodeStringToUTF8: return "Can't encode string to UTF8"
        case BufferTooSmall: return "Buffer too small"
        }
    }
}

let READ_CHUNK_SIZE: UInt = 1024*1024
let WRITE_CHUNK_SIZE: UInt  = 1024*1024

//--------------------------------------------------------------
// CWConnection
//--------------------------------------------------------------
public class CWConnection {
    private let socket: CWSocket
    public var sessionInfo: AnyObject?

    private var readSource: dispatch_source_t!
    private var writeSource: dispatch_source_t!
    private var writeSourceIsRunning = false

    private var socketRefCount = 0
    private let readBuffer = CWSmartByteBuffer(initialSize: 1024*1024)
    private let writeBuffer = CWSmartByteBuffer(initialSize: 1024*1024)
    private (set) public var totalBytesReceived = 0
    private var asyncQueue: dispatch_queue_t!

    // Semaphore holds 'doRead' if there's no room in the buffer to read into.
    // It gets released by 'ReadData' when the consuer thread frees up space in th
    // buffer.

    private lazy var semaphore = dispatch_semaphore_create (0)
    private var semWaitFor: UInt = 0


    //--------------------------------------------------------------
    // init
    //--------------------------------------------------------------
    init (socket: CWSocket) {
        self.socket = socket
        print ("Connection init")
    }

    //--------------------------------------------------------------
    // deinit
    //--------------------------------------------------------------
    deinit {
        print ("Connection deinit")

    }

    //--------------------------------------------------------------
    // remoteIP
    //--------------------------------------------------------------
    public func remoteIP ()->String {
        do {
            return try socket.remoteIP ()
        }
        catch {
            return "?"
        }
    }

    //--------------------------------------------------------------
    // running
    //--------------------------------------------------------------
    public var running: Bool {
        return socket.hasDescriptor
    }

    //--------------------------------------------------------------
    // doRead
    //
    // Called by the dispatch source on the async queue when there's
    // data available to read
    //--------------------------------------------------------------
    private func doRead () {
        let bytesAvailable = dispatch_source_get_data(readSource)

        if bytesAvailable == 0 {
            disconnect()
            return
        }

        do {
            repeat {
                // Read data into the read bufer until there's no more data
                // available.

                var space = READ_CHUNK_SIZE
                var buf = try readBuffer.getWritePointer (READ_CHUNK_SIZE)

                if buf == nil {
                    semWaitFor = READ_CHUNK_SIZE
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                    space = readBuffer.freeSpace
                    if space > READ_CHUNK_SIZE {
                        space = READ_CHUNK_SIZE
                    }
                    buf = try readBuffer.getWritePointer(space)

                    if buf == nil {
                        break
                    }
                }

                let bytesRead = try socket.read (buf!, len:Int (space))
                print ("Read ", bytesRead, " bytes")

                if bytesRead == 0 {
                    break
                }

                readBuffer.finalizeWrite(UInt (bytesRead))
                totalBytesReceived += bytesRead
                try hasData ()

            } while true

        }
        catch {
            disconnect()
        }
    }

    //--------------------------------------------------------------
    // doWrite
    //
    // Called by the dispatch source on the async queue when we can
    // write data.  Because we can usually write data, it typically
    // gets called repeatedly.  So we suspend the dispatch source when
    // we've written everything to prevent htis
    //--------------------------------------------------------------
    private func doWrite () {
        var l = writeBuffer.availableBytes

        var finished = l == 0

        var p = writeBuffer.getReadPointer()

        do {
            while !finished {
                var bytesToWrite = l
                if bytesToWrite > WRITE_CHUNK_SIZE {
                    bytesToWrite = WRITE_CHUNK_SIZE
                }

                let written = try socket.write(p, len: Int (bytesToWrite))
                print ("Written ", written, " bytes")

                if (written == 0) {
                    break
                }
                p += written
                writeBuffer.finalizeRead(UInt (written))
                l -= UInt (written)
                finished = l == 0

            }

            if finished {
                suspendWriteSource ()
            }


        } catch {
            disconnect()
        }

    }


    //--------------------------------------------------------------
    // hasData
    //
    // Overridden by the CWServerConnection/CWClientConnection to
    // process the data received
    //--------------------------------------------------------------
    private func hasData () throws {

    }

    //--------------------------------------------------------------
    // disconnect
    //
    // Called when we encounter errors to close the connection, but
    // also by CWServerConnection/CWClientConnection when they want
    // to disconnect
    //--------------------------------------------------------------
    internal func disconnect () {

        // nb. must be called on the async queue

        if semWaitFor > 0 {
            semWaitFor = 0
            dispatch_semaphore_signal(semaphore)
        }

        dispatch_source_cancel (readSource);
        dispatch_source_cancel (writeSource);

        resumeWriteSource()


     }

    //--------------------------------------------------------------
    // doReadCancel
    //
    // Called by the dispatch source on the Async queue when the
    // dispatch source is cancelled.  Close the socket
    //--------------------------------------------------------------
    private func doReadCancel () {
        if --socketRefCount <= 0 {
            closeSocket ()
        }
    }

    //--------------------------------------------------------------
    // doWriteCancel
    //
    // Called by the dispatch source on the Async queue when the
    // dispatch source is cancelled.  Close the socket
    //--------------------------------------------------------------
    private func doWriteCancel () {
        if --socketRefCount <= 0 {
            closeSocket ()
        }
    }


    //--------------------------------------------------------------
    // resumeWriteSource
    //
    // nb.  must be called on the Async thread so we don't get
    // two threads trying to suspend/resume at the same time
    //--------------------------------------------------------------
    private func resumeWriteSource () {
        if (!writeSourceIsRunning) {
            writeSourceIsRunning = true;
            dispatch_resume(writeSource)
        }
    }

    //--------------------------------------------------------------
    // suspendWriteSource
    //
    // nb.  must be called on the Async thread so we don't get
    // two threads trying to suspend/resume at the same time
    //--------------------------------------------------------------
    private func suspendWriteSource () {
        if (writeSourceIsRunning) {
            writeSourceIsRunning = false
            dispatch_suspend (writeSource)
        }
    }

    //--------------------------------------------------------------
    // closeSocket
    //
    // nb.  This is overriden by CWServerConnection/CWClientConnection
    // to do additional stuff when th connection is closed
    //--------------------------------------------------------------
    private func closeSocket () {
        socket.close()
    }


    //--------------------------------------------------------------
    // monitor
    //
    // Main function. Start monitoring the socket asynchronously
    //--------------------------------------------------------------
    func monitor (queue: dispatch_queue_t) throws {
        asyncQueue = queue
        readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt (socket.descriptor), 0, queue);
        if readSource == nil {
            throw CWConnectionError.CantCreateDispatchSource
        }
        socketRefCount += 1

        // nb.  The retain cycles here seem to be correct - the connection gets deinited correctly

        dispatch_source_set_event_handler(readSource) {
            self.doRead ()
        }

        dispatch_source_set_cancel_handler(readSource) {
            self.doReadCancel()
        }

        writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, UInt (socket.descriptor), 0, queue);
        if writeSource == nil {
            // See man page.  Cancelling the read source before it's being resumed must be done like this...
            dispatch_source_cancel(readSource)
            dispatch_resume (readSource)
            throw CWConnectionError.CantCreateDispatchSource
        }
        socketRefCount += 1

        dispatch_source_set_event_handler(writeSource) {
            self.doWrite ()
        }

        dispatch_source_set_cancel_handler(writeSource) {
            self.doWriteCancel ()
        }


        // don't resume the write source unless we've got data to write

        if (writeBuffer.availableBytes > 0) {
            resumeWriteSource()
        }
        dispatch_resume(readSource)

    }

    public func hasAvailableData () ->Bool {
        return readBuffer.availableBytes > 0
    }


    //--------------------------------------------------------------
    // readData
    //
    // public function to read the data.  This typically gets called
    // the application when the connection has had it's 'hasData'
    // function clled by its read event hander
    //--------------------------------------------------------------
    public func readData (data: NSMutableData) {
        let len = readBuffer.availableBytes
        print ("Read data ", len)

        if len > 0 {
            let p = readBuffer.getReadPointer()
            data.appendBytes(p, length: Int (len))
            readBuffer.finalizeRead(len)
            let dl = readBuffer.freeSpace
            if semWaitFor > 0 && dl >= semWaitFor {
                semWaitFor = 0
                dispatch_semaphore_signal(semaphore)
            }
        }
        else {
            print ("huh?")
        }
    }

    //--------------------------------------------------------------
    // writeData
    //
    // public function to write some data.
    //--------------------------------------------------------------
    public func writeData (data: NSData) throws {

        // Stuff the data in the write buffer
        let l = UInt (data.length)
        guard let p = try writeBuffer.getWritePointer(l) else {
            throw CWConnectionError.BufferTooSmall
        }

        memcpy (p, data.bytes, Int (l))
        writeBuffer.finalizeWrite (l)

        // Resume the write source so that the data gets written
        if asyncQueue != nil {
            dispatch_async(asyncQueue) {
                self.resumeWriteSource ();
            }
        }
    }

    //--------------------------------------------------------------
    // write
    //
    // Handy function to write a string
    //--------------------------------------------------------------
    public func write (st: String) throws {
        if let data = st.dataUsingEncoding(NSUTF8StringEncoding) {
            try writeData (data)
        } else {
            throw CWConnectionError.CantEncodeStringToUTF8
        }
    }
}

//--------------------------------------------------------------
// CWServerConnection
//--------------------------------------------------------------

final public class CWServerConnection: CWConnection {

    public let server: CWSocketServer

    //--------------------------------------------------------------
    // init
    //--------------------------------------------------------------
    init (server: CWSocketServer, socket: CWSocket) {
        self.server = server
        super.init(socket: socket)
    }

    //--------------------------------------------------------------
    // closeSocket
    //--------------------------------------------------------------
    override private func closeSocket () {
        super.closeSocket()

        // Remove ourself from the server's list of connections
        server.removeConnection(self)
    }

    //--------------------------------------------------------------
    // hasData
    //--------------------------------------------------------------
    override private func hasData() throws {
        try server.hasDataOnConnection (self);
    }
}

//--------------------------------------------------------------
// CWClientConnection
//--------------------------------------------------------------
final public class CWClientConnection: CWConnection {
    public let client: CWSocketClient

    //--------------------------------------------------------------
    // init
    //--------------------------------------------------------------
    init (client: CWSocketClient, socket: CWSocket) {
        self.client = client
        super.init(socket: socket)
    }

    //--------------------------------------------------------------
    // closeSocket
    //--------------------------------------------------------------
    override private func closeSocket () {
        super.closeSocket()
        client.disconnected()
    }

    //--------------------------------------------------------------
    // hasData
    //--------------------------------------------------------------
    override private func hasData() throws {
        try client.hasData ();
    }
}