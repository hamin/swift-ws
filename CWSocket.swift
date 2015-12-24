//==============================================================//
//  CWSocket.swift                                              //
//  CWSockets                                                   //
//                                                              //
//  Created by Colin Wilson on 08/07/2015.                      //
//  Copyright © 2015 Colin Wilson. All rights reserved.         //
//////////////////////////////////////////////////////////////////

import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

//--------------------------------------------------------------
// GAIError    - Exception wrapper for getaddrinfo errors
//
// Note that the actual integer values in Darwin are different 
// from everyone else's
//--------------------------------------------------------------
@objc enum GAIError: CInt, ErrorType {
    case EAI_AGAIN          // 2
    case EAI_BADFLAGS       // 3
    case EAI_BADHINTS       // 12
    case EAI_FAIL           // 4
    case EAI_FAMILY         // 5
    case EAI_MEMORY         // 6
    case EAI_NONAME         // 8
    case EAI_OVERFLOW       // ?? not documented?
    case EAI_PROTOCOL       // 13
    case EAI_SERVICE        // 9
    case EAI_SOCKTYPE       // 10
    
    var description: String {
        let rv = String.fromCString(gai_strerror(self.rawValue))
        return rv == nil ? String (self.rawValue) : rv!
    }
}


//--------------------------------------------------------------
//  CWSocketFamily.   Tries to make sense of AF/PF inet etc(!)
//--------------------------------------------------------------
public enum CWSocketFamily {
    case v4
    case v6
    
    
    var int32Value: Int32 {
        switch (self) {
        case .v4: return AF_INET
        case .v6: return AF_INET6
        }
    }
    
    var value: sa_family_t {
        return sa_family_t (int32Value)
    }
}


//--------------------------------------------------------------
//  CWSocketProtocol.  Encapsulates socket protocol
//--------------------------------------------------------------
public enum CWSocketProtocol {
    case tcp
    case udp
    
    var type: Int32 {
        switch (self) {
        case .tcp: return SOCK_STREAM
        case .udp: return SOCK_DGRAM
        }
    }
    
    var proto: Int32 {
        switch (self) {
        case .tcp: return IPPROTO_TCP
        case .udp: return IPPROTO_UDP
        }
    }
}


//--------------------------------------------------------------
// POSIXError extension - provides description for POSIX errors
//--------------------------------------------------------------
public extension POSIXError {
    var description: String {
        let rv = String.fromCString(strerror(self.rawValue))
        
        return rv == nil ? String (self.rawValue) : rv!
    }
}



//--------------------------------------------------------------
// CWSocket - Swift wrapper for sockets
//--------------------------------------------------------------
final public class CWSocket {
    
    var _descriptor : Int32 = -1
    private var sa: UnsafeMutablePointer<sockaddr>?

    let family : CWSocketFamily!
    let proto : CWSocketProtocol!
    
   /*---------------------------------------------------------
    | deinit.  Destructor 0 close the socke
    *--------------------------------------------------------*/
    deinit {
        close ();
        print ("Socket deinit")
    }
    
   /*--------------------------------------------------------
    | init {1}
    |
    | Constructor.  Initialise with family & protocol
    *-------------------------------------------------------*/
    public init (family: CWSocketFamily, proto: CWSocketProtocol) {
        self.family = family
        self.proto = proto
        print ("Socket init(1)")
    }
    
   /*---------------------------------------------------------
    | init {2}
    |
    | Constructor.  Initialise from an existing socket 
    | descriptor
    *--------------------------------------------------------*/
    public init (descriptor: Int32, family: CWSocketFamily) throws {
        self._descriptor = descriptor
        self.family = family
        
        var s: Int32 = 0
        var l: socklen_t = socklen_t (sizeofValue(s))
        
        // Get the socket type
        if getsockopt(descriptor, SOL_SOCKET, SO_TYPE, &s, &l) == -1 {
            self.proto = .tcp
            throw POSIXError (rawValue: errno)!
        }
        
        switch s {
        case SOCK_STREAM: self.proto = .tcp
        case SOCK_DGRAM: self.proto = .udp
        default:
            self.proto = .tcp
            throw POSIXError (rawValue: EPROTONOSUPPORT)!
        }
    }
    
