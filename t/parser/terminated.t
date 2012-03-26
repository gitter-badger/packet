#!/usr/bin/env coffee
require("./proof") 3, ({ parseEqual }) ->
  bytes = [ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x00 ]
  field = bytes.slice 0, 7
  parseEqual "b8z", bytes, 8, field, "read a zero terminated array of bytes"
