extends Node
## Tiny generated blips so the lodge and board are not silent.

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -8.0
	add_child(_player)


func pop() -> void:
	_tone(620.0, 0.045)


func boost() -> void:
	_tone(510.0, 0.07)


func win() -> void:
	_tone(880.0, 0.12)


func fail() -> void:
	_tone(196.0, 0.11)


func tap() -> void:
	_tone(440.0, 0.035)


func _tone(hz: float, seconds: float) -> void:
	var rate := 22050
	var frames := maxi(32, int(float(rate) * seconds))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var env := 1.0 - t / seconds
		var sample := int(sin(TAU * hz * t) * env * 8000.0)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	_player.stream = stream
	_player.play()
