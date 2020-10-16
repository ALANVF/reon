import fs from "fs"
import path from "path"
import toREON from "./to-reon.js"
import fromREON from "./from-reon.js"

if process.argv.length > 2
	[, , cmd, args...] = process.argv
	
	switch cmd.toLowerCase()
		when "tj", "tojson", "to-json", "fr", "fromreon", "from-reon"
			if args.length isnt 0
				fpath = path.resolve args[0]
				fdir = path.dirname fpath
				fbase = path.basename fpath
				fname = path.basename fpath, '.reon'
				newPath = path.join fdir, "#{fname}.json"
				
				data = fs.readFileSync fpath, encoding: "utf8"
				json = fromREON data

				fs.writeFileSync newPath, json, mode: 0o777

				console.log "Wrote to #{newPath}"
			else
				throw new Error "error!"
		when "fj", "fromjson", "from-json", "tr", "toreon", "to-reon"
			if args.length isnt 0
				fpath = path.resolve args[0]
				fdir = path.dirname fpath
				fbase = path.basename fpath
				fname = path.basename fpath, '.json'
				newPath = path.join fdir, "#{fname}.reon"
				
				data = fs.readFileSync fpath, encoding: "utf8"
				reon = toREON JSON.parse data

				fs.writeFileSync newPath, reon, mode: 0o777

				console.log "Wrote to #{newPath}"
			else
				throw new Error "error!"
		when "h", "help"
			console.log """
Usage: reon [option] [file]
Options:
	tj, tojson, to-json, fr, fromreon, from-reon       Convert the target file from JSON to REON
	fj, fromjson, from-json, tr, toreon, to-reon       Convert the target file from REON to JSON
	h, help                                            Display this message
			""".trim()
		else
			throw new Error "Unknown command `#{cmd}`. Type the `help` command for a list of commands"
