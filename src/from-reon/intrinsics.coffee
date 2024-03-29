import assert from "assert"
import * as Util from "../util.js"
import Token, {Datatypes, Value, Typesets, nameOfToken} from "./token.js"
import {Param, ControlFlow, Macro, Intrinsic, isAnyMacro, evalNextExpr, evalTokens} from "./eval.js"


### Tokenization ###

tokenize = null

export setTokenizeFunction = (fn) =>
	tokenize = fn


### Type-checking ###

unexpectedToken = (tokenK) =>
	throw new TypeError "Unexpected #{nameOfToken tokenK}!"

expectToken = (valueK, kinds...) =>
	if valueK not in kinds
		unexpectedToken valueK

expectValue = ([valueK, _], kinds...) =>
	expectToken valueK, kinds...


### Core ###

$macro = (_, [[paramsK, paramsV], [bodyK, bodyV]]) =>
	expectToken paramsK, Token.block
	expectToken bodyK,   Token.block

	params = []
	locals = []
	
	for [paramK, paramV] in paramsV
		switch paramK
			when Token.word    then params.push [Param.val, paramV]
			when Token.getWord then params.push [Param.get, paramV]
			when Token.litWord then params.push [Param.lit, paramV]
			when Token.setWord then locals.push paramV
			else                    unexpectedToken paramK

	new Macro params, locals, [bodyV...]

$type_q = (_, [[valueK, __]]) =>
	Datatypes.tokenType valueK

$type_q_word = (_, [[valueK, __]]) =>
	Value.litWord Datatypes.tokenName valueK

$value_q = (env, [[wordK, word]]) =>
	expectToken wordK, Token.word, Token.litWord

	Value.logic env.has word

$get = (env, [[wordK, word]]) =>
	expectToken wordK, Token.word, Token.litWord

	if env.has word
		value = env.get word

		if isAnyMacro value
			throw new Error "Cannot get macro! values"
		else
			value
	else
		throw new Error "Word `#{word}` doesn't exist!"

$set = (env, [[wordK, word], value]) =>
	expectToken wordK, Token.word, Token.litWord, Token.block

	if wordK is Token.block
		words = word

		Value.block(if isAnyMacro(value) or value[0] isnt Token.block
						for [wordK, word] in words
							expectToken wordK, Token.word, Token.litWord
							env.set(word, value)
					else
						$set(env, word, value[1][i]) for word, i in words)
	else
		env.set(word, value)


### Evaluation ###

$reduce = (env, [value]) =>
	if value[0] is Token.block
		[_, [tokens...]] = value

		values = while tokens.length > 0
			evalNextExpr(env, tokens)

		[Token.block, values]
	else
		value

# acts like compose/only
$compose = (env, [value]) =>
	expand = (val) =>
		if val[0] is Token.paren
			evalTokens env, val[1]
		else
			val

	do([valueK, valueV] = value) => switch valueK
		when Token.block then [valueK, expand(elem) for elem in valueV]
		when Token.map   then [valueK, pair.map(expand) for pair in valueV]
		else                  value

# acts like compose/only/deep
$compose_deep = (env, [value]) =>
	expand = (val) =>
		$compose_deep env, [val]
	
	do([valueK, valueV] = value) => switch valueK
		when Token.block then [valueK, expand(elem) for elem in valueV]
		when Token.map   then [valueK, pair.map(expand) for pair in valueV]
		when Token.paren then evalTokens env, valueV
		else                  value

#$load = (env, [value])

$do = (env, [value]) =>
	do([valueK, valueV] = value) => switch valueK
		when Token.block, Token.paren then evalTokens env, valueV
		when Token.string             then evalTokens env, tokenize valueV
		else                               value

$do_next = (env, [value, [wordK, wordV]]) =>
	expectToken wordK, Token.word, Token.litWord

	do_next = (tokens) =>
		res = evalNextExpr env, tokens
		env.set wordV, Value.block tokens # FIX: this breaks when target word already exists (?)
		res

	do([valueK, valueV] = value) => switch valueK
		when Token.block, Token.paren then do_next [valueV...]
		when Token.string then do_next tokenize valueV
		else value


### Accessing ###

