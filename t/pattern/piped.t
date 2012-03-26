#!/usr/bin/env coffee
require("./proof") 1, ({ parseEqual }) ->
  parseEqual "b8z|str()", [
    { signed: false
    , bits: 8
    , endianness: "b"
    , bytes: 1
    , type: "n"
    , exploded: false
    , arrayed: true
    , repeat: Number.MAX_VALUE
    , terminator: [ 0 ]
    , pipeline:
      [
        { name: "str"
        , parameters: []
        }
      ]
    }
  ], "parse an list of bytes termianted by zero piped to a transform."
