#!/usr/bin/env node

require('./proof')(0, function (serialize) {
    serialize({ require: true }, 'foo: l32f', { foo: 10.8 }, [ 1, 3 ], [ 0xcd, 0xcc, 0x2c, 0x41 ], 'exploded incremental')
})
