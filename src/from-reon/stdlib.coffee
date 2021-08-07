export default STDLIB = '''\
;-- Things that should probably be natives

all: macro [conds res:][
	res: true
	
	while [not empty? conds][
		if not res: do.next conds 'conds [
			return none
		]
	]

	return res
]

any: macro [conds res:][
	while [not empty? conds][
		if res: do.next conds 'conds [
			return res
		]
	]

	return none
]

case: macro [cases][
	while [not empty? cases][
		either do.next cases 'cases [
			return either block? first cases [do first cases][first cases]
		][
			cases: skip cases 1
		]
	]

	return none
]

case.all: macro [cases res:][
	while [not empty? cases][
		either do.next cases 'cases [
			res: either block? first cases [do first cases][first cases]
		][
			cases: skip cases 1
		]
	]
	
	return res
]

switch: macro [value cases][
	switch.default value cases []
]

switch.default: macro [value cases default conds:][
	while [not empty? cases][
		conds: copy []

		while [not or empty? cases block? first cases][
			append conds first cases
			cases: rest cases
		]

		foreach cond conds [
			if strict-equal? value cond [
				return do first cases
			]
		]
	]

	return do default
]

greater?: macro [a b][and lesser? b a not strict-equal? a b]

max: macro [a b][either lesser? b a [a][b]]
min: macro [a b][either lesser? b a [b][a]]

next: macro [series][skip series 1]


;-- Normal stdlib functions

rejoin: macro [values res:][
	res: copy ""

	foreach value reduce values [
		append res form value
	]

	return res
]

quote: macro [:v][:v]

empty?: macro [values][same? length? values 0]
single?: macro [values][same? length? values 1]

first: macro [values][pick values 0]
last: macro [values value: res:][pick values subtract length? values 1]


;-- My own additions

join-with: macro [sep values value: res:][
	res: copy ""

	if all [
		block? values
		not empty? values
	][
		append res form first values

		if not single? values [
			foreach value next values [
				append res sep
				append res value
			]
		]
	]

	return res
]
'''