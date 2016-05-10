var WebSocket = require('faye-websocket'),
    ws        = new WebSocket.Client('ws://127.0.0.1:8080/' + Math.r, [], {headers:    {Origin: 'http://localhost:8080'} } ),
    http        = require('http');

var server = http.createServer();
 
// ws.on('open', function(event) {
//   console.log('open');
//   ws.send('Hello, world!');
//   // console.log("ok something");
//   ws.send("WHAT NOW");
// });

// ws.on('connect', function(event) {
//   console.log('on connect from client');
// });
 
// ws.on('message', function(event) {
//   console.log('message', event.data);
// });
 
// ws.on('close', function(event) {
//   console.log('close', event.code, event.reason);
//   ws = null;
// });

// ws.onerror = function(error) {
//   console.log('[error]', error.message);
// };


ws.onopen = function() {
  console.log('[open]', ws.headers);
  ws.send('mic check');
  ws.ping('Mic check, one, two', function() {
    console.log("GOT PONG!!!!!!");
  });
};

ws.onclose = function(close) {
  console.log('[close]', close.code, close.reason);
};

ws.onerror = function(error) {
  console.log('[error]', error.message);
};

ws.onmessage = function(message) {
  console.log('[message]', message.data);
};



// server.listen(4000);
