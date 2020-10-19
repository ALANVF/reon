import * as Util from "../util.js"
import Token, {Value, Typesets, nameOfToken} from "./token.js"
import {Param, ControlFlow, Macro, Intrinsic, isAnyMacro, evalNextExpr, evalTokens} from "./eval.js"

unexpectedToken = (tokenK) =>
	throw new TypeError "Unexpected #{nameOfToken tokenK}!"

expectToken = (valueK, kinds...) =>
	if valueK not in kinds
		unexpectedToken valueK

expectValue = ([valueK, _], kinds...) =>
	expectToken valueK, kinds...

class TypeMappings
	@mappings = [
		[Token.none,    "none!"]
		[Token.logic,   "logic!"]
		[Token.word,    "word!"]
		[Token.litWord, "lit-word!"]
		[Token.getWord, "get-word!"]
		[Token.setWord, "set-word!"]
		[Token.integer, "integer!"]
		[Token.hexa,    "hexa!"]
		[Token.float,   "float!"]
		[Token.money,   "money!"]
		[Token.tuple,   "tuple!"]
		[Token.issue,   "issue!"]
		[Token.ref,     "ref!"]
		[Token.email,   "email!"]
		[Token.url,     "url!"]
		[Token.file,    "file!"]
		[Token.time,    "time!"]
		[Token.pair,    "pair!"]
		[Token.date,    "date!"]
		[Token.char,    "char!"]
		[Token.tag,     "tag!"]
		[Token.string,  "string!"]
		[Token.block,   "block!"]
		[Token.map,     "map!"]
		[Token.paren,   "paren!"]
	]
	@tokenToName = new Map @mappings
	@nameToToken = new Map([n, k] for [k, n] in @mappings)

	@name: (tokenK) -> @tokenToName.get(tokenK)

	@token: (name) -> @nameToToken.get(name)


### Core ###

$macro = (_, [[paramsK, params], [bodyK, body]]) =>
	expectToken paramsK, Token.block
	expectToken bodyK,   Token.block

	params = for [paramK, param] in params
		switch paramK
			when Token.word    then [Param.val, param]
			when Token.getWord then [Param.get, param]
			when Token.litWord then [Param.lit, param]
			else               unexpectedToken paramK

	new Macro params, [body...]

$type_word = (_, [[valueK, __]]) =>
	Value.litWord TypeMappings.name valueK

$value_q = (env, [[wordK, word]]) =>
	expectToken wordK, Token.word, Token.litWord#, ...any-string!

	Value.logic env.has word

$get = (env, [[wordK, word]]) =>
	expectToken wordK, Token.word, Token.litWord#, ...any-string!

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


### Evaluation ###

#$reduce = (env, [value])

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
	switch value[0]
		when Token.block, Token.paren then evalTokens env, value[1]
		when Token.string             then throw "todo!"
		else                               value

$do_next = (env, [value, [wordK, wordV]]) =>
	expectToken wordK, Token.word, Token.litWord

	do([valueK, valueV] = value) => switch valueK
		when Token.block, Token.paren
			tokens = [valueV...]
			res = evalNextExpr env, tokens
			env.set wordV, [valueK, tokens]
			res
		when Token.string
			throw "todo!"
		else
			value


### Accessing ###

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
				#valueV.find(([k, _]) => $strict_equal_q(env, [k, index])[1])?[1] ? Value.NONE
				if index[0] in Typesets.anyWord
					index = [Token.word, index[1]]

				for [k, v] in valueV
					if k[0] in Typesets.anyWord
						k = [Token.word, k[1]]
					
					if $strict_equal_q(env, [k, index])[1]
						return v
				Value.NONE
			when Token.pair, Token.time, Token.date, Token.tuple
				throw "todo!"
			else
				unexpectedToken tokenK

### Copying ###

$copy = (_, [[valueK, valueV]]) =>
	[valueK, switch valueK
		when Token.paren, Token.block then [valueV...]
		when Token.map then pair for [pair...] in valueV
		else
			if valueK in Typesets.anyString
				throw "todo!"
			else
				valueV]

# FIX
$copy_deep = (_, [[valueK, valueV]]) =>
	[valueK, switch valueK
		when Token.paren, Token.block then valueV.map($copy_deep)
		when Token.map then pair.map($copy_deep) for pair in valueV
		else
			if valueK in Typesets.anyString
				throw "todo!"
			else
				valueV]


