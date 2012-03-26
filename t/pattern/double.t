#!/usr/bin/env coffee
require("./proof") 1, ({ parseEqual }) ->
  parseEqual "b64f", [
    { signed: true
    , bits: 64
    , endianness: "b"
    , bytes: 8
    , type: "f"
    , exploded: true
    , arrayed: false
    , repeat: 1
    }
  ], "parse a single 64 bit float."
