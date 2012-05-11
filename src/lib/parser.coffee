# Require the necessary Packet sibling modules.
{parse}   = require "./pattern"
{Packet}  = require "./packet"
ieee754   = require "./ieee754"

##### Parser

# The `Parser` reads binary data from a stream and converts it into JavaScript
# primitives, Strings and arrays of JavaScript primitives.
class exports.Parser extends Packet
  # Construct a `Parser` that will use the given `self` object as the `this`
  # when a callback is called. If no `self` is provided, the `Serializer`
  # instance will be used as the `this` object for serialization event
  # callbacks.
  constructor: (self) ->
    super self
    @writable = true

  # Get the number of bytes read since the last call to `@reset()`. 
  getBytesRead: -> @_bytesRead

  # Initialize the next field pattern in the serialization pattern array, which
  # is the pattern in the array `@_pattern` at the current `@_patternIndex`.
  _nextField: ->
    pattern       = @_pattern[@_patternIndex]
    @_repeat      = pattern.repeat
    @_index       = 0
    @_skipping    = null
    @_terminated  = not pattern.terminator
    @_terminator  = pattern.terminator and
                    pattern.terminator[pattern.terminator.length - 1]
    @_arrayed     = [] if pattern.arrayed and pattern.endianness isnt "x"
    @_named     or= !! pattern.name

  # Prepare the parser to parse the next value in the input stream.  It
  # initializes the value to a zero integer value or an array.  This method
  # accounts for skipping, for skipped patterns.
  _nextValue: ->
    # Get the next pattern.
    pattern = @_pattern[@_patternIndex]

    # If skipping, skip over the count of bytes.
    if pattern.endianness is "x"
      @_skipping  = pattern.bytes

    # Create the empty value and call the inherited `@_nextValue`.
    else
      if pattern.exploded
        value = []
      else
        value = 0

      super value

  # Set the next packet to parse by providing a named packet name or a packet
  # pattern, with an optional `callback`. The optional `callback` will override
  # the callback assigned to a named pattern.
  extract: (nameOrPattern, callback) ->
    @_nameOrPattern nameOrPattern, callback
    @_fields      = []

    @_nextField()
    @_nextValue()

  ##### parser.skip(length[, callback])

  # Skip a region of input stream, invoking the given `callback` when `length`
  # bytes have been skipped. The callback will be invoked with the flexible
  # `this` object.
  skip: (length, @_callback) ->
    # Create a bogus pattern to enter the parse loop where the stream is fed in
    # the skipping branch.
    @_pattern      = [ {} ]
    @_terminated   = true
    @_index        = 0
    @_repeat       = 1
    @_patternIndex = 0
    @_fields       = []

    @_skipping     = length

  ##### parser.stream(length[, callback])

  # Construct a readable stream that will read `length` bytes from the stream
  # and invoke the given `callback` when the bytes have been read.
  # 
  # A zero `length` will confuse the `parse` loop, so we call the `callback`
  # immediately.
  stream: (length, callback) ->
    if length > 0
      @skip(length, callback)
      @_stream = new (require("./readable").ReadableStream)(@, length, callback)
    else
      callback()
    
  ##### parser.write(buffer[, encoding])
  
  # Parse the `Buffer` or `String` given in `buffer`. If `buffer` is a string it
  # is decoded using the given `encoding` or UTF-8 if no encoding is specified.
  #
  # If the stream is paused by a pattern callback, this method will return
  # `false`, to indicate that the parser is no longer capable of accepting data.
  write: (buffer, encoding) ->
    if typeof buffer is "string"
      buffer = new Buffer(buffer, encoding or "utf8")
    @parse(buffer, 0, buffer.length)

  ##### parser.parse(buffer[, offset][, length])
  # The `parse` method reads from the buffer, returning when the current pattern
  # is read, or the end of the buffer is reached.
  #
  # If the stream is paused by a pattern callback, this method will return
  # `false`, to indicate that the parser is no longer capable of accepting data.

  # Read from the `buffer` for the given `offset` `and length`.
  parse: (buffer, offset, length) ->
    # If we are paused, freak out.
    if @_paused
      throw new Error "cannot write to paused parser"

    # Initialize the loop counters. Initialize unspecified parameters with their
    # defaults.
    offset or= 0
    length or= buffer.length
    start    = @_bytesRead
    end      = offset + length

    # We set the pattern to null when all the fields have been read, so while
    # there is a pattern to fill and bytes to read.
    while @_pattern != null and offset < end
      field = @_pattern[@_patternIndex]
      # If we are skipping, we advance over all the skipped bytes or to the end
      # of the current buffer.
      if @_skipping?
        advance      = Math.min(@_skipping, end - offset)
        begin        = offset
        offset      += advance
        @_skipping  -= advance
        @_bytesRead += advance
        # If feeding a stream is done through skipping. Skipping and the
        # presence of a stream is how skipping is done.
        if @_stream
          if Array.isArray(buffer)
            slice = new Buffer(buffer.slice(begin, begin + advance))
          else
            slice = buffer.slice(begin, begin + advance)
          @_stream._write(slice)
          if not @_skipping
            @_stream._end()
        # If we have more bytes to skip, then return `true` because we've
        # consumed the entire buffer.
        if @_skipping
          return true
        else
          @_skipping = null

      else
        # If the pattern is exploded, the value we're populating is an array.
        if field.exploded
          loop
            b = buffer[offset]
            @_bytesRead++
            offset++
            @_value[@_offset] = b
            @_offset += @_increment
            break if @_offset is @_terminal
            return true if offset is end

        # Otherwise we're packing bytes into an unsigned integer, the most
        # common case.
        else
          loop
            b = buffer[offset]
            @_bytesRead++
            offset++
            @_value += Math.pow(256, @_offset) * b
            @_offset += @_increment
            break if @_offset == @_terminal
            return true if offset is end

        # Unpack the field value. Perform our basic transformations. That is,
        # convert from a byte array to a JavaScript primitive.
        #
        # Resist the urge to implement these conversions with pipelines. It
        # keeps occuring to you, but those transitions are at a higher level of
        # abstraction, primairly for operations on gathered byte arrays. These
        # transitions need to take place immediately to populate those arrays.

        # By default, value is as it is.
        bytes = value = @_value

        # Convert to float or double.
        if field.type == "f"
          if field.bits == 32
            value = ieee754.fromIEEE754Single(bytes)
          else
            value = ieee754.fromIEEE754Double(bytes)

        # Get the two's compliment signed value. 
        else if field.signed
          value = 0
          if (bytes[bytes.length - 1] & 0x80) == 0x80
            top = bytes.length - 1
            for i in [0...top]
              value += (~bytes[i] & 0xff) * Math.pow(256, i)
            # To get the two's compliment as a positive value you use
            # `~1 & 0xff == 254`. For exmaple: `~1 == -2`.
            value += (~(bytes[top] & 0x7f) & 0xff & 0x7f) * Math.pow(256, top)
            value += 1
            value *= -1
          else
            # Not really necessary, the bit about top.
            top = bytes.length - 1
            for i in [0...top]
              value += (bytes[i] & 0xff)  * Math.pow(256, i)
            value += (bytes[top] & 0x7f) * Math.pow(256, top)

        # If the current field is arrayed, we keep track of the array we're
        # building after a pause through member variable.
        @_arrayed.push(value) if field.arrayed

      # If we've not yet hit our terminator, check for the terminator. If we've
      # hit the terminator, and we do not have a maximum size to fill, then
      # terminate by setting up the array to terminate.
      #
      # A length value of the maximum number value means to repeat until the
      # terminator, but a specific length value means that the zero terminated
      # string occupies a field that has a fixed length, so we need to skip the
      # unused bytes.
      if not @_terminated
        if @_terminator is value
          @_terminated = true
          terminator = @_pattern[@_patternIndex].terminator
          for i in [1..terminator.length]
            if @_arrayed[@_arrayed.length - i] isnt terminator[terminator.length - i]
              @_terminated = false
              break
          if @_terminated
            for char in terminator
              @_arrayed.pop()
            @_terminated = true
            if @_repeat == Number.MAX_VALUE
              @_repeat = @_index + 1
            else
              @_skipping = (@_repeat - (++@_index)) * field.bytes
              if @_skipping
                @_repeat = @_index + 1
                continue

      # If we are reading an arrayed pattern and we have not read all of the
      # array elements, we repeat the current field type.
      if ++@_index <  @_repeat
        @_nextValue()

      # Otherwise, we've got a complete field value, either a JavaScript
      # primitive or raw bytes as an array.
      else

        # If we're not skipping, push the field value after running it through
        # the pipeline.
        if field.endianness isnt "x"

          # If the field is a bit packed field, unpack the values and push them
          # onto the field list.
          if packing = field.packing
            length  = field.bits
            for pack, i in packing
              length -= pack.bits
              if pack.endianness is "b"
                unpacked = Math.floor(value / Math.pow(2, length))
                unpacked = unpacked % Math.pow(2, pack.bits)
                # If signed, we convert from two's compliment.
                if pack.signed
                  mask = Math.pow(2, pack.bits - 1)
                  if unpacked & mask
                    unpacked = -(~(unpacked - 1) & (mask * 2 - 1))
                @_fields.push(unpacked)

          # If the value is a length encoding, we set the repeat value for the
          # subsequent array of values. If we have a zero length encoding, we
          # push an empty array through the pipeline, and move on to the next
          # field.
          else if field.lengthEncoding
            if (@_pattern[@_patternIndex + 1].repeat = value) is 0
              @_fields.push(@_pipeline(field, [], false))
              @_patternIndex++

          # If the value is used as a switch for an alternation, we run through
          # the different possible branches, updating the pattern with the
          # pattern of the first branch that matches. We then re-read the bytes
          # used to determine the conditional outcome.
          else if field.alternation
            unless field.signed
              value = (Math.pow(256, i) * b for b, i in @_arrayed)
            for branch in field.alternation
              break if branch.read.minimum <= value and
                       value <= branch.read.maximum and
                       (value & branch.read.mask) is branch.read.mask
            if branch.failed
              throw new Error "Cannot match branch."
            bytes = @_arrayed.slice(0)
            @_bytesRead -= bytes.length
            @_pattern.splice.apply @_pattern, [ @_patternIndex, 1 ].concat(branch.pattern)
            @_nextField()
            @_nextValue()
            @parse bytes, 0, bytes.length
            continue

          # Otherwise, the value is what it is, so run it through the user
          # supplied tranformation pipeline, and push it onto the list of fields.
          else
            value = @_arrayed if field.arrayed
            @_fields.push(@_pipeline(field, value, false))

        # If we have read all of the pattern fields, call the associated
        # callback.  We add the parser and the user suppilied additional
        # arguments onto the callback arguments.
        #
        # The pattern is set to null, our terminal condition, because the
        # callback may specify a subsequent packet to parse.
        if ++@_patternIndex == @_pattern.length
          [ pattern, @_pattern ] = [ @_pattern, null ]

          if @_callback
            # At one point, you thought you could have  a test for the arity of
            # the function, and if it was not `1`, you'd call the callback
            # positionally, regardless of named parameters. Then you realized
            # that the `=>` operator in CoffeeScript would use a bind function
            # with no arguments, and read the argument array. If you do decide
            # to go back to arity override, then greater than one is the
            # trigger. However, on reflection, I don't see that the flexiblity
            # is useful, and I do believe that it will generate at least one bug
            # report that will take a lot of hashing out only to close with "oh,
            # no, you hit upon a "hidden feature".
            offset = 0
            if @_named
              object = {}
              for field in pattern
                if field.endianness isnt "x"
                  if field.packing
                    for pack in field.packing
                      if pack.endianness isnt "x"
                        if pack.name
                          object[pack.name] = @_fields[offset]
                        else
                          object["field#{offset + 1}"] = @_fields[offset]
                        offset++
                  else
                    if field.name
                      object[field.name] = @_fields[offset]
                    else
                      object["field#{offset + 1}"] = @_fields[offset]
                    offset++
              @_callback.call @_self, object
            else
              @_callback.apply @_self, @_fields

            # The callback can pause the parser, which causes us to stash the
            # current state of our parser, then return `false` to indicate that
            # the destination is saturated.
            if @_paused
              @_paused = { buffer, offset, end }
              return false

        # Otherwise we proceed to the next field in the packet pattern.
        else
          @_nextField()
          @_nextValue()

    # We were able to write the whole
    true

  # Mark the parser as paused and notify the source of the pause.
  pause: ->
    @_paused = true
    @emit "pause"

  resume: ->
    if @_paused
      [ paused, @_paused ] = [ @_paused, false ]
      @emit "resume"
      @parse paused.buffer, paused.start, paused.end

  # What to do?
  destroy: ->
  destroySoon: ->
    
  close: ->
    @emit "close"

  end: (string, encoding) ->
    @write(string, encoding) if string
    @emit "end"