#!/usr/bin/env coffee
require("./proof") 1, ({ parseEqual }) ->
  parseEqual "b16{b3,x6,-b7}", [
    { "signed": false
    , "endianness": "b"
    , "bits": 16
    , "type": "n"
    , "bytes": 2
    , "exploded": false
    , "packing":
      [
        { "signed": false
        , "endianness": "b"
        , "bits": 3
        , "type": "n"
        , "bytes": 3
        , "repeat": 1
        , "arrayed": false
        , "exploded": false
        }
      ,
        { "signed": false
        , "endianness": "x"
        , "bits": 6
        , "type": "n"
        , "bytes": 6
        , "repeat": 1
        , "arrayed": false
        , "exploded": false
        }
      ,
        { "signed": true
        , "endianness": "b"
        , "bits": 7
        , "type": "n"
        , "bytes": 7
        , "repeat": 1
        , "arrayed": false
        , "exploded": true
        }
      ]
    }
  ], "parse bit packing starting with big-endian."
