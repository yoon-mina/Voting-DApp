'use strict';
var http = require('http');
var fs = require('fs');
var url = require("url")




async function gateWayPage(req, res) {
  var fname = "." + url.parse(req.url).pathname; console.log(fname)
  fs.readFile(fname, async function (err, data) {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/html' });
      return res.end("404 Not Found");
    }
    res.writeHead(200, { 'Content-Type': 'text/html' }); res.write(data);
    return res.end();
  });
}
http.createServer(gateWayPage).listen(8080, () => {
  console.log("Listening ...")
});
