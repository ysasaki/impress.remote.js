impress.remote.js
=================

What is impress.remote.js?
--------------------------

impress.remote.js lets you control a impress presentation like Keynote Remote.

How to use
----------

    $ git clone https://github.com/ysasaki/impress.remote.js.git impress.remote.js
    $ cd impress.remote.js/sample/
    $ make
    $ node impress.remote.server.js -h 192.168.1.2 -p 3000
    $ open http://192.168.1.2:3000

Dependencies
------------

 - node
 - npm
   - express
   - ws
 - [markdown2impress](https://github.com/yoshiki/markdown2impress)

License
-------

MIT Licensed.

See also
--------
 - [impress.js](https://github.com/bartaz/impress.js/)
 - [markdown2impress](https://github.com/yoshiki/markdown2impress)
 - [jQuery ScrollTo](http://archive.plugins.jquery.com/project/ScrollTo)
