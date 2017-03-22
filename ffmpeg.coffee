colors = require 'colors'
ffmpeg = require 'fluent-ffmpeg'
shell  = require 'shelljs'
path   = require 'path'
fs 	   = require 'fs'

InputOutputParser = (options)->

	file   = options.file
	parsed = path.parse file
	ext    = if options.ext then options.ext else parsed.ext
	output = parsed.dir + parsed.name + options.slug + ext
	return output

nullable = ()->

	if process.platform is 'win32'
		return 'nul'
	else
		return '/dev/null'

FFMPEG =

	exportAudioWaveform: (options)->

		output = InputOutputParser({ file: options.file, ext: ".png", slug: "-waveform" })

		# EXTRA OPTIONS
		extras = ""
		if options.extras
			extrasArgs = options.extras.split(",")
			extrasArgs.map((extra)->
				if extra is 'downmixed'
					extras += "aformat=channel_layouts=mono,"
				if extra is "compand"
					extras += "compand,"
			)

		new Promise((resolve, reject)->

			# EXPORT AUDIO WAVEFORM
			ffmpeg(options.file)
			.addOption('-filter_complex', "#{extras}showwavespic=s=1280x240")
			.addOption('-frames:v', '1')
			.saveToFile(output)
			.on('end', ()-> resolve({ msg: "Output written to file #{output}" })  )
			.on('error', (err)-> resolve({ msg: 'An error happened', error: err.message }))

		)

	trimAudio: (options)->

		output = options.output or InputOutputParser({ file: options.file, slug: "-trimmed" })

		new Promise((resolve, reject)->

			ffmpeg(options.file)
			.addOption('-ss', options.start)	# Start at options.start
			.addOption('-t', options.duration)	# Capture options.duration in seconds
			.saveToFile(output)
			.on('end', ()-> resolve({ msg: "Output written to file #{output}" })  )
			.on('error', (err)-> resolve({ msg: 'An error happened', error: err.message }))

		)

	changeSpeed: (options)->

		speed  = options.speed or 0.5
		output = InputOutputParser({ file: options.file, slug: "-speed-change" })

		new Promise((resolve, reject)->

			ffmpeg(options.file)
			.addOption('-filter:a',"atempo=#{speed}")
			.saveToFile(output)
			.on('end', ()-> resolve({ msg: "Output written to file #{output}" })  )
			.on('error', (err)-> resolve({ msg: 'An error happened', error: err.message }))

		)

	reduceNoise: (options)->

		# Combining a a lowpass filter to cut higher frequencies with a high pass filter to cut lower frequencies
		# For usable audio, filtering out 200hz and below and filtering out 3000hz and above produces usable voice audio. 
		# Repeat command for better results.

		output = InputOutputParser({ file: options.file, slug: "-reduced-noise" })

		new Promise((resolve, reject)->

			ffmpeg(options.file)
			.addOption('-af', "highpass=f=200, lowpass=f=3000")	# ISOLATE AUDIBLE SPEECH USING LOWPASS + HIGHPASS FILTERS
			.saveToFile(output)
			.on('end', ()-> resolve({ msg: "Output written to file #{output}" })  )
			.on('error', (err)-> resolve({ msg: 'An error happened', error: err.message }))

		)

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
			.saveToFile( output )
			.on('end', ()-> resolve({ msg: "File: #{input} has been converted successfully" }))
			.on('error', (err)-> resolve({ msg: 'An error happened', error: err.message }))

		)

	detectSilence: (options)->

		output = InputOutputParser({ file: options.file, slug: "-detect-silence" })

		new Promise((resolve, reject)->

			ffmpeg(options.file)
			# .audioFilters('volume=0.5')
			.addOption('-af', "silencedetect=noise=#{options.noise}dB:d=#{options.d}")
			.addOption('-f', "null")
			.on('end', (stdout, stderr)->      

				# console.log stderr
				###
				[silencedetect @ 0x7f95bad000c0] silence_end: 163.933 | silence_duration: 0.59288
				[silencedetect @ 0x7f95bad000c0] silence_start: 167.287
				[silencedetect @ 0x7f95bad000c0] silence_end: 167.88 | silence_duration: 0.59288
				...
				[silencedetect @ 0x7f95bad000c0] silence_start: 608.095
				[silencedetect @ 0x7f95bad000c0] silence_end: 611.103 | silence_duration: 3.00776
				[silencedetect @ 0x7f95bad000c0] silence_start: 611.299
				###

				silenceDetect = []
				stderr.split("\n").filter (entry) ->
					~entry.indexOf '[silencedetect @'
				.map (entry) ->

					if ~entry.indexOf('silence_start')
						silence_start = entry.split("silence_start")
						silence_start = silence_start[1].replace(":","").trim()
						silenceDetect.unshift({ start: silence_start }) 

					if ~entry.indexOf('silence_end')
						silence_end = entry.split("silence_end")
						silence_end = silence_end[1]
						silence_end = silence_end.split('|')
						# DEBUG: TypeError: Cannot set property 'end' of undefined
						silenceDetect[0].end      = silence_end[0].replace(":","").trim()
						silenceDetect[0].duration = silence_end[1].replace("silence_duration:","").trim()

				res = {}
				res.msg = if silenceDetect.length then "Silence detected" else "Silence not detected"
				if silenceDetect.length then res.data = silenceDetect.reverse()
				resolve(res) 

			)
			.saveToFile(nullable())

		)

	removeSilence: (options)->

		output = InputOutputParser({ file: options.file, slug: "-debug" })

		# [1] DETECT SILENCE
		FFMPEG.detectSilence({

			file  : options.file
			noise : "-30"
			d     : "0.5"

		}).then((res)->

			# [2] SPLIT FILE ACCORDING TO SILENCE
			pRes = Promise.resolve()

			offset      = 0
			counter     = 0
			split_files = []
			tempSlug    = "pa-ffmpeg-tmp-"
			res.data.forEach (entry) ->

				pRes = pRes.then(()->
					opts = {
						file     : options.file
						start    : offset
						duration : entry.start - offset
						output   : tempSlug + counter + '.wav'
					}
					offset = entry.end
					if counter > 0
						split_files.push(tempSlug + counter + '.wav',)
					counter++
					FFMPEG.trimAudio(opts)

				)

			pRes.then((res)->

				# [3] CONCATENATE SPLITTED FILES
				proc = new ffmpeg(

					source : tempSlug + '0.wav'
					nolog  : true
				)

				split_files.map((file)-> proc.mergeAdd(file))

				proc.mergeToFile( output, ()-> )
				.on('end', ()->

					console.log "Cleaning up..."
					split_files.push(tempSlug + "0.wav")
					split_files.map (file)->
						console.log "Removing #{file}..."
						fs.unlinkSync(file)

				)

			).then((res)->

				return { msg: 'files have been merged successfully into ' + output }

			).catch(console.log)

		).catch(console.log)

	__volumeDetect: (options)->

		ffmpeg(file)
		.withAudioFilter('volumedetect')
		.on('error', (err, stdout, stderr)-> console.log('Error: '.red, err.message, stdout, stderr))
		.on('end', (stdout, stderr)->      

			volumeDetect = {}
			stderr.split("\n").filter (x) ->
				~x.indexOf 'Parsed_volumedetect'
			.forEach (x) ->
				x = x.substr 2 + x.indexOf '] '
				x = x.split ': '
				volumeDetect[x[0]] = x[1]

			console.log volumeDetect

		)
		.saveToFile('tmp.wav')

module.exports = FFMPEG