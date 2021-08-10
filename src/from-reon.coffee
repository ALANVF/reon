import Token, {Value, Datatypes, nameOfToken} from "./from-reon/token.js"
import Env from "./from-reon/env.js"
import Intrinsics, {setTokenizeFunction} from "./from-reon/intrinsics.js"
import * as Eval from "./from-reon/eval.js"
import STDLIB from "./from-reon/stdlib.js"

digits = "(?:\\d+(?:'\\d+)*)"
wordBase = /[^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*/.source
comment = /^;[^\n]*(?:\n|$)/m
literals =
	none:    /^none(?=[\s()[\]{}#;"%]|$)/i
	logic:   /^(?:true|false|yes|no|on|off)(?=[\s()[\]{}#;"%]|$)/i
	word:    ///^#{wordBase}(?![:@])///
	litWord: ///^'(#{wordBase})///
	getWord: ///^:(#{wordBase})///
	setWord: ///^(#{wordBase}):(?![\w/])///
	integer: ///^
		(?<sign>   [+-])?
		(?<number> #{digits} (?! [\d,.x:/-]))
		(?<exp>    e[+-]?\d+)?
	///i
	hexa:  /^([A-F\d]{2,})h(?![\w:@])/
	float: ///^
		(?<sign>  [+-])?
		(?<ipart> #{digits})
		[,.]
		(?<fpart> #{digits} (?! \.))
		(?<exp>   e[+-]?\d+)?
	///i
	money: /^[+-]?[A-Z]{0,3}\$\d+(?:[,.]\d{1,5})?/
	tuple: /^\d+(?:\.\d+){2,12}/
	issue: /^#([^\s@#$%^()[\]{},\\;"<>/]+)/
	ref:   /^@([^\s#$@",;=\\^/<>()[\]{}]+)/
	email: /^[^\s:/()[\]{}]+@[^\s:/()[\]{}]+/
	url:   /^[A-Za-z][\w-]{1,15}:(?:\/{0,3}[^\s[\]()"]+|\/\/)/
	file:  /^%(?![\s%:;()[\]{}])(?:([^\s;"()[\]{}]+)|"((?:\^"|[^"^])*?)")/
	time:  ///^
		[+-]? (?:
			\d{0,2} : \d\d? (?:
				\. \d{0,9}
				|
				[ap]m
			)?
			|
			\d\d? : \d\d? : \d\d?
			(?: \. \d{0,9} )?
			(?: [ap]m )?
		)
	///i
	pair: /^[+-]?\d+x[+-]?\d+/i
	date: ///^
		\d{1,4}
		-
		(?:
			Jan(?:uary)? |
			Feb(?:uary)? |
			Mar(?:ch)? |
			Apr(?:il)? |
			May |
			June? |
			July? |
			Aug(?:ust)? |
			Sep(?:tember)? |
			Oct(?:ober)? |
			Nov(?:ember)? |
			Dec(?:ember)? |
			[1-9] |
			1[012]
		)
		-
		\d{1,4}
		(?:
			[T/]
			\d\d? : \d\d?
			(?:
				: \d\d?
				(?: \. \d{1,5} )?
			)?
			(?:
				Z |
				[+-] \d\d? : \d\d?
			)?
		)?
	///
	char:   /^#"((?:^\(\w+\)|\^.|[^"^]))"/
	tag:    /^<[^=><[\](){}^"\s](?:"[^"]*"|'[^']*'|[^>"']*)*>/
	string: /^"((?:\^.|[^"^]+)*)"/


class Reader
	constructor: (@input) ->
		@pos = 0
		@cachedLine = 0
		@cachedColumn = 0
	
	match: (rule, advance = true) ->
		if typeof rule is "string"
			if @input[@pos..].startsWith rule
				if advance then @pos += rule.length
				rule
			else
				null
		else
			if (match = @input[@pos..].match rule)?.index is 0
				if advance then @pos += match[0].length
				match
			else
				null
	
	next: (length = 1) ->
		@input[@pos...(@pos += length)]
	
	peek: (length = 1, offset = 0) ->
		@input[@pos..].slice offset, length
	
	eof: ->
		@pos >= @input.length
	
	line: ->
		@cachedLine = @input[..@pos].split(/\r\n?|\n/).length
	
	column: ->
		column = 0
		for char, pos in @input
			switch
				when @eof(), pos is @pos
					return @cachedColumn = column
				when char is "\n", char is "\r"
					column = 0
				else
					column++
	
	error: (message, line = null, column = null) ->
		unless line? and column?
			line = @cachedLine
			column = @cachedColumn
		
		throw new Error "Syntax Error: near #{line}:#{column}: #{message}"


Object.fromEntries ?= (arr) ->
	Object.assign {}, ...Array.from(arr, ([k, v]) => [k]: v)

# meh
String.prototype.replaceAll ?= (find, repl) ->
	if typeof find is "string"
		if @includes find
			@replace new RegExp(String.raw(raw: find), "gm"), repl # lazy
		else
			@
	else
		find = new RegExp find.source, find.flags + (if find.flags.includes("g") then "" else "g")
		@replace find, repl

trimSpace = (reader) =>
	if reader.match /^\s+/m
		if reader.match comment
			trimSpace reader
		else
			false
	else
		if reader.match comment
			trimSpace reader
		else
			false

nextLiteral = (reader) =>
	if reader.match "{"
		out = ""
		level = 1
		line = reader.line()
		column = reader.column()

		while level > 0 and not reader.eof()
			out += switch
				when reader.match "{"  then level++; "{"
				when reader.match "}"  then level--; "}"
				when reader.match "^{" then "{"
				when reader.match "^}" then "}"
				when reader.match "^^" then "^^"
				else                        reader.next()
		
		if level is 0
			return Value.string out[...-1]
		else
			reader.error "Unexpected EOF, was expecting `}` instead! (starting at #{line}:#{column})"
	
	if reader.match "("
		values = []
		line = reader.line()
		column = reader.column()

		trimSpace reader

		until reader.eof() or reader.peek() is ")"
			values.push nextToken reader
			trimSpace reader
		
		if reader.eof() or reader.peek() isnt ")"
			reader.error "Unexpected EOF, was expecting `)` instead! (starting at #{line}:#{column})"
		else
			reader.next()
			return Value.paren values
	
	for literal in ["string", "hexa", "file", "char", "issue", "ref"]
		if match = reader.match literals[literal]
			return Value[literal] match[1]
	
	for literal in ["integer", "float"]
		if match = reader.match literals[literal]
			return Value[literal] match.groups
	
	if reader.match literals.none
		return Value.NONE

	for literal in ["logic", "money", "tuple", "email", "url", "time", "pair", "date", "tag"]
		if match = reader.match literals[literal]
			return Value[literal] match[0]
	
	null

nextKey = (reader) =>
	for literal in ["litWord", "getWord", "setWord"]
		if match = reader.match literals[literal]
			return Value[literal] match[1]
	
	if match = reader.match literals.word
		Value.word match[0]
	else if (literal = nextLiteral reader)?
		literal
	else
		reader.error "Invalid key!"

nextValue = (reader, allowWord = false) =>
	switch
		when reader.match "["
			values = []
			line = reader.line()
			column = reader.column()

			trimSpace reader

			until reader.eof() or reader.peek() is "]"
				values.push nextValue(reader, allowWord)
				trimSpace reader
			
			if reader.eof() or reader.peek() isnt "]"
				reader.error "Unexpected EOF, was expecting `]` instead! (starting at #{line}:#{column})"
			else
				reader.next()
				Value.block values
		
		when reader.match "#("
			pairs = []
			line = reader.line()
			column = reader.column()

			trimSpace reader

			until reader.eof() or reader.peek() is ")"
				key = nextKey reader
				trimSpace reader
				value = nextValue(reader, allowWord)
				trimSpace reader
				pairs.push [key, value]
			
			if reader.eof() or reader.peek() isnt ")"
				reader.error "Unexpected EOF, was expecting `)` instead! (starting at #{line}:#{column})"
			else
				reader.next()
				Value.map pairs
		
		when (literal = nextLiteral reader)?
			literal
		
		else
			if allowWord
				for literal in ["litWord", "getWord", "setWord"]
					if match = reader.match literals[literal]
						return Value[literal] match[1]
				
				if match = reader.match literals.word
					return Value.word match[0]

			reader.error "Invalid value near `#{reader.peek()}`!"

nextToken = (reader) =>
	nextValue(reader, true)


normalizeStringy = (string, isEval = false) =>
	out = ""

	if isEval
		while string.length > 0
			offset = switch string[..1]
				when "^^"  then out += "^^";   2
				when '^"'  then out += '"';    2
				when "^-"  then out += "\t";   2
				when "^/"  then out += "\n";   2
				when "^{"  then out += "{";    2
				when "^}"  then out += "}";    2
				when "^@"  then out += "\0";   2
				when "^["  then out += "\x1B"; 2
				when "^\\" then out += "\x1C"; 2
				when "^]"  then out += "\x1D"; 2
				when "^_"  then out += "\x1F"; 2
				when "^~"  then out += "\x7F"; 2
				when "^("
					str = string.toLowerCase()
					switch
						when str.startsWith "^(tab)"  then out += "\t";   6
						when str.startsWith "^(line)" then out += "\n";   7
						when str.startsWith "^(null)" then out += "\0";   7
						when str.startsWith "^(back)" then out += "\b";   7
						when str.startsWith "^(page)" then out += "\x0C"; 7
						when str.startsWith "^(esc)"  then out += "\x1B"; 6
						when str.startsWith "^(del)"  then out += "\x7F"; 6
						else                               throw new Error "Invalid char!"
				else
					switch
						when string.length < 2
							out += string
							string.length
						when string.match /^\^[A-Z]/i
							out += String.fromCharCode(string.toUpperCase().charCodeAt(1) - 64)
							2
						when match = string.match /^\^\(([\dA-F]{2})\)$/i
							out += String.fromCharCode Number.parseInt(match[1], 16)
							4
						when string[0] is "^"
							throw new Error "Error in string near `#{string[..5]}`!"
						else
							out += string[0]
							1
			
			string = string[offset..]
	else
		# ew, code duplication
		while string.length > 0
			offset = switch string[..1]
				when "^^"  then out += "^";     2
				when '^"'  then out += '\\"';   2
				when "^-"  then out += "\\t";   2
				when "^/"  then out += "\\n";   2
				when "^{"  then out += "{";     2
				when "^}"  then out += "}";     2
				when "^@"  then out += "\\0";   2
				when "^["  then out += "\\x1B"; 2
				when "^\\" then out += "\\x1C"; 2
				when "^]"  then out += "\\x1D"; 2
				when "^_"  then out += "\\x1F"; 2
				when "^~"  then out += "\\x7F"; 2
				when "^("
					str = string.toLowerCase()
					switch
						when str.startsWith "^(tab)"  then out += "\\t";   6
						when str.startsWith "^(line)" then out += "\\n";   7
						when str.startsWith "^(null)" then out += "\\0";   7
						when str.startsWith "^(back)" then out += "\\b";   7
						when str.startsWith "^(page)" then out += "\\x0C"; 7
						when str.startsWith "^(esc)"  then out += "\\x1B"; 6
						when str.startsWith "^(del)"  then out += "\\x7F"; 6
						else                               throw new Error "Invalid char!"
				when "\r\n"
					out += "\\r\\n"
					2
				else
					switch
						when string[0] is "\\"
							out += "\\\\"
							1
						when string[0] is "\n"
							out += "\\n"
							1
						when string[0] is "\r"
							out += "\\r"
							1
						when string[0] is "\t"
							out += "\\t"
							1
						when string[0] is '"'
							out += '\\"'
							1
						when string.length < 2
							out += string
							string.length
						when string.match /^\^[A-Z]/i
							char = (string.toUpperCase().charCodeAt(1) - 64).toString 16
							out += "\\u00" + "0".repeat(2 - char.length) + char
							2
						when match = string.match /^\^\(([\dA-F]{2})\)$/i
							out += "\\u" + "0".repeat(4 - match[1].length) + match[1]
							4
						when string[0] is "^"
							throw new Error "Error in string near `#{string[..5]}`!"
						else
							out += string[0]
							1
			
			string = string[offset..]
	
	out


makeObject = (indent, pairs) =>
	return "{}" if pairs.length is 0

	tabs = "\t".repeat indent + 1
	kv = for [k, v] in pairs
		[_k, _v] = k
		key = switch _k
			when Token.word, Token.litWord, Token.getWord, Token.setWord
				'"' + _v + '"'
			when Token.integer, Token.float, Token.hexa
				'"' + makeValue(0, k) + '"'
			else
				makeValue 0, k

		"\n#{tabs}#{key}: #{makeValue indent + 1, v}"
	
	"{#{kv.join ","}\n#{"\t".repeat indent}}"

makeArray = (indent, values) =>
	return "[]" if values.length is 0

	vals = for value in values
		makeValue indent + 1, value
	isMultiLine =
		vals.length > 10 or
		vals.some((str) => "\n" in str or str.length > 80) or
		vals.reduce(
			(l, s) => l + s.length,
			(vals.length - 1) * 2) > 80
	
	if isMultiLine
		tabs = "\t".repeat indent + 1
		vals = for value in vals
			"\n" + tabs + value
		
		"[#{vals.join ","}\n#{"\t".repeat indent}]"
	else
		"[#{vals.join ", "}]"

makeString = ([kind, value]) =>
	switch kind
		when Token.file, Token.char, Token.string, Token.tag, Token.url then '"' + normalizeStringy(value) + '"'
		when Token.issue then '"#' + value + '"'
		when Token.ref then '"@' + value + '"'
		when Token.money, Token.tuple, Token.email, Token.time, Token.pair, Token.date then '"' + value + '"'
		else throw new TypeError "Unexpected #{nameOfToken kind}"

makeBoolean = (logic) =>
	if logic.toLowerCase() in ["true", "yes", "on"]
		"true"
	else
		"false"

makeInteger = (sign, number, exp) =>
	sign = "" if sign isnt "-"
	number = number.replace /'/g, ""
	"#{sign}#{number}#{expr ? ""}"

makeHexa = (hexa) =>
	parseInt(hexa).toString()

makeFloat = (sign, ipart, fpart, exp) =>
	sign = "" if sign isnt "-"
	ipart = ipart.replace /'/g, ""
	fpart = fpart.replace /'/g, ""
	"#{sign}#{ipart}.#{fpart}#{exp ? ""}"

makeValue = (indent, token) =>
	[kind, value] = token
	switch kind
		when Token.map then makeObject indent, value
		when Token.block then makeArray indent, value
		when Token.integer then makeInteger value.sign, value.number, value.exp
		when Token.hexa then makeHexa value
		when Token.float then makeFloat value.sign, value.ipart, value.fpart, value.exp
		when Token.logic then makeBoolean value
		when Token.none then "null"
		when Token.paren then throw new Error "Unexpected paren!"
		when Token.datatype then throw new Error "Unexpected datatype!"
		else makeString token

makeTokenValue = (indent, [kind, value]) =>
	switch kind
		when Token.map then makeObject indent, value
		when Token.block then makeArray indent, value
		when Token.integer, Token.float, Token.logic then "#{value}"
		when Token.hexa then "#{value.toString(10)}"
		when Token.none then "null"
		when Token.paren then throw new Error "Unexpected paren!"
		when Token.datatype then throw new Error "Unexpected datatype!"
		when Token.char then '"' + String.fromCharCode(value) + '"'
		when Token.issue then '"#' + value + '"'
		when Token.ref then '"@' + value + '"'
		when Token.string then '"' + normalizeStringy(value) + '"'
		else '"' + value + '"'

toValueToken = (token) =>
	[kind, value] = token
	[kind, switch kind
		when Token.block, Token.paren         then value.map(toValueToken)
		when Token.map                        then pair.map(toValueToken) for pair in value
		when Token.integer                    then Number.parseInt makeInteger(value.sign, value.number, value.exp), 10
		when Token.hexa                       then Number.parseInt value, 16
		when Token.float                      then Number.parseFloat makeFloat(value.sign, value.ipart, value.fpart, value.exp)
		when Token.logic                      then value.toLowerCase() in ["true", "yes", "on"]
		when Token.none                       then null
		when Token.char                       then normalizeStringy(value).charCodeAt 0
		when Token.string                     then normalizeStringy(value, true)
		when Token.file, Token.tag, Token.url then normalizeStringy(value)
		else                                                value]


tokenize = (input) =>
	reader = new Reader input
	until (trimSpace reader; reader.eof())
		toValueToken(nextToken reader)

setTokenizeFunction tokenize

evalREON = (env, input) =>
	reader = new Reader input
	tokens = until (trimSpace reader; reader.eof())
		toValueToken(nextToken reader)
	
	Eval.evalTokens env, tokens 


export default fromREON = (input) =>
	reader = new Reader input
	
	trimSpace reader

	return if reader.match literals.setWord, false
		env = new Env env: {Intrinsics...}

		for name, kind of Token
			env.set name + "!", Datatypes.tokenType kind
			env.set name + "?", new Eval.Macro [[Eval.Param.val, "value"]], [], [
				Value.word("same?"),
				Value.word("type?"),
				Value.word("value"),
				Value.word(name + "!")
			]
		
		evalREON env, STDLIB

		tokens = until (trimSpace reader; reader.eof())
			toValueToken(nextToken reader)
		
		mainValue = tokens.pop()

		throw new TypeError "Unexpected #{nameOfToken mainValue[0]}" if mainValue[0] isnt Token.map
		
		Eval.evalTokens env, tokens
		
		mainValue = Intrinsics["compose.deep"].fn(env, [mainValue])
		_makeValue = makeValue
		makeValue = makeTokenValue
		res = makeValue 0, mainValue
		makeValue = _makeValue
		
		res
	else
		makeValue 0, nextValue reader