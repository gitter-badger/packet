// Explode a field specified in the intermediate language, filling in all the
// properties needed by a generator. Saves the hastle and clutter of repeating
// these calculations as needed.
function explode (field) {
    switch (field.type) {
    case 'structure':
        field.fields = field.fields.map(explode)
        break
    case 'alternation':
        field.select = explode(field.select)
        field.choose.forEach(function (option) {
            option.read.field = explode(option.read.field)
            option.write.field = explode(option.write.field)
        })
        break
    case 'lengthEncoded':
        field.length = explode(field.length)
        field.element = explode(field.element)
        break
    case 'integer':
        var little = field.endianess === 'l'
        var bytes = field.bits / 8
        field = {
            name: field.name,
            length: field.length,
            endianness: field.endianess,
            type: 'integer',
            little: little,
            bite: little ? 0 : bytes - 1,
            direction: little ? 1 : -1,
            stop: little ? bytes : -1,
            bits: field.bits,
            bytes: bytes
        }
        break
    }
    return field
}

module.exports = function (field) {
    return explode(field)
}
