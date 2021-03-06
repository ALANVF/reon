export default class Env
	constructor: ({@env = null, @outer = null}) ->
		if @env?
			if typeof @env is "object" and @env.constructor is Object
				@env = new Map([k, v] for k, v of @env)
			else
				@env = new Map @env
		else
			@env = new Map
	
	has: (word) ->
		@env.has(word) or @outer?.has(word)?
	
	get: (word) ->
		@env.get(word) ? @outer?.get(word)
	
	set: (word, value) ->
		(if @env.has(word) or @outer is null then @env else @outer).set(word, value)
		value
	
	add: (word, value) ->
		@env.set(word, value)
		value
	
	newInner: (env = null) ->
		new Env
			env: env
			outer: @