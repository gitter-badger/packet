#!/usr/bin/env node

require("./proof")(3, function (offsetsOf) {
  offsetsOf("b8z<13,10> => numbers", [
    0xab, 0xcd, 0xef, 0x0d, 0x0a
  ], {
    numbers: { pattern: 'b8z<13,10>',
               value: [{ pattern: 'b8', value: 0xab, offset: 0, length: 1, hex: "ab" },
                       { pattern: 'b8', value: 0xcd, offset: 1, length: 1, hex: "cd" },
                       { pattern: 'b8', value: 0xef, offset: 2, length: 1, hex: "ef" }],
               offset: 0,
               terminator: { value: [ 13, 10 ], offset: 3, length: 2, hex: "0d0a" },
               length: 5,
               hex: 'abcdef0d0a' }
  }, "offsets of a custom terminated array");
});