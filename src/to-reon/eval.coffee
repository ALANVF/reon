import Token, {Value} from "./token.js"

export Param =
	val: 0
	get: 1
	lit: 2

export class ControlFlow
	class @Return
		constructor: (@value = Token.NONE) ->
	
	class @Break
		constructor: (@value = Token.NONE) ->
	
	class @Continue
		constructor: ->

export class Macro
	constructor: (@params, @body) ->
	
	# basic for now
	call: (env, tokens) ->
		args = for [kind, name] in @params
			[name, switch kind
				when Param.val
					evalNextExpr(env, tokens)
				else
					throw new Error "todo!"]
		
		return try
			tmpEnv = env.newInner(args)
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
			switch param
				when Param.val
					evalNextExpr(env, tokens)
				else
					throw new Error "todo!"
		
		return @fn(env, args)

export isMacro = (value) => value instanceof Macro

export isIntrinsic = (value) => value instanceof Intrinsic

export isAnyMacro = (value) => isMacro(value) or isIntrinsic(value)

export evalNextExpr = (env, tokens) =>
	if tokens.length is 0
		throw new Error "Unexpected end of input!"
	else
		token = tokens.shift()
		[kind, val] = token

		switch kind
			when Token.getWord
				if (value = env.get(val))?
					if isAnyMacro value 
						throw new Error "Cannot get a macro value"
					else
						value
				else
					throw new Error "Undefined word `#{val}`!"
			
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