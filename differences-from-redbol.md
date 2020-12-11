## Unsupported features

- `any-path!`
- `refinement!`
- `bitset!`
- `any-object!`
- `vector!`
- `any-function!` (macros are used instead)
- `hash!`
- `handle!`
- `datatype!`/`typeset!`
- `unset!`
- Construction syntax
- Binary operators
- Most actions and natives
- I/O
- ...


## Unsupported features that may be added in the future

- `binary!`
- `percent!`
- `raw-string!`
- `image!`
- Special words such as `/`, `//`, and `%`
- File metadata
- Docstrings and types in macro specs
- ...


## Other differences

To simplify implementations of REON:
- Macros cannot be passed around as a regular value
- Series values do not have an associated index
- `issue!` values act more like a string than a word
- `a: b: c:` syntax is used instead of `/local a b c` when declaring local variables in the macro spec

In an attempt to prevent unwanted surprises:
- Indexing starts at 0
- Series operations such as `append` and `compose` will always treat a block as a single value
- Standard logic words are always evaluated


## Intrinsics
(aka natives, actions, builtins, etc)

Note: Because REON does not support refinements, `.` is used in place of `/`.

```red
macro: make intrinsic! [[
	Defines a macro with a given spec and body"
	spec    [block!] "Parameters"
	body    [block!] "Code body"
	return: [macro!]
]]

type?.word: make intrinsic! [[ ;@@ TODO: fix
	"Returns the datatype of a value as a word value (rather than a datatype)"
	value   [any-type!]
	return: [word!]
]]

value?: make intrinsic! [[
	"Returns TRUE if the word has a value"
	value   [word!]
	return: [logic!]
]]

get: make intrinsic! [[
	"Returns the value a word refers to"
	word    [any-word!]
	return: [any-type!]
]]

set: make intrinsic! [[
	"Sets the value(s) one or more words refer to"
	word    [any-word! block!]
	value   [any-type!]
	return: [any-type!]
]]

reduce: make intrinsic! [[
	"Returns a copy of a block, evaluating all expressions"
	value   [any-type!]
	return: [any-type!]
]]

compose: make intrinsic! [[
	"Returns a copy of a block, evaluating only parens"
	value [any-type!]
]]

compose.deep: make intrinsic! [[
	"Returns a copy of a block, evaluating only parens. Also composes nested blocks"
	value   [any-type!]
	return: [any-type!]
]]

do: make intrinsic! [[
	"Evaluates a value, returning the last evaluation result"
	value   [any-type!]
	return: [any-type!]
]]

do.next: make intrinsic! [[
	"Do next expression only, return it, update block word"
	value   [any-type!]
	rest    [word!]     "Word updated with new block position"
	return: [any-type!]
]]

pick: make intrinsic! [[
	"Returns the series value at a given index"
	series	 [series! map! pair! tuple! money! date! time!]
	index 	 [scalar! any-string! any-word!]
	return:  [any-type!]
]]

copy: make intrinsic! [[
	"Returns a copy of a value"
	value   [any-type!]
	return: [any-type!]
]]

copy.deep: make intrinsic! [[
	"Returns a copy of a value. Also copies nested values"
	value   [any-type!]
	return: [any-type!]
]]

not: make intrinsic! [[
	"Returns the logical complement of a value (truthy or falsy)"
	value   [any-type!]
	return: [logic!]
]]

and: make intrinsic! [[
	"Returns the first value ANDed with the second"
	value1	[logic! integer! char! pair! tuple!]
	value2	[logic! integer! char! pair! tuple!]
	return:	[logic! integer! char! pair! tuple!]
]]

or: make intrinsic! [[
	"Returns the first value ORed with the second"
	value1	[logic! integer! char! pair! tuple!]
	value2	[logic! integer! char! pair! tuple!]
	return:	[logic! integer! char! pair! tuple!]
]]

xor: make intrinsic! [[
	"Returns the first value exclusive ORed with the second"
	value1	[logic! integer! char! pair! tuple!]
	value2	[logic! integer! char! pair! tuple!]
	return:	[logic! integer! char! pair! tuple!]
]]

strict-equal?: make intrinsic! [[
	"Returns TRUE if two values are equal, and also the same datatype"
	value1  [any-type!]
	value2  [any-type!]
	return: [logic!]
]]

same?: make intrinsic! [[
	"Returns TRUE if two values have the same identity"
	value1  [any-type!]
	value2  [any-type!]
	return: [logic!]
]]

if: make intrinsic! [[
	"If conditional expression is truthy, evaluate block; else return NONE"
	cond    [any-type!]
	block   [block!]
	return: [any-type!]
]]

either: make intrinsic! [[
	"If conditional expression is truthy, evaluate the first branch; else evaluate the alternative"
	cond     [any-type!]
	then-blk [block!]
	else-blk [block!]
	return:  [any-type!]
]]

while: make intrinsic! [[
	"Evaluates body as long as condition block evaluates to truthy value"
	cond    [block!]
	body    [block!]
	return: [any-type!]
]]

foreach: make intrinsic! [[
	"Evaluates body for each value in a series"
	'word   [word! block!]
	data    [series! map!] ;@@ TODO: fix
	body    [block!]
	return: [any-type!]
]]

return: make intrinsic! [[
	"Returns a value from a macro"
	value [any-type!]
]]

exit: make intrinsic! [[
	"Exits a macro, returning no value"
]]

break: make intrinsic! [[
	"Breaks out of a loop"
]]

break.return: make intrinsic! [[
	"Breaks out of a loop, returning a value"
	value [any-type!]
]]

continue: make intrinsic! [[
	"Throws control back to top of loop"
]]

form: make intrinsic! [[
	"Converts a value to a human-readable string"
	value   [any-type!]
	return: [string!]
]]

length?: make intrinsic! [[
	"Gets the length of a series value"
	series  [series! map! tuple! none!]
	return: [integer! none!]
]]

append: make intrinsic! [[
	"Adds a single value to the end of a series"
	series  [series!]
	value   [any-type!]
	return: [series!]
]]

extend: make intrinsic! [[
	"Extends a map type with word and value pair"
	map     [map!]
	key     [scalar! any-string! any-word!]
	value   [any-type!]
	return: [any-type!]
]]
```