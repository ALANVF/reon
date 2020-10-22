"use strict";

var _fs = _interopRequireDefault(require("fs"));

var _path = _interopRequireDefault(require("path"));

var _toReon = _interopRequireDefault(require("./to-reon.js"));

var _fromReon = _interopRequireDefault(require("./from-reon.js"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { "default": obj }; }

function _toArray(arr) { return _arrayWithHoles(arr) || _iterableToArray(arr) || _unsupportedIterableToArray(arr) || _nonIterableRest(); }

function _nonIterableRest() { throw new TypeError("Invalid attempt to destructure non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }

function _arrayWithHoles(arr) { if (Array.isArray(arr)) return arr; }

function _toConsumableArray(arr) { return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _unsupportedIterableToArray(arr) || _nonIterableSpread(); }

function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }

function _unsupportedIterableToArray(o, minLen) { if (!o) return; if (typeof o === "string") return _arrayLikeToArray(o, minLen); var n = Object.prototype.toString.call(o).slice(8, -1); if (n === "Object" && o.constructor) n = o.constructor.name; if (n === "Map" || n === "Set") return Array.from(o); if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen); }

function _iterableToArray(iter) { if (typeof Symbol !== "undefined" && Symbol.iterator in Object(iter)) return Array.from(iter); }

function _arrayWithoutHoles(arr) { if (Array.isArray(arr)) return _arrayLikeToArray(arr); }

function _arrayLikeToArray(arr, len) { if (len == null || len > arr.length) len = arr.length; for (var i = 0, arr2 = new Array(len); i < len; i++) { arr2[i] = arr[i]; } return arr2; }

// Generated by CoffeeScript 2.5.1
var args, cmd, data, fbase, fdir, fname, fpath, getOptions, json, newPath, options, ref, ref1, ref2, ref3, reon;

getOptions = function getOptions(args, rules) {
  var arg, flag, name, options, param, ref, ref1, ref2, ref3, ref4, ref5, rule;
  args = _toConsumableArray(args);
  options = {};

  for (flag in rules) {
    rule = rules[flag];
    options[(ref2 = rule != null ? rule.name : void 0) != null ? ref2 : flag] = ((ref = rule != null ? (ref1 = rule.params) != null ? ref1.length : void 0 : void 0) != null ? ref : 0) === 0 ? false : null;
  }

  while (args.length > 0) {
    if (args[0] in rules) {
      flag = args.shift();
      rule = rules[flag];
      name = (ref3 = rule != null ? rule.name : void 0) != null ? ref3 : flag;

      if (((ref4 = rule != null ? (ref5 = rule.params) != null ? ref5.length : void 0 : void 0) != null ? ref4 : 0) === 0) {
        options[name] = true;
      } else {
        options[name] = function () {
          var i, len, ref6, results;
          ref6 = rule.params;
          results = [];

          for (i = 0, len = ref6.length; i < len; i++) {
            param = ref6[i];
            arg = args.shift();

            switch (param) {
              case "integer":
                results.push(parseInt(arg, 10));
                break;

              case "float":
              case "number":
                results.push(parseFloat(arg));
                break;

              default:
                results.push(arg);
            }
          }

          return results;
        }();

        if (rule.params.length === 1) {
          options[name] = options[name][0];
        }
      }
    } else {
      throw "wtf at ".concat(args[0]);
    }
  }

  return options;
};

if (process.argv.length > 2) {
  var _process$argv = _toArray(process.argv);

  cmd = _process$argv[2];
  args = _process$argv.slice(3);

  switch (cmd.toLowerCase()) {
    case "tj":
    case "tojson":
    case "to-json":
      if (args.length !== 0) {
        options = getOptions(args.slice(1), {
          "-o": {
            name: "outputFile",
            params: ["string"]
          }
        });
        fpath = _path["default"].resolve(args[0]);
        fdir = _path["default"].dirname(fpath);
        fbase = _path["default"].basename(fpath);
        fname = _path["default"].basename(fpath, '.reon');
        newPath = _path["default"].join(fdir, "".concat((ref = (ref1 = options.outputFile) != null ? ref1.replace(/\.json$/, "") : void 0) != null ? ref : fname, ".json"));
        data = _fs["default"].readFileSync(fpath, {
          encoding: "utf8"
        });
        json = (0, _fromReon["default"])(data);

        _fs["default"].writeFileSync(newPath, json, {
          mode: 511
        });

        console.log("Wrote to ".concat(newPath));
      } else {
        throw new Error("error!");
      }

      break;

    case "tr":
    case "toreon":
    case "to-reon":
      if (args.length !== 0) {
        options = getOptions(args.slice(1), {
          "-o": {
            name: "outputFile",
            params: ["string"]
          }
        });
        fpath = _path["default"].resolve(args[0]);
        fdir = _path["default"].dirname(fpath);
        fbase = _path["default"].basename(fpath);
        fname = _path["default"].basename(fpath, '.json');
        newPath = _path["default"].join(fdir, "".concat((ref2 = (ref3 = options.outputFile) != null ? ref3.replace(/\.reon$/, "") : void 0) != null ? ref2 : fname, ".reon"));
        data = _fs["default"].readFileSync(fpath, {
          encoding: "utf8"
        });
        reon = (0, _toReon["default"])(JSON.parse(data));

        _fs["default"].writeFileSync(newPath, reon, {
          mode: 511
        });

        console.log("Wrote to ".concat(newPath));
      } else {
        throw new Error("error!");
      }

      break;

    case "h":
    case "help":
      console.log("Usage: reon-convert [command] [file] [options]\nCommands:\n\ttj, tojson, to-json       Convert the target file from REON to JSON\n\ttr, toreon, to-reon       Convert the target file from JSON to REON\n\th, help                   Display this message\nOptions:\n\t-o [file]                 Output file (relative)".trim());
      break;

    default:
      throw new Error("Unknown command `".concat(cmd, "`. Type the `help` command for a list of commands"));
  }
}