mapFindPair = (map, key) =>
	if key[0] in Typesets.anyWord
		key = [Token.word, key[1]]

	for pair in map
		[kK, kV] = k = pair[0]

		if kK in Typesets.anyWord
			k = [Token.word, kV]
		
		if $strict_equal_q(null, [k, key])[1]
			return pair
	
	null

$pick = (env, [[valueK, valueV], index]) =>
	do([indexK, indexV] = index) =>
		if valueK in Typesets.anyString
			expectToken indexK, Token.integer
			if (char = valueV.charCodeAt(indexV))?
				Value.char char
			else
				Value.NONE
		else switch valueK
			when Token.block, Token.paren
				expectToken indexK, Token.integer
				valueV[indexV] ? Value.NONE
			when Token.map
				# todo: validate key
				if (pair = mapFindPair(valueV, index))? then pair[1]
				else Value.NONE
			when Token.pair, Token.time, Token.date, Token.tuple
				throw "todo!"
			else
				unexpectedToken tokenK


### Copying ###

$copy = (_, [[valueK, valueV]]) =>
	[valueK, switch valueK
		when Token.paren, Token.block then [valueV...]
		when Token.map then pair for [pair...] in valueV
		else valueV]

$copy_deep = (_, [value]) =>
	copy_deep = ([valueK, valueV]) =>
		[valueK, switch valueK
			when Token.paren, Token.block then valueV.map(copy_deep)
			when Token.map then pair.map(copy_deep) for pair in valueV
			else valueV]
	
	copy_deep value

getPair = (pair) =>
	p = pair.split /x/i
	p[0] = +p[0]
	p[1] = +p[1]
	p

$copy_part = (_, [[valueK, valueV], [lengthK, lengthV]]) =>
	expectToken valueK, Typesets.series...
	expectToken lengthK, Token.integer, Token.pair
	
	[valueK, switch lengthK
		when Token.integer then valueV.slice 0, Math.max(0, lengthV)
		else
			[x, y] = getPair lengthV
			valueV.slice Math.max(0, x), Math.max(0, y)]


### Logic ###

toLogic = ([valueK, valueV]) =>
	switch valueK
		when Token.none  then false
		when Token.logic then valueV
		else                  true

$not = (_, [value]) =>
	Value.logic not toLogic value

$and = (_, [left, right]) =>
	expectValue right, left[0]

	switch left[0]
		when Token.logic then Value.logic(toLogic(left) and toLogic(right))
		else throw "todo!"

$or = (_, [left, right]) =>
	expectValue right, left[0]

	switch left[0]
		when Token.logic then Value.logic(toLogic(left) or toLogic(right))
		else throw "todo!"

$xor = (_, [left, right]) =>
	expectValue right, left[0]

	switch left[0]
		when Token.logic then Value.logic(toLogic(left) isnt toLogic(right))
		else throw "todo!"


### Relational ###

#$equal

$lesser_q = (_, [[leftK, leftV], [rightK, rightV]]) =>
	Value.logic(switch leftK
		when Token.integer, Token.hexa, Token.float, Token.char then switch rightK
			when Token.integer, Token.hexa, Token.float, Token.char then leftV < rightV
			else throw "todo!"
		else throw "todo!")


# basic for now
$strict_equal_q = (_, [left, right]) =>
	strict_equal_q = ([leftK, leftV], [rightK, rightV]) =>
		leftK is rightK and switch leftK
			when Token.none then true
			when Token.block, Token.paren
				leftV.length is rightV.length and
					Util.all Util.zip(leftV, rightV, strict_equal_q)
			when Token.map
				leftV.length is rightV.length and
					Util.all Util.zip(leftV, rightV, ([k1, v1], [k2, v2]) =>
						strict_equal_q(k1, k2) and strict_equal_q(v1, v2))
			else # todo: make this better
				leftV is rightV
	
	Value.logic strict_equal_q(left, right)

$same_q = (_, [left, right]) =>
	Value.logic do ([leftK, leftV] = left, [rightK, rightV] = right) =>
		if leftK is rightK
			if leftK in Typesets.seriesLike then left is right
			else leftV is rightV


### Control flow ###

$if = (env, [value, [bodyK, bodyV]]) =>
	expectToken bodyK, Token.block
	
	if toLogic value
		evalTokens env, bodyV
	else
		Value.NONE

