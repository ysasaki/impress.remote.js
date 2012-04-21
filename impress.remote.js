/**
 * impress.remote.js
 *
 * MIT Licensed.
 *
 * Copyright 2012 Yoshihiro Sasaki (@aloelight)
 */
var util = require('util')
    , express = require('express')
    , WebSocketServer = require('ws').Server;

function Remote(options, callback) {
    var server = express.createServer();
    server.configure(function(){
        server.use(express.static(__dirname));
    });
    WebSocketServer.call(this, {server:server}, callback);
    var self = this;
    this.on('connection', function(ws) {
        console.log('Client connected');
        ws.on('message', function(message) {
            console.log('received: %s', message);
            self.broadcast(ws, message);
        });
        ws.send('Connected to impress.remote.js');
    });
    server.listen(options.port, options.host);
    return this;
};
util.inherits(Remote, WebSocketServer);

Remote.prototype.broadcast = function(sender, message) {
    var len = this.clients.length;
    for ( var i = 0; i<len; i++ ) {
        var c = this.clients[i];
        if ( c === sender ) {
            c.send('broadcast: ' + message);
        }
        else {
            c.send(message);
        }
    }
};

module.exports = Remote;
