export default Token =
	none: 0
	logic: 1
	word: 2
	litWord: 3
	getWord: 4
	setWord: 5
	integer: 6
	hexa: 7
	float: 8
	money: 9
	tuple: 10
	issue: 11
	ref: 12
	email: 13
	url: 14
	file: 15
	time: 16
	pair: 17
	date: 18
	char: 19
	tag: 20
	string: 21
	block: 22
	map: 23
	paren: 24

export Value = do =>
	_Value = {}
	for name, val of Token
		do(val) =>
			_Value[name] = (value) => [val, value]
	_Value.NONE = _Value.none null
	_Value

export class Typesets
	@anyWord = [Token.word, Token.litWord, Token.getWord, Token.setWord]
	@anyString = (Token[n] for n in ["ref", "email", "url", "file", "tag", "string"])
	@series = [@anyString..., Token.block, Token.paren]
	@otherStringy = [Token.money, Token.tuple, Token.issue, Token.time, Token.pair, Token.date]

export nameOfToken = (token) =>
	name = Object.keys(Token)[token]
	rx = /[A-Z]/

	while rx.exec name
		name = name.replace(rx, (l) => "-" + l.toLowerCase())
	
	name + "!"