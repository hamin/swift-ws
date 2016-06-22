// Reference
// http://tools.ietf.org/html/rfc6455
// http://www.w3.org/TR/2011/WD-websockets-20110929/
// https://github.com/einaros/ws
// https://github.com/Worlize/WebSocket-Node
// http://ja.wikipedia.org/wiki/WebSocket
// http://www.slideshare.net/You_Kinjoh/javascript-websocket P.68
// http://d.hatena.ne.jp/gtk2k/20120203/1328274962

var log = console.log.bind(console);

var http = require('http'),
    assert = require('assert');

var host = 'localhost'
  , http_port = process.argv[2] || 3000
  ;

var clientScript = function () {
  var ws = new WebSocket("ws://localhost:8080/", ["test", "chat"]);
  // var ws = new WebSocket("ws://localhost:3000/", "test");
  ws.onopen = function() {
    console.log(ws);
    ws.send("test");
    ws.onmessage = function(message) {
      console.log(message.data);
    };
  }
}

var server = http.createServer(function(req, res) {
  res.writeHead(200, {'Content-Type': 'text/html'});
  var html = '<html><head><title>wsserver</title>' +
  '<script type="text/javascript">' +
    '(' + clientScript + ')();' +
  '</script>' +
  '</head>' +
  '<body>hello world</body>' +
  '<html>';
  res.end(html);
});

