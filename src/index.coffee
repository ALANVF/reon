import fs from "fs"
import path from "path"
import toREON from "./to-reon.js"
import fromREON from "./from-reon.js"


getOptions = (args, rules) ->
	args = [args...]
	
	options = {}
	
	for flag, rule of rules
		options[rule?.name ? flag] = if (rule?.params?.length ? 0) is 0
			false
		else
			null

	while args.length > 0
		if args[0] of rules
			flag = args.shift()
			rule = rules[flag]
			name = rule?.name ? flag

			if (rule?.params?.length ? 0) is 0
				options[name] = true
			else
				options[name] = for param in rule.params
					arg = args.shift()

					switch param
						when "integer" then parseInt(arg, 10)
						when "float", "number" then parseFloat(arg)
						else arg
				
				if rule.params.length is 1
					options[name] = options[name][0]
		else
			throw "wtf at #{args[0]}"
	
	return options


if process.argv.length > 2
	[, , cmd, args...] = process.argv
	
	switch cmd.toLowerCase()
		when "tj", "tojson", "to-json"
			if args.length isnt 0
				options = getOptions args[1..],
					"-o":
						name: "outputFile"
						params: ["string"]

				fpath = path.resolve args[0]
				fdir = path.dirname fpath
				fbase = path.basename fpath
				fname = path.basename fpath, '.reon'
				newPath = path.join fdir, "#{options.outputFile?.replace(/\.json$/, "") ? fname}.json"
				
				data = fs.readFileSync fpath, encoding: "utf8"
				json = fromREON data

				fs.writeFileSync newPath, json, mode: 0o777

				console.log "Wrote to #{newPath}"
			else
				throw new Error "error!"
		when "tr", "toreon", "to-reon"
			if args.length isnt 0
				options = getOptions args[1..],
					"-o":
						name: "outputFile"
						params: ["string"]

				fpath = path.resolve args[0]
				fdir = path.dirname fpath
				fbase = path.basename fpath
				fname = path.basename fpath, '.json'
				newPath = path.join fdir, "#{options.outputFile?.replace(/\.reon$/, "") ? fname}.reon"
				
				data = fs.readFileSync fpath, encoding: "utf8"
				reon = toREON JSON.parse data

				fs.writeFileSync newPath, reon, mode: 0o777

				console.log "Wrote to #{newPath}"
			else
				throw new Error "error!"
		when "h", "help"
			console.log """
Usage: reon [command] [file] [options]
Commands:
	tj, tojson, to-json       Convert the target file from REON to JSON
	tr, toreon, to-reon       Convert the target file from JSON to REON
	h, help                   Display this message
Options:
	-o [file]                 Output file (relative)
			""".trim()
		else
			throw new Error "Unknown command `#{cmd}`. Type the `help` command for a list of commands"