   /*---------------------------------------------------------
    | close
    *--------------------------------------------------------*/
    public func close () {
        
        // Close the descriptor
        if _descriptor != -1 {
            Foundation.close(_descriptor)
            _descriptor = -1
        }
        
        // Close the cached sock addr
        if let sa = sa {
            CWSocket.freeSockAddr(sa)
            self.sa = nil
        }
    }
    
    /*---------------------------------------------------------
     | descriptor variabled
     *--------------------------------------------------------*/
    
    public var descriptor: Int32 {
        if _descriptor == -1 {
            // Create a new one if necessary
            _descriptor = socket (family.int32Value, proto.type, proto.proto)
        }
        return _descriptor
    }
    
    public var hasDescriptor: Bool {
        return _descriptor != -1
    }
    
    
    /*---------------------------------------------------------
     | remoteIP.
     *--------------------------------------------------------*/
    func remoteIP () throws ->String {
        if let sa = sa {
            var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
            var servBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue: 0)
            
            let rv = getnameinfo(sa, socklen_t (sa.memory.sa_len), &hostBuffer, socklen_t (NI_MAXHOST), &servBuffer, socklen_t (NI_MAXSERV), NI_NUMERICHOST | NI_NUMERICSERV)
            
            if rv != 0 {
                throw GAIError (rawValue: rv)!
            }
            
            return String.fromCString(hostBuffer)!
        } else {
            throw GAIError (rawValue: EAI_NONAME)!
        }
    }
    
    
   /*---------------------------------------------------------
    | bind.  Bind the socket so that it can listen
    *--------------------------------------------------------*/
    public func bind (port: in_port_t, ipAddress: String?) throws {
        if family == .v6 {
            var v6OnlyOn: Int32 = 1
            
            // By setting IPV6_V6ONLY we allow binding separately to the same port with ipv4 & ipv6
            guard Foundation.setsockopt(descriptor, IPPROTO_IPV6, IPV6_V6ONLY, &v6OnlyOn, socklen_t (sizeofValue(v6OnlyOn))) != -1 else {
                throw POSIXError (rawValue: errno)!
            }
        }
        
        // nb.  The reason we have to do SO_REUSEADDR is that, even when we close the listener's socket, for some strange reason it may
        //      still think the port is in use - so when we create a new socket it may fail when we bind it.
        //
        //      Weirdly, this doesn't happen if you step through with the debugger (!)
        
        var reuseOn: Int32 = 1
        guard Foundation.setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuseOn, socklen_t (sizeofValue(reuseOn))) != -1 else {
            throw POSIXError (rawValue: errno)!
        }

        sa = try createSockAddrIn (port, ipAddress: ipAddress)
        guard Foundation.bind(_descriptor, sa!, socklen_t (sa!.memory.sa_len)) == 0 else {
            CWSocket.freeSockAddr(sa!)
            sa = nil
            throw POSIXError (rawValue: errno)!
        }
    }
    
    /*---------------------------------------------------------
     | listen
     *--------------------------------------------------------*/
    public func listen (backlog: Int32) throws {
        guard Foundation.listen(descriptor, backlog) == 0 else {
            throw POSIXError (rawValue: errno)!
        }
    }
    
    /*---------------------------------------------------------
     | connect.
     *--------------------------------------------------------*/
    public func connect (port: in_port_t, ipAddress: String, nonblocking: Bool) throws {
        sa = try createSockAddrIn (port, ipAddress: ipAddress)
        guard Foundation.connect (descriptor, sa!, socklen_t (sa!.memory.sa_len)) == 0 else {
            CWSocket.freeSockAddr(sa!)
            sa = nil
            let e = errno
            print (e)
            throw POSIXError (rawValue: e)!
        }
        
        if nonblocking {
            guard fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else {
                throw POSIXError (rawValue: errno)!
            }
        }

    }
    
   /*---------------------------------------------------------
    | accept
    *--------------------------------------------------------*/
    public func accept (nonblocking nonblocking: Bool) throws ->CWSocket {
        var sl: socklen_t = socklen_t (SOCK_MAXADDRLEN)
        let addr = CWSocket.createSockAddr (Int (SOCK_MAXADDRLEN))
        
        let clientSocket = Foundation.accept(descriptor, addr, &sl)
        guard clientSocket > 0 else {
            throw POSIXError (rawValue: errno)!
        }
        
        if nonblocking {
            guard fcntl(clientSocket, F_SETFL, O_NONBLOCK) != -1 else {
                throw POSIXError (rawValue: errno)!
            }
        }
        
        let family: CWSocketFamily = addr.memory.sa_family == sa_family_t (AF_INET) ? CWSocketFamily.v4 : CWSocketFamily.v6
        let rv = try CWSocket (descriptor: clientSocket, family: family)
        rv.sa = addr
        return rv
    }
    
   /*---------------------------------------------------------
    | read.
    *--------------------------------------------------------*/
    public func read (buffer: UnsafeMutablePointer<Void>, len: Int) throws ->Int {
        let rv = Foundation.read(descriptor, buffer, len)
        if rv == -1 {
            if errno == EAGAIN {
                return 0
            }
            throw POSIXError (rawValue: errno)!
        }
        return rv
    }
    
    public func write (buffer:UnsafePointer<Void>, len: Int) throws ->Int {
        let rv = Foundation.write (descriptor, buffer, len)
        
        if (rv == -1) {
            if (errno == EWOULDBLOCK) {
                return 0
            }
            throw POSIXError (rawValue: errno)!
        }
        return rv
    }
    
   /*---------------------------------------------------------
    | createSockAddrIn
    *--------------------------------------------------------*/
    private func createSockAddrIn (port: in_port_t, ipAddress: String?) throws ->UnsafeMutablePointer<sockaddr> {
        
        var gaiResult = UnsafeMutablePointer<addrinfo> ()
        
        let portBuffer : [CChar]?
        let p: UnsafePointer<Int8>
        
        // Create a buffer containing a string reprentation of the port
        if port != 0 {
            let ptst = String (port)
            portBuffer = ptst.cStringUsingEncoding(NSASCIIStringEncoding)
            p = UnsafePointer<Int8>(portBuffer!)
        } else {
            p = nil
        }
 
        var rv: Int32
        var hint = addrinfo(
            ai_flags: AI_NUMERICSERV, ai_family: Int32 (family.value), ai_socktype: proto.type, ai_protocol: proto.proto, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        
        // Get the address info.
        if let ipAddress = ipAddress {
            
            // Resolves - so may block for a while
            rv = getaddrinfo(ipAddress, p, &hint, &gaiResult)
        } else {
            hint.ai_flags |= AI_PASSIVE
            rv = getaddrinfo(nil, p, &hint, &gaiResult)
        }
        
        defer {
            freeaddrinfo(gaiResult)
        }
        
        if (rv != 0) {
            throw GAIError (rawValue: rv)!
        }
        
        let l = Int (gaiResult.memory.ai_addr.memory.sa_len)
        let r = CWSocket.createSockAddr(l)
        memcpy (r, gaiResult.memory.ai_addr, l)
        
        
        return r
    }
    
    
   /*---------------------------------------------------------
    | createSockAddr
    *--------------------------------------------------------*/
   private static func createSockAddr (len: Int)->UnsafeMutablePointer<sockaddr> {
        let buffer = UnsafeMutablePointer<Void>.alloc(len)
        let rv = UnsafeMutablePointer<sockaddr>(buffer)
        rv.memory.sa_len = __uint8_t (len)
        return rv
    }
    
   /*---------------------------------------------------------
    | freeSockAddr
    *--------------------------------------------------------*/
    private static func freeSockAddr (addr: UnsafeMutablePointer<sockaddr>) {
        let buffer = UnsafeMutablePointer<Void> (addr)
        buffer.dealloc(Int (addr.memory.sa_len))
    }


}