server.on('upgrade', function(req, socket, head) {
  /**
   * 1.2. Protocol Overview
   * http://tools.ietf.org/html/rfc6455#section-1.2
   *
   * GET /chat HTTP/1.1
   * Host: server.example.com
   * Upgrade: websocket
   * Connection: Upgrade
   * Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
   * Origin: http://example.com
   * Sec-WebSocket-Protocol: chat, superchat
   * Sec-WebSocket-Version: 13
   *
   * actual [new WebSocket('ws://localhost:3000/', 'test');]
   * { host: 'localhost:3000',
   * upgrade: 'websocket',
   * connection: 'Upgrade',
   * origin: 'http://localhost:3000',
   * 'sec-websocket-protocol': 'test, chat',
   * 'sec-websocket-extensions': 'x-webkit-deflate-frame',
   * 'sec-websocket-key': 'NblXHeIwGDpoQ2GFAGzwzw==',
   * 'sec-websocket-version': '13' }
   */


  if (req.headers['sec-websocket-key1'] && req.headers['sec-websocket-key2']) {
    assert.fail('Old Header hybi-00(hixi-76) to hybi-03');
  }

  var version = parseInt(req.headers['sec-websocket-version']);
  // 13 is hibi-13 to 17 & RFC
  if (version !== 13) {
    var v;
    switch (version) {
    case 4:
      v = '04';
      break;
    case 5:
      v = '05';
      break;
    case 6:
      v = '06';
      break;
    case 7:
      v = '07';
      break;
    case 8:
      v = '08-12';
      break;
    default:
      v = 'unknown';
    }
    assert.fail('Old version hibi-' + v);
  }


  if (req.headers['sec-websocket-origin']) {
    assert.fail('Old Header');
  }

  // Subprotocol selector
  // this case, use first one
  var protocol = req.headers['sec-websocket-protocol'].split(',')[0];

  // list of extensions support by the client
  // this used to indecate application-level protocol
  // server selects one or none of acceptable protocol
  // echoes that value in its handshake.
  var extensions = req.headers['sec-websocket-extensions'];

  // use for reject browser if not acceptable
  // you can reject by sending appropriate HTTP error code
  var origin = req.headers['origin'];

  // to prove the client that handshake was recieved,
  // use the sec-websocket-key to prevent an attacker
  // from sending crafted XHR or Form packet.
  var key = req.headers['sec-websocket-key'];

  // take sec-websocket-key without any trailing whitespace
  // concatnate this with Globally Unique Identifier
  // "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"(GUID, [RFC4122])
  // A Sha1 hash(160 bits), base64 encoded of this is for returning.
  // this would be echoed in the |Sec-WebSocket-Accept| header field.
  //
  // test case
  // sec-websocket-key="dGhlIHNhbXBsZSBub25jZQ=="
  // cat="dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  // sha1="0xb3 0x7a 0x4f 0x2c 0xc0 0x62 0x4f 0x16 0x90 0xf6 0x46 0x06 0xcf 0x38 0x59 0x45 0xb2 0xbe 0xc4 0xea"
  // base64="s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
  key = require('crypto')
         .createHash('sha1')
         .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
         .digest('base64');

  var headers = [
     // The first line is an HTTP Status-Line
     // code 101, Switching Protocols
     'HTTP/1.1 101 Switching Protocols'
     // Upgrade, Connection fields complete the Upgrade
   , 'Upgrade: websocket'
   , 'Connection: Upgrade'
     // Accept will checked by client which is expected
   , 'Sec-WebSocket-Accept: ' + key
     // option fields can be included
     // main is subprotocol that indicates server has selected
   , 'Sec-WebSocket-Protocol: ' + protocol
  ].concat('', '').join('\r\n');

  socket.write(headers);

  log('\n======== Request Header =========');
  log(req.headers);

  log('\n======== Response Header =========');
  log(headers);

  socket.on('data', function(receivedData) {
    /**
     * 5, Data Framing
     * http://tools.ietf.org/html/rfc6455#section-5.2
     * Client must masks all frames because of
     * intermediaries(e.g proxy) and security reason.
     * Server must not mask all frames
     */

    var firstByte = receivedData[0];
    /**
     * fin
     * axxx xxxx first byte
     * 1000 0000 mask with 0x80 >>> 7
     * ---------
     * 1         is final frame
     * 0         is continue after this frame
     */
    var fin = (firstByte & 0x80) >>> 7;

    /**
     * opcode
     * xxxx aaaa first byte
     * 0000 1111 mask with 0x0f
     * ---------
     * 0000 0001 is text frame
     */
    var opcode = firstByte & 0x0f;
    var payloadType;
    switch (opcode) {
    case 0x0:
      payloadType = 'continuation';
      break;
    case 0x1:
      payloadType = 'text';
      break;
    case 0x2:
      payloadType = 'binary';
      break;
    case 0x8:
      payloadType = 'connection close';
      break;
    case 0x9:
      payloadType = 'ping';
      break;
    case 0xA:
      payloadType = 'pong';
      break;
    default:
      payloadType = 'reserved for non-control';
    }
    if (payloadType !== 'text') {
       assert.fail('this script dosen\'t supports without text');
    }

    var secondByte = receivedData[1];

    /**
     * mask
     * axxx xxxx second byte
     * 1000 0000 mask with 0x80
     * ---------
     * 1000 0000 is masked
     * 0000 0000 is not masked
     */
    var mask = (secondByte & 0x80) >>> 7;
    if (mask === 0) {
      assert.fail('browse should always mask the payload data');
    }

    /**
     * Payload Length
     * xaaa aaaa second byte
     * 0111 1111 mask with 0x7f
     * ---------
     * 0000 0100 4(4)
     * 0111 1110 126(next UInt16)
     * 0111 1111 127(next UInt64)
     */
    var payloadLength = (secondByte & 0x7f);
    if (payloadLength === 0x7e) {
      assert.fail('next 16bit is length but not supported');
    }
    if (payloadLength === 0x7f) {
      assert.fail('next 64bit is length but not supported');
    }

    /**
     * masking key
     * 3rd to 6th byte
     * (total 32bit)
     */
    var maskingKey = receivedData.readUInt32BE(2);

    /**
     * Payload Data = Extention Data + Application Data
     */

    /**
     * extention data
     * 0 byte unless negotiated during handshake
     */
    var extentionData = null;

    /**
     * application data
     * remainder of frame after extention data.
     * length of this is payload length minus
     * extention data.
     */
    var applicationData = receivedData.readUInt32BE(6);

    /**
     * unmask the data
     * application data XOR mask
     */
    var unmasked = applicationData ^ maskingKey;

    /**
     * write to temp buffer and
     * encoding to utf8
     */
    var unmaskedBuf = new Buffer(4);
    unmaskedBuf.writeInt32BE(unmasked, 0);

    var encoded = unmaskedBuf.toString();

    log('======== Parsed Data ===============');
    log('fin:', fin);
    log('opcode:', payloadType);
    log('mask:', mask);
    log('payloadLength:', payloadLength);
    log('maskingkey:', maskingKey);
    log('applicationData:', applicationData);
    log('unmasked', unmasked);
    log('encoded data:', encoded);
    console.log('\n======== Recieved Frame ===============');
    display(receivedData);


    /**
     * Sending data to client
     * data must not mask
     */
    var sendData = new Buffer(6);

    // FIN:1, opcode:1
    // 0x81 = 10000001
    sendData[0] = 0x81;
    // MASK:0, len:4
    // 0x4 = 100
    sendData[1] = 0x4;

    // payload data
    // send data "test"
    sendData[2] = 'test'.charCodeAt(0);
    sendData[3] = 'test'.charCodeAt(1);
    sendData[4] = 'test'.charCodeAt(2);
    sendData[5] = 'test'.charCodeAt(3);

    console.log('\n======== Sending Frame ===============');
    display(sendData);

    // send to client
    socket.end(sendData);

  });
});

server.listen(http_port);


console.log('Server running at', host, http_port);

function display(buffer) {
  // display data frame
  function zeropadding(str, len) {
    while (str.length < len) {
      str = '0' + str;
    }
    return str;
  }
  var temp = [];
  for (var i = 0; i < buffer.length; i++) {
    var d = buffer[i];
    var hex = d.toString(2);
    hex = zeropadding(hex, 8);
    temp.push(hex);
  }

  for (var j = 0; j < temp.length; j += 4) {
    log(temp[j], temp[j + 1], temp[j + 2], temp[j + 3]);
  }
}
