// WebSocketFrame.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//	0                   1                   2                   3
//	0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
//	+-+-+-+-+-------+-+-------------+-------------------------------+
//	|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
//	|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
//	|N|V|V|V|       |S|             |   (if payload len==126/127)   |
//	| |1|2|3|       |K|             |                               |
//	+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
//	|     Extended payload length continued, if payload len == 127  |
//	+ - - - - - - - - - - - - - - - +-------------------------------+
//	|                               |Masking-key, if MASK set to 1  |
//	+-------------------------------+-------------------------------+
//	| Masking-key (continued)       |          Payload Data         |
//	+-------------------------------- - - - - - - - - - - - - - - - +
//	:                     Payload Data continued ...                :
//	+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
//	|                     Payload Data continued ...                |
//	+---------------------------------------------------------------+

internal struct WebSocketFrame {

	internal static let FinMask			: UInt8 = 0b10000000
	internal static let Rsv1Mask		: UInt8 = 0b01000000
	internal static let Rsv2Mask		: UInt8 = 0b00100000
	internal static let Rsv3Mask		: UInt8 = 0b00010000
	internal static let OpCodeMask		: UInt8 = 0b00001111

	internal static let MaskMask		: UInt8 = 0b10000000
	internal static let PayloadLenMask	: UInt8 = 0b01111111

	internal enum OpCode: UInt8 {
		case Continuation	= 0x0
		case Text			= 0x1
		case Binary			= 0x2
		// 0x3 -> 0x7 reserved
		case Close			= 0x8
		case Ping			= 0x9
		case Pong			= 0xA
		// 0xB -> 0xF reserved

		var isControl: Bool {
			return self == .Close || self == .Ping || self == .Pong
		}
	}

	var fin: Bool
	var rsv1: Bool
	var rsv2: Bool
	var rsv3: Bool
	var opCode: OpCode
	var masked: Bool
	var payloadLength: UInt64
	var maskKey: [UInt8]?
	var data: [UInt8] = []

	var payloadRemainingLength: UInt64
	var headerExtraLength: Int
	var maskOffset = 0

	init(fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: OpCode, masked: Bool, payloadLength: UInt64, headerExtraLength: Int) {
		self.fin = fin
		self.rsv1 = rsv1
		self.rsv2 = rsv2
		self.rsv3 = rsv3
		self.opCode = opCode
		self.masked = masked
		self.payloadLength = payloadLength
		self.payloadRemainingLength = payloadLength
		self.headerExtraLength = headerExtraLength
	}

	init(fin: Bool = true, rsv1: Bool = false, rsv2: Bool = false, rsv3: Bool = false, opCode: OpCode, data: [UInt8] = []) {
		self.fin = fin
		self.rsv1 = rsv1
		self.rsv2 = rsv2
		self.rsv3 = rsv3
		self.opCode = opCode
		self.masked = false
		self.data = data
		self.payloadLength = UInt64(data.count)

		self.payloadRemainingLength = 0
		self.headerExtraLength = 0
		self.maskKey = nil
	}

	func getData() -> [UInt8] {
		var data: [UInt8] = []

		data.append(((fin ? 1 : 0) << 7) | ((rsv1 ? 1 : 0) << 6) | ((rsv2 ? 1 : 0) << 5) | ((rsv3 ? 1 : 0) << 4) | opCode.rawValue)

		let payloadLen: UInt8
		if payloadLength > UInt64(UInt16.max) {
			payloadLen = 127
		} else if payloadLength >= 126 {
			payloadLen = 126
		} else {
			payloadLen = UInt8(payloadLength)
		}
		data.append(((masked ? 1 : 0) << 7) | payloadLen)

		if payloadLen == 127 {
			data += payloadLength.bytes()
		} else if payloadLen == 126 {
			data += UInt16(payloadLength).bytes()
		}

		data += self.data

		return data
	}

}