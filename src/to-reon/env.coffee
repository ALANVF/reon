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
		if @outer?.has(word)
			@outer.set(word, value)
		else
			@env.set(word, value)
	
	newInner: (env = null) ->
		new Env
			env: env
			outer: @