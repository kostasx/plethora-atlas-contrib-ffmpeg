colors = require 'colors'
ffmpeg = require 'fluent-ffmpeg'
shell  = require 'shelljs'
path   = require 'path'

FFMPEG =

	convert: (options)->

		input  = options.input
		format = options.format
		output = options.output

		new Promise((resolve, reject)->

			if !format
				reject({ msg: "Error: Please provide a format", error: true })

			if !output
				output = path.parse(input)
				output = path.join( output.dir, output.name + "." + format ) 

			binary = shell.which('ffmpeg')
			binary = "#{binary}"

			proc = new ffmpeg({ source: input, nolog: true })
			proc
			.setFfmpegPath(binary)
			.toFormat(format)
			.on('end', ()->

				resolve({ msg: "File: #{input} has been converted successfully" })

			).on('error', (err)->

				resolve({ msg: 'An error happened', error: err.message })

			).saveToFile( output )

		)

module.exports = FFMPEG