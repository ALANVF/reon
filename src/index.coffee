import toREON from "./to-reon.js"
import fromREON from "./from-reon.js"

export jsonToReon = (json) =>
	toREON json

export jsonStringToReon = (json) =>
	toREON JSON.parse json

export reonToJson = (reon) =>
	JSON.parse fromREON reon

export reonToJsonString = (reon) =>
	fromREON reon