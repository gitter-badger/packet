#!/usr/bin/env node
require('./proof')(0, function (serialize) {
    serialize('foo: l16', { foo: 0x1FF }, 2, [ 0xFF, 0x01 ], 'write a little-endian 16 bit integer')
})
