export default Token = do =>
	i = 0
	datatype: i++
	none: i++
	logic: i++
	word: i++
	litWord: i++
	getWord: i++
	setWord: i++
	integer: i++
	hexa: i++
	float: i++
	money: i++
	tuple: i++
	issue: i++
	ref: i++
	email: i++
	url: i++
	file: i++
	time: i++
	pair: i++
	date: i++
	char: i++
	tag: i++
	string: i++
	block: i++
	map: i++
	paren: i++

export class Datatypes
	@names = [
		"datatype!"
		"none!"
		"logic!"
		"word!"
		"lit-word!"
		"get-word!"
		"set-word!"
		"integer!"
		"hexa!"
		"float!"
		"money!"
		"tuple!"
		"issue!"
		"ref!"
		"email!"
		"url!"
		"file!"
		"time!"
		"pair!"
		"date!"
		"char!"
		"tag!"
		"string!"
		"block!"
		"map!"
		"paren!"
	]
	@tokens = (Token[name] for name in @names)
	@datatypes = ([Token.datatype, k] for k in @tokens)

	@tokenName: (tokenK) -> @names[tokenK]

	@tokenType: (tokenK) -> @datatypes[tokenK]


export Value = do =>
	_Value = {}
	for name, val of Token
		do(val) =>
			_Value[name] = (value) => [val, value]
	_Value.NONE = _Value.none null
	_Value

export Typesets = do =>
	anyString = (Token[n] for n in ["ref", "email", "url", "file", "tag", "string"])
	series = [anyString..., Token.block, Token.paren]
	
	anyWord: [Token.word, Token.litWord, Token.getWord, Token.setWord]
	anyString: anyString
	series: series
	seriesLike: [series..., Token.map]
	otherStringy: [Token.money, Token.tuple, Token.issue, Token.time, Token.pair, Token.date]

export nameOfToken = (token) =>
	name = Object.keys(Token)[token]
	rx = /[A-Z]/

	while rx.exec name
		name = name.replace(rx, (l) => "-" + l.toLowerCase())
	
	name + "!"