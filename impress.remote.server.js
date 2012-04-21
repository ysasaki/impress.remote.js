/**
 * impress.remote.server.js
 *
 * MIT Licensed.
 *
 * Copyright 2012 Yoshihiro Sasaki (@aloelight)
 */
var Remote = require('./impress.remote')
    , opt = require('getopt');

// set default opt
var host = '127.0.0.1', port = 3000;

try {
    opt.setopt("h:p:");
} catch (e) {
    console.dir(e);
    process.exit(1);
}
opt.getopt(function(o,p) {
    switch(o) {
        case "h":
            host = p[0];
            break;
        case "p":
            port = p[0];
            break;
    }
});

var server = new Remote({host:host, port:port});
console.log("Starting Impress.js Remote Server(%s:%s)...", host, port);
