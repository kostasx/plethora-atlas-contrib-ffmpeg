colors = require 'colors'

initCommands = (program)->

	program
		.command('ffmpeg')
		.description('FFMPEG Utilities')
		.option('-c, --convert <input>', 'Convert file to another format: atlas ffmpeg --convert <FILE> --format <FORMAT> [--output <OUTPUT>]')
		.option('-f, --format <format>', 'The output format.')
		.option('-o, --output <filename>', 'The output file.')
		.option('-s, --split <filename>', 'Split file.')
		.option('-t, --trim-audio <filename>', 'Trim audio: atlas ffmpeg --trim-audio input.wav --start 0 --duration 30')
		.option('-s, --start <start>', 'Trim audio start time.')
		.option('--detect-silence <audio>', 'Detect silence in audio file.')
		.option('-d, --duration <secs>', 'Trim audio for <secs> seconds.')
		.option('-e, --export-waveform <filename>', 'Export audio waveform image: atlas ffmpeg --export-waveform input.wav --waveform-options "[compand][,downmixed]"')
		.option('--waveform-options <extras>', '--waveform-options [compand][,downmixed]')
		.option('--change-speed <filename>', 'atlas ffmpeg --change-speed input.wav --speed 0.5|2')
		.option('--reduce-noise <filename>', 'Apply a lowpass and highpass filter to isolate audible speech.')
		.option('--remove-silence <filename.wav>', 'Remove silence from audio. Currently only .wav files are supported')
		.option('--speed <value>')
		.action (options) ->

			FFMPEG = require('./ffmpeg')

			if options.removeSilence
				FFMPEG.removeSilence({ file: options.removeSilence })
				.then(console.log)
				.catch(console.log)

			if options.detectSilence
				FFMPEG.detectSilence({ 

					file  : options.detectSilence
					noise : "-30"
					d     : "0.5"

				})
				.then(console.log)
				.catch(console.log)

			if options.reduceNoise
				FFMPEG.reduceNoise({ 
					file: options.reduceNoise 
				})
				.then(console.log)
				.catch(console.log)

			if options.changeSpeed
				FFMPEG.changeSpeed({
					file  : options.changeSpeed,
					speed : options.speed
				})
				.then(console.log)
				.catch(console.log)

			if options.trimAudio
				FFMPEG.trimAudio({ 
					file     : options.trimAudio, 
					start    : options.start, 
					duration : options.duration
				})
				.then(console.log)
				.catch(console.log)

			if options.exportWaveform
				FFMPEG.exportAudioWaveform({ 
					file   : options.exportWaveform 
					extras : options.waveformOptions or null
				})
				.then(console.log)
				.catch(console.log)

			if options.convert

				FFMPEG.convert({ 

					input  : options.convert
					format : options.format or null 
					output : options.output or null

				}).then((res)->

					console.log res

				).catch(console.log)

module.exports = initCommands