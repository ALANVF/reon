digits = "(?:\\d(?:'?\\d+)*)"
comment = /;[^\n]*(?:\n|$)/m
literals =
	none:    /none(?=[\s()[\]{}#;"%]|$)/i
	logic:   /(?:true|false|yes|no|on|off)(?=[\s()[\]{}#;"%]|$)/i
	word:    /[^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*(?![:@])/
	litWord: /'([^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*)/
	getWord: /:([^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*)/
	setWord: /([^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*):(?![\w/])/
	integer: ///
		(?<sign>   [+-])?
		(?<number> #{digits} (?! [,.x:/-]))
		(?<exp>    e[+-]?\d+)?
	///i
	hexa:  /([A-F\d]{2,})h(?![\w:@])/
	float: ///
		(?<sign>  [+-])?
		(?<ipart> #{digits})
		[,.]
		(?<fpart> #{digits} (?! \.))
		(?<exp>   e[+-]?\d+)?
	///i
	money: /[+-]?[A-Z]{0,3}\$\d+(?:[,.]\d{1,5})?/
	tuple: /\d+(?:\.\d+){2,12}/
	issue: /#[^\s@#$%^()[\]{},\\;"<>/]+/
	ref:   /@[^#$@",;=\\^/<>()[\]{}]+/
	email: /[^\s:/()[\]{}]+@[^\s:/()[\]{}]+/
	url:   /[A-Za-z][\w-]{1,15}:(?:\/{0,3}[^\s[\]()"]+|\/\/)/
	file:  /%(?![\s%:;()[\]{}])(?:([^\s;"]+)|"((?:\^"|[^"^])*?)")/
	time:  ///
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
	pair: /[+-]?\d+x[+-]?\d+/i
	date: ///
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
	char:   /#"((?:^\(\w+\)|\^.|[^"^]))"/
	tag:    /<[^=><[\](){}l^"\s](?:"[^"]*"|'[^']*'|[^>"']*)*>/
	string: /"((?:\^.|[^"^]+)*)"/


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
		@pos >= @input.length - 1
	
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


Object.fromEntries = (arr) ->
	Object.assign {}, ...Array.from(arr, ([k, v]) => [k]: v)


trimSpace = (reader) ->
	if reader.match /\s+/m
		if reader.match comment
			trimSpace reader
		else
			false
	else
		if reader.match comment
			trimSpace reader
		else
			false

nextLiteral = (reader) ->
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
			return string: out[...-1]
		else
			reader.error "Unexpected EOF, was expecting `}` instead! (starting at #{line}:#{column})"
	
	for literal in ["string", "hexa", "file", "char"]
		if match = reader.match literals[literal]
			return [literal]: match[1]
	
	for literal in ["integer", "float"]
		if match = reader.match literals[literal]
			return [literal]: match.groups
	
	for literal in ["none", "logic", "money", "tuple", "issue", "ref", "email", "url", "time", "pair", "date", "tag"]
		if match = reader.match literals[literal]
			return [literal]: match[0]
	
	null

nextKey = (reader) ->
	for literal in ["litWord", "getWord", "setWord"]
		if match = reader.match literals[literal]
			return [literal]: match[1]
	
	if match = reader.match literals.word
		word: match[0]
	else if literal = nextLiteral reader
		literal
	else
		reader.error "Invalid key!"

nextValue = (reader) ->
	switch
		when reader.match "["
			values = []
			line = reader.line()
			column = reader.column()

			trimSpace reader

			until reader.eof() or reader.peek() is "]"
				values.push nextValue reader
				trimSpace reader
			
			if reader.peek() isnt "]"
				reader.error "Unexpected EOF, was expecting `]` instead! (starting at #{line}:#{column})"
			else
				reader.next()
				block: values
		
		when reader.match "#("
			pairs = []
			line = reader.line()
			column = reader.column()

			trimSpace reader

			until reader.eof() or reader.peek() is ")"
				key = nextKey reader
				trimSpace reader
				value = nextValue reader
				trimSpace reader
				pairs.push [key, value]
				
			
			if reader.peek() isnt ")"
				reader.error "Unexpected EOF, was expecting `)` instead! (starting at #{line}:#{column})"
			else
				reader.next()
				map: pairs
		
		when (literal = nextLiteral reader)?
			literal
		
		else
			reader.error "Invalid value near `#{reader.peek()}`!"


normalizeStringy = (string) ->
	out = ""

	while string.length > 0
		str = string.toLowerCase()
		offset = switch str[..1]
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
				switch
					when str.startsWith "^(tab)"  then out += "\\t";   6
					when str.startsWith "^(line)" then out += "\\n";   7
					when str.startsWith "^(null)" then out += "\\0";   7
					when str.startsWith "^(back)" then out += "\\b";   7
					when str.startsWith "^(page)" then out += "\\x0C"; 7
					when str.startsWith "^(esc)"  then out += "\\x1B"; 6
					when str.startsWith "^(del)"  then out += "\\x7F"; 6
					else                               throw new Error "Invalid char!"
			else
				switch
					when string[0] is "\\"
						out += "\\\\"
						1
					when string[0] is "\n"
						out += "\\n"
						1
					when string[0] is "\t"
						out += "\\t"
						1
					when string.length < 2
						out += string
						string.length
					when string.match /^\^[A-Z]/i
						char = (string[1].toUpperCase().charCodeAt(1) - 64).toString 16
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

makeObject = (indent, pairs) ->
	return "{}" if pairs.length is 0

	tabs = "\t".repeat indent + 1
	kv = for [k, v] in pairs
		[[_k, _v]] = Object.entries k
		key = switch _k
			when "word", "litWord", "getWord", "setWord"
				'"' + _v + '"'
			when "integer", "float", "hexa"
				'"' + makeValue(0, k) + '"'
			else
				makeValue 0, k

		"\n#{tabs}#{key}: #{makeValue indent + 1, v}"
	
	"{#{kv.join ","}\n#{"\t".repeat indent}}"

makeArray = (indent, values) ->
	return "[]" if values.length is 0

	vals = for value in values
		makeValue indent + 1, value
	
	if vals.length > 10 or vals.some (str) => "\n" in str or str.length > 80
		tabs = "\t".repeat indent + 1
		vals = for value in vals
			"\n" + tabs + value
		
		"[#{vals.join ","}\n#{"\t".repeat indent}]"
	else
		"[#{vals.join ", "}]"

makeString = (stringy) ->
	[[token, value]] = Object.entries stringy
	switch token
		when "file", "char", "string", "tag", "url"
			'"' + normalizeStringy(value) + '"'
		when "money", "tuple", "issue", "ref", "email", "time", "pair", "date"
			'"' + value + '"'

makeBoolean = (logic) ->
	if logic.toLowerCase() in ["true", "yes", "on"]
		"true"
	else
		"false"

makeInteger = (sign, number, exp) ->
	sign = "" if sign isnt "-"
	number = number.replace /'/g, ""
	"#{sign}#{number}#{expr ? ""}"

makeHexa = (hexa) ->
	parseInt(hexa).toString()

makeFloat = (sign, ipart, fpart, exp) ->
	sign = "" if sign isnt "-"
	ipart = ipart.replace /'/g, ""
	fpart = fpart.replace /'/g, ""
	"#{sign}#{ipart}.#{fpart}#{exp ? ""}"

makeValue = (indent, token) ->
	switch
		when token.map?           then makeObject indent, token.map
		when token.block?         then makeArray indent, token.block
		when (i = token.integer)? then makeInteger i.sign, i.number, i.exp
		when token.hexa?          then makeHexa token.hexa
		when (f = token.float)?   then makeFloat f.sign, f.ipart, f.fpart, f.exp
		when token.logic?         then makeBoolean token.logic
		when token.none?          then "null"
		else                           makeString token

export default fromREON = (input) ->
	makeValue 0, nextValue new Reader input