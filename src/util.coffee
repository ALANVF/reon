export zip = (arr1, arr2, fn = undefined) =>
	if fn? then fn(v, arr2[i]) for v, i in arr1
	else [v, arr2[i]] for v, i in arr1

export id = (value) => value

export all = (values) => values.every id

export any = (values) => values.some id

export chunk = (values, size, fill = undefined) =>
	[_..., end] = res = (values[i...(i+size)] for _, i in values when i % size is 0)

	if end? and fill isnt undefined and end.length != size
		for i in [0...size]
			end[i] ?= fill
	
	res