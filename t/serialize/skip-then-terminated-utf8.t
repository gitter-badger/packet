#!/usr/bin/env coffee
require("./proof") 2, ({ serialize }) ->
  serialize "x16{0}, b8z|utf8()", "ABC", 6, [ 0x00, 0x00, 0x41, 0x42, 0x43, 0x00 ],
    "write a zero terminated UTF-8 string after skipping"
