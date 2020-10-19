export zip = (arr1, arr2, fn = null) =>
	if fn? then fn(v, arr2[i]) for v, i in arr1
	else [v, arr2[i]] for v, i in arr1

export id = (value) => value

export all = (values) => values.every id

export any = (values) => values.some id