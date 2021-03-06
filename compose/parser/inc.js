var Variables = require('../variables')
var explode = require('../explode')
var qualify = require('../qualify')
var joinSources = require('../join-sources')
var $ = require('programmatic')

function Generator () {
    this.step = 0
    this.variables = new Variables
}

function when (condition, source) {
    return condition ? source : ''
}

Generator.prototype.integer = function (field, property, cached) {
    var read = [], bite = field.bite, stop = field.stop, step = this.step
    while (bite != stop) {
        read.unshift('buffer[start++]')
        if (bite) {
            read[0] += ' * 0x' + Math.pow(256, bite).toString(16)
        }
        bite += field.direction
    }
    if (cached) {
        this.cached = true
    }
    read = read.reverse().join(' + \n')
    var direction = field.little ? '++' : '--'
    var source = $('                                                        \n\
        case ' + (this.step++) + ':                                         \n\
            // __blank__                                                    \n\
            ' + when(cached, 'this.cache = []') + '                         \n\
            this.stack.push({                                               \n\
                value: 0,                                                   \n\
                bite: ' + field.bite + '                                    \n\
            })                                                              \n\
            this.step = ' + this.step + '                                   \n\
            // __blank__                                                    \n\
        case ' + (this.step++) + ':                                         \n\
            // __blank__                                                    \n\
            frame = this.stack[this.stack.length - 1]                       \n\
            // __blank__                                                    \n\
            while (frame.bite != ' + stop + ') {                            \n\
                if (start == end) {                                         \n\
                    engine.start = start                                    \n\
                    return                                                  \n\
                }                                                           \n\
                ' + when(cached, 'this.cache.push(buffer[start])') + '      \n\
                frame.value += Math.pow(256, frame.bite) * buffer[start++]  \n\
                frame.bite', direction, '                                   \n\
            }                                                               \n\
            // __blank__                                                    \n\
            this.stack.pop()                                                \n\
            this.stack[this.stack.length - 1].' + property + ' = frame.value\n\
    ')
    return {
        step: step,
        source: source
    }
}

Generator.prototype.construct = function (packet) {
    var fields = []
    // TODO Not always a structure, sometimes it is an object.
    if (packet.type == 'structure') {
        packet.fields.forEach(function (packet) {
            switch (packet.type) {
            case 'integer':
            case 'alternation':
                fields.push(packet.name + ': null')
                break
            case 'lengthEncoded':
                fields.push(packet.name + ': new Array')
                break
            }
        }, this)
    } else {
        throw new Error('to do')
    }
    return fields.join(',\n')
}

Generator.prototype.alternation = function (packet, depth) {
    var step = this.step
    this.forever = true
    var integer = this.integer(packet.select, 'select', true)
    var source = integer.source
    packet.choose.forEach(function (choice, index) {
        var when = choice.read.when || {}, test
        if (when.and != null) {
            test = 'frame.select & 0x' + when.and.toString(16)
        }
        choice.condition = '} else {'
        if (test) {
            if (index === 0) {
                choice.condition = 'if (' + test + ') {'
            } else {
                choice.condition = '} else if (' + test + ') {'
            }
        }
    })
    var sources = [], dispatch = ''
    packet.choose.forEach(function (choice) {
        choice.read.field.name = packet.name
        var compiled = this.field(choice.read.field)
        dispatch = $('                                                      \n\
            // __reference__                                                \n\
            ', dispatch, '                                                  \n\
            ', choice.condition, '                                          \n\
            // __blank__                                                    \n\
                this.step = ' + compiled.step + '                           \n\
                this.parse({                                                \n\
                    buffer: this.cache,                                     \n\
                    start: 0,                                               \n\
                    end: this.cache.length                                  \n\
                })                                                          \n\
                continue                                                    \n\
                // __blank__                                                \n\
        ')
        sources.push(compiled.source)
    }, this)
    var steps = ''
    sources.forEach(function (source) {
        steps = $('                                                         \n\
            // __reference__                                                \n\
            ', steps, '                                                     \n\
            ', source, '                                                    \n\
                this.step = ' + this.step + '                               \n\
            // __blank__                                                    \n\
        ')
    }, this)
    source = $('                                                            \n\
        // __reference__                                                    \n\
        ', source, '                                                        \n\
            frame = this.stack[this.stack.length - 1]                       \n\
            // __blank__                                                    \n\
            ', dispatch, '                                                  \n\
            }                                                               \n\
        // __blank__                                                        \n\
        ', steps, '                                                         \n\
    ')
    return {
        step: integer.step,
        source: source
    }
}

