export zip = (arr1, arr2, fn = undefined) =>
	if fn? then fn(v, arr2[i]) for v, i in arr1
	else [v, arr2[i]] for v, i in arr1

export id = (value) => value

export all = (values) => values.every id

export any = (values) => values.some id

export chunk = (values, size, fill = undefined) =>
	res = values[i...(i+size)] for _, i in values when i % size is 0

	if res.length > 0 and fill isnt undefined and res[-1].length != size
		for i in [0...size]
			res[-1][i] ?= fill
	
	res