$either = (env, [value, [thenK, thenV], [elseK, elseV]]) =>
	expectToken thenK, Token.block
	expectToken elseK, Token.block

	evalTokens env, (if toLogic value then thenV else elseV)

$while = (env, [[valueK, valueV], [bodyK, bodyV]]) =>
	expectToken valueK, Token.block
	expectToken bodyK, Token.block

	res = Value.NONE

	while toLogic evalTokens(env, valueV)
		try
			res = evalTokens(env, bodyV)
		catch e then switch
			when e instanceof ControlFlow.Continue then continue
			when e instanceof ControlFlow.Break then return e.value
			else throw e
	
	res

$foreach = (env, [[wordK, wordV], [seriesK, seriesV], [bodyK, bodyV]]) =>
	expectToken wordK, Token.word, Token.litWord, Token.block
	expectToken seriesK, Typesets.seriesLike...
	expectToken bodyK, Token.block

	word =
		if wordK isnt Token.block then wordV
		else
			words = for [k, v] in wordV
				expectToken k, Token.word, Token.litWord
				v
			
			if words.length is 1 then words[0]
			else words

	elements = switch seriesK
		when Token.block, Token.paren then seriesV
		when Token.map
			if typeof word is "string" then k for [k, _] in seriesV
			else [].concat(seriesV...)
		else Value.char(c.charCodeAt 0) for c in seriesV
	
	res = Value.NONE

	if typeof word is "string"
		for elem in elements
			env.set(word, elem)
			
			try
				res = evalTokens env, bodyV
			catch e then switch
				when e instanceof ControlFlow.Continue then continue
				when e instanceof ControlFlow.Break then return e.value
				else throw e
	else
		words = word
		
		for elems in Util.chunk(elements, words.length, Value.NONE)
			for [word, elem] in Util.zip(words, elems)
				env.set(word, elem)
			
			try
				res = evalTokens env, bodyV
			catch e then switch
				when e instanceof ControlFlow.Continue then continue
				when e instanceof ControlFlow.Break then return e.value
				else throw e
	
	res


$return = (_, [value]) =>
	throw new ControlFlow.Return value

$exit = (_, []) =>
	throw new ControlFlow.Return

$break = (_, []) =>
	throw new ControlFlow.Break

$break_return = (_, [value]) =>
	throw new ControlFlow.Break value

$continue = (_, []) =>
	throw new ControlFlow.Continue


### Conversion ###

toInteger = ([valueK, valueV]) =>
	expectToken valueK, Token.integer, Token.float, Token.hexa, Token.char, Token.string, Token.ref..., Typesets.otherStringy...
	
	switch valueK
		when Token.integer, Token.hexa, Token.char then valueV
		when Token.float then Math.floor valueV
		when Token.string, Token.ref, Token.issue then Number.parseInt valueV, 10
		else throw "todo!"

toFloat = ([valueK, valueV]) =>
	expectToken valueK, Token.integer, Token.float, Token.hexa, Token.char, Token.string, Token.ref..., Typesets.otherStringy...
	
	switch valueK
		when Token.integer, Token.float, Token.hexa, Token.char then valueV
		when Token.string, Token.ref, Token.issue then Number.parseFloat valueV
		else throw "todo!"

toHexa = ([valueK, valueV]) =>
	expectToken valueK, Token.integer, Token.float, Token.hexa, Token.char, Token.string, Token.ref..., Typesets.otherStringy...
	
	val = switch valueK
		when Token.integer, Token.hexa, Token.char then valueV
		when Token.float then Math.floor valueV
		when Token.string, Token.ref, Token.issue then Number.parseInt valueV, 16
		else throw "todo!"
	
	assert val >= 0, "hexa! value cannot be negative"
	val

toChar = ([valueK, valueV]) =>
	expectToken valueK, Token.integer, Token.float, Token.hexa, Token.char, Typesets.anyString...

	switch valueK
		when Token.integer
			assert valueV >= 0, "Out of bounds"
			valueV
		when Token.float
			assert valueV >= 0, "Out of bounds"
			Math.floor valueV
		when Token.hexa, Token.char then valueV
		else
			assert valueV.length > 0, "Invalid arg"
			valueV.charCodeAt 0

toBlock = ([valueK, valueV]) => switch valueK
	when Token.map then [].concat(valueV...)
	when Token.string then tokenize valueV
	when Token.block, Token.paren then [valueV...]
	else [valueV]

