import isValidPath from "is-valid-path"
import isUrl from "is-url"

literals =
	word:   /^[^\d/\\,()[\]{}"'#%$@:;][^/\\,()[\]{}"#%$@:;]*$/
	number: /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$/,
	tuple:  /^\d+(?:\.\d+){2,12}$/
	issue:  /^#[^\s@#$%^()[\]{},\\;"'<>/]+$/
	ref:    /^@[^#$@'",;=\\^/<>()[\]{}]+$/
	email:  /^[^\s:/()[\]{}]+@[^\s:/()[\]{}]+$/
	# ... finish

normalizeChar = (char) ->
	if "\x01" <= char <= "\x1A"
		hex = char.charCodeAt(0).toString(16).toUpperCase()
		if hex.length is 1
			"^(0#{hex})"
		else
			"^(#{hex})"
	else
		char

replaceEscapes = (str, multiline = false) ->
	chars =
		if multiline
			level = 0
			for char, i in str
				switch char
					when "^" then "^^"
					when "\t"   then "\t"
					when "\n"   then "\n"
					when "\r"   then "\r"
					when "\0"   then "^@"
					when "\b"   then "^(back)"
					when "\x0C" then "^(page)"
					when "\x1B" then "^["
					when "\x1C" then "^\\"
					when "\x1D" then "^]"
					when "\x1E" then "^(1E)"
					when "\x1F" then "^_"
					when "\x7F" then "^~"
					when "}"
						if level is 0
							"^}"
						else
							level--
							"}"
					
					when "{"
						nestedLevel = level + 1
						j = i + 1
						
						while nestedLevel > 0 and j < str.length
							switch str[j++]
								when "{" then nestedLevel++
								when "}" then nestedLevel--
						
						if nestedLevel <= 0
							level++	
							"{"
						else
							"^{"
					
					else normalizeChar char
		else
			for char in str
				switch char
					when "^"    then "^^"
					when '"'    then '^"'
					when "\t"   then "^-"
					when "\n"   then "^/"
					when "\0"   then "^@"
					when "\b"   then "^(back)"
					when "\x0C" then "^(page)"
					when "\x1B" then "^["
					when "\x1C" then "^\\"
					when "\x1D" then "^]"
					when "\x1E" then "^(1E)"
					when "\x1F" then "^_"
					when "\x7F" then "^~"
					else normalizeChar char
	
	chars.join ""

isValidFile = (str) ->
	("/" in str isnt ("\\" in str and str[0] isnt "\\")) and
	not str.match(/\s|\\\\|\/\//) and
	isValidPath str

buildObject = (object, indent) ->
	return "#()" if Object.keys(object).length is 0

	tabs = "\t".repeat indent + 1
	pairs = for k, v of object
		key = switch
			# tuple!
			when k.match literals.tuple then k
			
			# issue!
			when k.match literals.issue then k
			
			# ref!
			when k.match literals.ref then k

			# email!
			when k.match literals.email then k

			# url!
			when isUrl k then k

			# file!
			when isValidFile k then "%#{k}"

			# ... finish later

			# word!
			when k.match literals.word then "#{k}:"

			# number!
			when k.match literals.number then k
			
			else "\"#{replaceEscapes k}\""
		
		"\n#{tabs}#{key} #{buildValue v, indent + 1}"
	
	"#(#{pairs.join ""}\n#{"\t".repeat indent})"
	

buildArray = (array, indent) ->
	return "[]" if array.length is 0

	values = for value in array
		buildValue value, indent + 1
	
	if values.length > 10 or values.some (str) => "\n" in str or str.length > 80
		tabs = "\t".repeat indent + 1
		values = for value in values
			"\n" + tabs + value
		
		"[#{values.join ""}\n#{"\t".repeat indent}]"
	else
		"[#{values.join " "}]"

buildBoolean = (bool) ->
	if bool then "true" else "false"

buildNull = () ->
	"none"

buildNumber = (number) ->
	number.toString()

buildString = (string, indent) ->
	switch
		# tuple!
		when string.match literals.tuple then string
			
		# issue!
		when string.match literals.issue then string
		
		# ref!
		when string.match literals.ref then string

		# email!
		when string.match literals.email then string

		# url!
		when isUrl string then string

		# file!
		when isValidFile string then "%#{string}"

		# ... finish later

		when string.match(/\n {2,}/) or string.match(/\n\t+/)
			"{#{replaceEscapes string, true}}"

		else "\"#{replaceEscapes string}\""

buildValue = (value, indent) ->
	if value is null
		buildNull()
	else
		switch value.constructor
			when Boolean then buildBoolean value
			when Number then buildNumber value
			when String then buildString value, indent
			when Array then buildArray value, indent
			else buildObject value, indent

export default toREON = (json) ->
	buildObject json, 0