### Logic ###

toLogic = ([valueK, valueV]) =>
	switch valueK
		when Token.none  then false
		when Token.logic then valueV
		else                  true

$not = (_, [value]) =>
	Value.logic toLogic value

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

#$lesser

#$lesser_or_equal

# basic for now
$strict_equal_q = (_, [left, right]) =>
	strict_equal_q = ([leftK, leftV], [rightK, rightV]) =>
		Value.logic(leftK is rightK and switch leftK
			when Token.none then true
			when Token.block, Token.paren
				leftV.length is rightV.length and
					Util.all Util.zip(leftV, rightV, strict_equal_q)
			when Token.map
				leftV.length is rightV.length and
					Util.all Util.zip(leftV, rightV, ([k1, v1], [k2, v2]) =>
						strict_equal_q(k1, k2) and strict_equal_q(v1, v2))
			else # todo: make this better
				leftV is rightV)
	
	strict_equal_q left, right

$same_q = (_, [left, right]) =>
	Value.logic(left is right)


### Control flow ###

$if = (env, [value, [bodyK, bodyV]]) =>
	expectToken bodyK, Token.block
	
	if toLogic value
		evalTokens env, bodyV
	else
		Token.NONE

$either = (env, [value, [thenK, thenV], [elseK, elseV]]) =>
	expectToken thenK, Token.block
	expectToken elseK, Token.block

	evalTokens env, (if toLogic value then thenV else elseV)

$while = (env, [[valueK, valueV], [bodyK, bodyV]]) =>
	expectToken valueK, Token.block
	expectToken bodyK, Token.block

	res = Token.NONE

	while toLogic evalTokens(env, valueV)
		try
			res = evalTokens(env, bodyV)
		catch e then switch
			when e instanceof ControlFlow.Continue then continue
			when e instanceof ControlFlow.Break
				res = e.value ? Token.NONE 
				break
			else
				throw e
	
	res

$return = (_, [value]) =>
	throw new ControlFlow.Return value

$exit = (_, __) =>
	throw new ControlFlow.Return

$break = (_, __) =>
	throw new ControlFlow.Break

$break_return = (_, [value]) =>
	throw new ControlFlow.Break value

$continue = (_, __) =>
	throw new ControlFlow.Continue value


### Conversion ###


### Math (maybe) ###


### Strings ###

# basic for now
$form = (_, value) =>
	form = ([valueK, valueV]) =>
		if valueK in Typesets.anyString.concat(Typesets.anyWord) then valueV
		else switch valueK
			when Token.none then "none"
			when Token.logic, Token.integer, Token.float then "#{valueV}"
			when Token.block, Token.paren then valueV.map(form).join(" ")
			else throw "todo!"
	
	Value.string form value

#$mold


### Series ###


### Intrinsics ###

{val: PVal, get: PGet, lit: PLit} = Param

export default Intrinsics =
	macro: new Intrinsic [PVal, PVal], $macro
	"type.word": new Intrinsic [PVal], $type_word
	"value?": new Intrinsic [PVal], $value_q
	get: new Intrinsic [PVal], $get
	set: new Intrinsic [PVal, PVal], $set
	compose: new Intrinsic [PVal], $compose
	"compose.deep": new Intrinsic [PVal], $compose_deep
	do: new Intrinsic [PVal], $do
	"do.next": new Intrinsic [PVal, PVal], $do_next
	pick: new Intrinsic [PVal, PVal], $pick
	copy: new Intrinsic [PVal], $copy
	"copy.deep": new Intrinsic [PVal], $copy_deep
	not: new Intrinsic [PVal], $not
	and: new Intrinsic [PVal, PVal], $and
	or: new Intrinsic [PVal, PVal], $or
	xor: new Intrinsic [PVal, PVal], $xor
	"strict-equal?": new Intrinsic [PVal, PVal], $strict_equal_q
	"same?": new Intrinsic [PVal, PVal], $same_q
	"if": new Intrinsic [PVal, PVal], $if
	either: new Intrinsic [PVal, PVal, PVal], $either
	"while": new Intrinsic [PVal, PVal], $while
	"return": new Intrinsic [PVal], $return
	exit: new Intrinsic [], $exit
	"break": new Intrinsic [], $break
	"break.return": new Intrinsic [PVal], $break_return
	"continue": new Intrinsic [], $continue
	form: new Intrinsic [PVal], $form