colors = require 'colors'

initCommands = (program)->

	program
		.command('ffmpeg')
		.description('FFMPEG Utilities')
		.option('-c, --convert <input>', 'Convert file to another format.')
		.option('-f, --format <format>', 'The output format.')
		.option('-o, --output <filename>', 'The output file.')
		.action (options) ->

			FFMPEG = require('./ffmpeg')

			if options.convert

				FFMPEG.convert({ 

					input  : options.convert
					format : options.format or null 
					output : options.output or null

				}).then((res)->

					console.log res

				)

module.exports = initCommands