toMap = ([valueK, valueV]) =>
	expectToken valueK, Token.map, Token.block, Token.paren

	if valueK is Token.map then ([k, v] for [k, v] in valueV)
	else
		assert valueV.length % 2
		Util.chunk(valueV, 2)

stringToWord = (string, rx) =>
	word = string.trim()
	assert rx.exec word
	word

charToWord = (char, rx) =>
	word = String.fromCharCode char
	assert rx.exec word
	word

toWord = ([valueK, valueV]) =>
	expectToken valueK, Typesets.anyWord..., Token.issue, Token.string, Token.char, Token.datatype, Token.logic

	if valueK in Typesets.anyWord then valueV
	else switch valueK
		when Token.issue, Token.ref
			assert valueV[0].match /^\D/
			valueV
		when Token.string then stringToWord valueV, /^[^\d/\\,()[\]{}"'#%$@:;\s][^/\\,()[\]{}"#%$@:;\s]*$/
		when Token.char then charToWord valueV, /[^\d/\\,()[\]{}"'#%$@:;\s]/
		when Token.datatype then Datatypes.tokenName valueV
		else "#{valueV}"

toIssue = (value) => do([valueK, valueV] = value) => switch valueK
	when Token.string then stringToWord valueV, /^[^\s@#$%^()[\]{},\\;"<>/]+$/
	when Token.char then charToWord valueV, /[^\s@#$%^()[\]{},\\;"<>/]/
	else toWord

toRef = (value) => do([valueK, valueV] = value) => switch valueK
	when Token.string then stringToWord valueV, /^[^\s#$@",;=\\^/<>()[\]{}]+$/
	when Token.char then charToWord valueV, /[^\s#$@",;=\\^/<>()[\]{}]/
	else toWord

_toString = (value) => do([valueK, valueV] = value) => switch valueK
	when Token.block, Token.paren then valueV.map(form).join("")
	else form value


$to = (_, [target, value]) =>
	do([targetK, targetV] = target) =>
		datatype = if targetK is Token.datatype then targetV else targetK
		[datatype, switch datatype
			when Token.none then null
			when Token.logic then toLogic value
			when Token.word, Token.litWord, Token.getWord, Token.setWord then toWord value
			when Token.issue then toIssue value
			when Token.ref then toRef value
			when Token.integer then toInteger value
			when Token.float then toFloat value
			when Token.hexa then toHexa value
			when Token.char then toChar value
			when Token.string then _toString value
			when Token.block, Token.paren then toBlock value
			when Token.map then toMap value
			# ...
			else throw "todo!"
		]


### Math (maybe) ###

Op = do =>
	i = 0
	add: i++
	sub: i++

math = ([leftK, leftV], [rightK, rightV], op) =>
	expectToken leftK, Token.integer, Token.hexa, Token.float, Token.char, Token.money, Token.tuple, Token.time, Token.pair, Token.date
	expectToken rightK, Token.integer, Token.hexa, Token.float, Token.char, Token.money, Token.tuple, Token.time, Token.pair, Token.date

	defaultOp = (l, r) => switch op
		when Op.add then l + r
		when Op.sub then l - r
		else throw "error!"

	checkUnderflow = (value) =>
		assert value >= 0
		value

	switch leftK
		when Token.integer, Token.float, Token.hexa then switch rightK
			when Token.integer, Token.hexa, Token.float, Token.char then [leftK, defaultOp(leftV, rightV)]
			else throw "todo!"
		when Token.char then Value.char checkUnderflow switch rightK
			when Token.integer, Token.hexa, Token.char then defaultOp(leftV, rightV)
			when Token.float then defaultOp(leftV, Math.floor rightV)
			else throw "todo!"
		else throw "todo!"

$add = (_, [left, right]) =>
	math left, right, Op.add

$subtract = (_, [left, right]) =>
	math left, right, Op.sub


### Strings ###

# basic for now
form = ([valueK, valueV]) =>
	if valueK in [Typesets.anyString..., Typesets.anyWord..., Typesets.otherStringy...] then valueV
	else switch valueK
		when Token.none then "none"
		when Token.logic, Token.integer, Token.float then "#{valueV}"
		when Token.block, Token.paren then valueV.map(form).join(" ")
		when Token.char then String.fromCharCode valueV
		else throw "todo!"

$form = (_, [value]) =>
	Value.string form value

#$mold


### Series ###

$length_q = (_, [[seriesK, seriesV]]) =>
	expectToken seriesK, Typesets.seriesLike..., Token.tuple, Token.none

	if seriesK is Token.none then Value.NONE
	else Value.integer(
		if seriesK isnt Token.tuple then seriesV.length
		else throw "todo!")

$skip = (_, [[seriesK, seriesV], [offsetK, offsetV]]) =>
	expectToken seriesK, Typesets.series...
	expectToken offsetK, Token.integer
	
	[seriesK, seriesV.slice offsetV]

$append = (env, [series, value]) =>
	expectValue series, Typesets.series...

	do([seriesK, seriesV] = series, [valueK, valueV] = value) =>
		if seriesK in Typesets.anyString
			series[1] +=
				if valueK in Typesets.anyString then valueV
				else $form(env, [value])[1]
		else
			seriesV.push value

	series

###
$insert_at = (env, [series, [indexK, indexV], value]) =>
	expectValue series, Typesets.series...
	expectToken indexK, Token.integer

	do([seriesK, seriesV] = series, [valueK, valueV] = value) =>
		if seriesK in Typesets.anyString
			str =
				if valueK in Typesets.anyString then valueV
				else $form(env, [value])[1]
			
			series[1] = seriesV[...indexV] + str + seriesV[indexV..]
		else
			seriesV.splice indexV, 0, value

	series
###


### Maps ###

$extend = (_, [[mapK, mapV], key, value]) =>
	expectToken mapK, Token.map

	if (pair = mapFindPair(mapV, key))?
		pair[1] = value
	else
		mapV.push [key, value]

	value


### Intrinsics ###

{val: PVal, get: PGet, lit: PLit} = Param

export default Intrinsics =
	macro: new Intrinsic [PVal, PVal], $macro
	"type?": new Intrinsic [PVal], $type_q
	"type?.word": new Intrinsic [PVal], $type_q_word
	"value?": new Intrinsic [PVal], $value_q
	get: new Intrinsic [PVal], $get
	set: new Intrinsic [PVal, PVal], $set
	reduce: new Intrinsic [PVal], $reduce
	compose: new Intrinsic [PVal], $compose
	"compose.deep": new Intrinsic [PVal], $compose_deep
	do: new Intrinsic [PVal], $do
	"do.next": new Intrinsic [PVal, PVal], $do_next
	pick: new Intrinsic [PVal, PVal], $pick
	copy: new Intrinsic [PVal], $copy
	"copy.deep": new Intrinsic [PVal], $copy_deep
	"copy.part": new Intrinsic [PVal, PVal], $copy_part
	not: new Intrinsic [PVal], $not
	and: new Intrinsic [PVal, PVal], $and
	or: new Intrinsic [PVal, PVal], $or
	xor: new Intrinsic [PVal, PVal], $xor
	"lesser?": new Intrinsic [PVal, PVal], $lesser_q
	"strict-equal?": new Intrinsic [PVal, PVal], $strict_equal_q
	"same?": new Intrinsic [PVal, PVal], $same_q
	"if": new Intrinsic [PVal, PVal], $if
	either: new Intrinsic [PVal, PVal, PVal], $either
	"while": new Intrinsic [PVal, PVal], $while
	foreach: new Intrinsic [PLit, PVal, PVal], $foreach
	"return": new Intrinsic [PVal], $return
	exit: new Intrinsic [], $exit
	"break": new Intrinsic [], $break
	"break.return": new Intrinsic [PVal], $break_return
	"continue": new Intrinsic [], $continue
	to: new Intrinsic [PVal, PVal], $to
	add: new Intrinsic [PVal, PVal], $add
	subtract: new Intrinsic [PVal, PVal], $subtract
	form: new Intrinsic [PVal], $form
	"length?": new Intrinsic [PVal], $length_q
	skip: new Intrinsic [PVal, PVal], $skip
	append: new Intrinsic [PVal, PVal], $append
	#"insert-at": new Intrinsic [PVal, PVal, PVal], $insert_at
	extend: new Intrinsic [PVal, PVal, PVal], $extend