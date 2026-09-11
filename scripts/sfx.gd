extends Node
## Tiny generated blips so the lodge and board are not silent.

var _voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for _i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_voices.append(p)


func pop() -> void:
	_tone(620.0, 0.045)
	_buzz(28, 0.55)


func boost() -> void:
	_tone(510.0, 0.07)
	_buzz(40, 0.65)


func win() -> void:
	_tone(880.0, 0.12)
	_buzz(70, 0.5)


func fail() -> void:
	_tone(196.0, 0.11)
	_buzz(55, 0.45)


func tap() -> void:
	_tone(440.0, 0.035)
	_buzz(14, 0.32)


func shoot() -> void:
	_play(_bubble(0.09))
	_buzz(24, 0.72)


func bounce() -> void:
	_tone(196.0, 0.05)
	_buzz(10, 0.28)


func _buzz(msec: int, amplitude: float) -> void:
	Input.vibrate_handheld(msec, amplitude)


func _tone(hz: float, seconds: float) -> void:
	_play(_sine(hz, seconds))


func _player() -> AudioStreamPlayer:
	for p in _voices:
		if not p.playing:
			return p
	return _voices[0]


func _play(bytes: PackedByteArray) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes
	var p := _player()
	p.stream = stream
	p.play()


func _sine(hz: float, seconds: float) -> PackedByteArray:
	var rate := 22050
	var frames := maxi(32, int(float(rate) * seconds))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var env := 1.0 - t / seconds
		var sample := int(sin(TAU * hz * t) * env * 8000.0)
		bytes.encode_s16(i * 2, sample)
	return bytes


func _bubble(seconds: float) -> PackedByteArray:
	var rate := 22050
	var frames := maxi(32, int(float(rate) * seconds))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var env := pow(1.0 - t / seconds, 1.4)
		var hz := 980.0 - 420.0 * (t / seconds)
		var sample := int((sin(TAU * hz * t) + 0.35 * sin(TAU * hz * 2.2 * t)) * env * 7200.0)
		bytes.encode_s16(i * 2, sample)
	return bytes
