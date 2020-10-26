import Token, {Value} from "./token.js"

export Param =
	val: 0
	get: 1
	lit: 2

export class ControlFlow
	class @Return
		constructor: (@value = Value.NONE) ->
	
	class @Break
		constructor: (@value = Value.NONE) ->
	
	class @Continue
		constructor: ->

export class Macro
	constructor: (@params, locals, @body) ->
		@locals = ([name, Value.NONE] for name in locals)
	
	# basic for now
	call: (env, tokens) ->
		args = for [kind, name] in @params
			[name, evalNextExprWithQuoting(env, tokens, kind)]
		
		return try
			tmpEnv = env.newInner(args.concat @locals)
			evalTokens(tmpEnv, @body)
		catch e
			switch
				when e instanceof ControlFlow.Return   then e.value
				when e instanceof ControlFlow.Break    then throw new Error "Unhandled break!"
				when e instanceof ControlFlow.Continue then throw new Error "Unhandled continue!"
				else                                        throw e

export class Intrinsic
	constructor: (@params, @fn) ->

	call: (env, tokens) ->
		args = for param in @params
			evalNextExprWithQuoting env, tokens, param
		
		return @fn(env, args)

export isMacro = (value) => value instanceof Macro

export isIntrinsic = (value) => value instanceof Intrinsic

export isAnyMacro = (value) => isMacro(value) or isIntrinsic(value)

notEmpty = (tokens) =>
	if tokens.length is 0
		throw new Error "Unexpected end of input!"

mustGetWord = (env, word) =>
	if (value = env.get(word))?
		if isAnyMacro value 
			throw new Error "Cannot get a macro value"
		else
			value
	else
		throw new Error "Undefined word `#{word}`!"

export evalNextExprWithQuoting = (env, tokens, quoting) =>
	notEmpty tokens
	switch quoting
		when Param.val then evalNextExpr env, tokens
		when Param.get then tokens.shift()
		else
			[kind, val] = token = tokens.shift()

			switch kind
				when Token.paren then evalTokens env, val
				when Token.getWord then mustGetWord val
				else token

export evalNextExpr = (env, tokens) =>
	notEmpty tokens

	[kind, val] = token = tokens.shift()

	switch kind
		when Token.getWord
			mustGetWord env, val
		
		when Token.setWord
			env.set(val, evalNextExpr(env, tokens))
		
		when Token.word
			if (value = env.get(val))?
				if isAnyMacro value
					value.call(env, tokens)
				else
					value
			else
				throw new Error "Undefined word `#{val}`!"
		
		when Token.paren
			evalTokens(env, val)
		
		else
			token

export evalTokens = (env, [tokens...]) =>
	if tokens.length is 0
		throw new Error "Unexpected end of input!"
	else
		res = Value.NONE

		while tokens.length > 0
			res = evalNextExpr(env, tokens)
		
		res

###
export reduceTokens = (env, [tokens...]) ->
	while tokens.length > 0
		evalNextExpr(env, tokens)
###