Generator.prototype.lengthEncoded = function (packet, depth) {
    var source = ''
    this.forever = true
    var integer = this.integer(packet.length, 'length')
    var again = this.step
    source = $('                                                            \n\
        // __reference__                                                    \n\
        ', integer.source, '                                                \n\
        // __blank__                                                        \n\
            this.stack[this.stack.length - 1].index = 0                     \n\
        // __blank__                                                        \n\
        case ' + (this.step++) + ':                                         \n\
            // __blank__                                                    \n\
            this.stack.push({                                               \n\
                object: {                                                   \n\
                    ', this.construct(packet.element, 0), '                 \n\
                }                                                           \n\
            })                                                              \n\
            // __blank__                                                    \n\
        ', this.field(packet.element), '                                    \n\
            // __blank__                                                    \n\
            frame = this.stack[this.stack.length - 2]                       \n\
            frame.object.' + packet.name + '.push(this.stack.pop().object)  \n\
            if (++frame.index != frame.length) {                            \n\
                this.step = ' + again + '                                   \n\
                continue                                                    \n\
            }                                                               \n\
    ')
    return {
        step: integer.step,
        source: source
    }
}

Generator.prototype.field = function (packet) {
    switch (packet.type) {
    case 'structure':
        return joinSources(packet.fields.map(function (packet) {
            return this.field(packet).source
        }.bind(this)))
    case 'alternation':
        return this.alternation(packet)
    case 'lengthEncoded':
        return this.lengthEncoded(packet)
    default:
        var object = 'object'
        if (packet.type === 'integer')  {
            return this.integer(packet, object + '.' + packet.name)
        }
    }
}

Generator.prototype.parser = function (packet) {
    var source = this.field(packet, 0)
    var dispatch = $('                                                      \n\
        switch (this.step) {                                                \n\
        ', source, '                                                        \n\
        case ' + this.step + ':                                             \n\
            // __blank__                                                    \n\
            engine.start = start                                            \n\
            // __blank__                                                    \n\
        }                                                                   \n\
    ')
    if (this.forever) {
        dispatch = $('                                                      \n\
            for (;;) {                                                      \n\
                // __blank__                                                \n\
                ', dispatch, '                                              \n\
                // __blank__                                                \n\
                break                                                       \n\
            }                                                               \n\
        ')
    }
    return $('                                                              \n\
        parsers.' + packet.name + ' = function () {                         \n\
            this.step = 0                                                   \n\
            this.stack = [{                                                 \n\
                object: this.object = {                                     \n\
                    ', this.construct(packet), '                            \n\
                },                                                          \n\
                array: null,                                                \n\
                index: 0,                                                   \n\
                length: 0                                                   \n\
            }]                                                              \n\
            ' + when(this.cached, 'this.cache = null') + '                  \n\
        }                                                                   \n\
        // __blank__                                                        \n\
        parsers.' + packet.name + '.prototype.parse = function (engine) {   \n\
            var buffer = engine.buffer                                      \n\
            var start = engine.start                                        \n\
            var end = engine.end                                            \n\
            // __blank__                                                    \n\
            var frame = this.stack[this.stack.length - 1]                   \n\
            // __blank__                                                    \n\
            ', dispatch, '                                                  \n\
        }                                                                   \n\
    ')
}

module.exports = function (compiler, definition) {
    var source = joinSources(definition.map(function (packet) {
        return new Generator().parser(explode(packet))
    }))
    source = $('                                                            \n\
        var parsers = {}                                                    \n\
        // __blank__                                                        \n\
        ', source, '                                                        \n\
        // __blank__                                                        \n\
        return parsers                                                      \n\
    ')
    return compiler(source)
}
