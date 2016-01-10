///////////////////////////////////////////////////////////////////////////////
//  CWSmartBuffer.swift
//  CWEXSockets
//
//  Circular buffer implemntation using mirroring to ensure that it always
//  provides a contiguous chunk of memory
//
//  Created by Colin Wilson on 17/11/2015.
//  Copyright © 2015 Colin Wilson. All rights reserved.
//

import Foundation

public enum CWSmartByteBufferError : ErrorType {
    case noSpace
    case badAddress
}


//==============================================================
// class CWSmartByteBuffer
//==============================================================
public class CWSmartByteBuffer {

    let VM_INHERIT_DEFAULT: vm_inherit_t = 1

    public enum Error: ErrorType {
        case noSpace
        case badAddress
    }

    static let vm_page_size_m1: vm_size_t = vm_page_size - 1
    static let TruncPage = { (x: vm_size_t) -> vm_size_t in x & ~(vm_page_size_m1) }
    static let RoundPage = { (x: vm_size_t) -> vm_size_t in TruncPage(x + vm_page_size_m1) }

    private var bufPtr: vm_address_t = 0
    private var bufSize: UInt

    private var readPointer: vm_address_t = 0
    private var writePointer: vm_address_t = 0

    private var bytesWritten: UInt = 0
    private var bytesRead: UInt = 0

    //--------------------------------------------------------------
    // init
    //--------------------------------------------------------------
    public init (initialSize: UInt) {
        self.bufSize = CWSmartByteBuffer.RoundPage (initialSize)
    }

    //--------------------------------------------------------------
    // deinit
    //--------------------------------------------------------------
    deinit {
        deallocBuffer ()
    }

    //--------------------------------------------------------------
    // availableBytes
    //--------------------------------------------------------------
    public var availableBytes: UInt {
        if bytesWritten >= bytesRead {
            return bytesWritten - bytesRead
        } else {
            return UInt.max - bytesRead + bytesWritten
        }
    }

    //--------------------------------------------------------------
    // freeSpace
    //--------------------------------------------------------------
    public var freeSpace: UInt {
        return bufSize - availableBytes
    }


    //--------------------------------------------------------------
    // reset
    //
    // Empty the buffer - but don't deallocate it
    //--------------------------------------------------------------
    public func reset () {
        readPointer = bufPtr
        writePointer = bufPtr

        bytesWritten = 0
        bytesRead = 0
    }

    //--------------------------------------------------------------
    // deallocBuffer
    //
    // Deallocate and reset the buffer
    //--------------------------------------------------------------
    private func deallocBuffer () {
        if bufPtr != 0 {
            vm_deallocate(mach_task_self_, bufPtr, bufSize)
            bufPtr = 0
            bufSize = 0
        }
        reset ();
    }

    //--------------------------------------------------------------
    // createBuffer
    //
    // nb.  bufSize must have been rounded when this is called
    //--------------------------------------------------------------
    private func createBuffer () throws {

        // Make sure there's space for the buffer and its mirror
        guard vm_allocate(mach_task_self_, &bufPtr, bufSize * 2, VM_FLAGS_ANYWHERE) == 0 else {
            throw Error.noSpace
        }

        // Deallocate the top, 'mirror' half
        var mirror = bufPtr + bufSize
        guard vm_deallocate(mach_task_self_, mirror, bufSize) == 0 else {
            throw Error.badAddress
        }

        do {

            // Now map the mirror half onto the lower, non-mirror half.  We end up with a chunk of address space, twice as large as the buffer.  If you write anywhere in the lower half
            // the data appears in the upper half too - and vice versa.  And if you read from either half the results will be the same.

            var cp: vm_prot_t = 0
            var mp: vm_prot_t = 0
            guard vm_remap(mach_task_self_, &mirror, bufSize, 0, 0, mach_task_self_, bufPtr, 0, &cp, &mp, VM_INHERIT_DEFAULT) == 0 else {
                throw Error.noSpace
            }
        } catch let e {
            vm_deallocate (mach_task_self_, bufPtr, bufSize)
            throw e
        }

        // Set the read & write pointers to the start of the buffer.
        readPointer = bufPtr
        writePointer = bufPtr
    }


    //--------------------------------------------------------------
    // getWritePointer
    //
    // Returns the current write pointer.  AFter you've written data
    // to this pointer, call 'finalizeWrite' to update the pointers.
    //
    // If size is greater than the amonunt of free space in the buffer,
    // the buffer will automatically resize itself - as long as it's
    // empty.  If it's not empty, the function wil return nil.
    //--------------------------------------------------------------
    public func getWritePointer (size: UInt) throws -> UnsafeMutablePointer<UInt8>? {
        if (bufPtr == 0) {
            // First time buffer used - so create it

            bufSize = size > bufSize ? CWSmartByteBuffer.RoundPage (size) : bufSize
            try createBuffer()
        } else if freeSpace < size {
            // The buffer isn't big enoug to return a chunk with the required size

            if availableBytes == 0 {
                // Buffer is currently empty, so can be resized

                deallocBuffer()
                bufSize = CWSmartByteBuffer.RoundPage (size)
                try createBuffer()
            } else {
                return nil
            }
        }

        return unsafeBitCast(writePointer, UnsafeMutablePointer<UInt8>.self)
    }

    //--------------------------------------------------------------
    // getReadPointer
    //
    // Return a pointer that you can read 'availeBytes' of data
    // from.  After you've read the data, call finalizeRead to update
    // the pointers
    //--------------------------------------------------------------
    public func getReadPointer ()->UnsafeMutablePointer<UInt8> {
        return unsafeBitCast(readPointer, UnsafeMutablePointer<UInt8>.self)
    }

    //--------------------------------------------------------------
    // finalizeRead
    //--------------------------------------------------------------
    public func finalizeRead (size: UInt) {
        readPointer += size

        if readPointer - bufPtr >= bufSize {
            readPointer -= bufSize
        }

        bytesRead = bytesRead &+ size  // Note overflow + operator
    }

    //--------------------------------------------------------------
    // finalizeWrite
    //--------------------------------------------------------------
    public func finalizeWrite (size: UInt) {
        writePointer += size

        if writePointer - bufPtr >= bufSize {
            writePointer -= bufSize
        }

        bytesWritten = bytesWritten &+ size
    }
}
