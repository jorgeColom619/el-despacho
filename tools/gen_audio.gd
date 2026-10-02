extends SceneTree
## Generador offline de audio: sintetiza todos los efectos y la música del juego.
## Uso: godot --headless --path . --script res://tools/gen_audio.gd

const SR := 44100
const MSR := 32000
var rng := RandomNumberGenerator.new()


class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func setup(kind: String, freq: float, q: float, sr: float) -> void:
		var w0 := TAU * freq / sr
		var cw := cos(w0)
		var alpha := sin(w0) / (2.0 * q)
		var a0 := 1.0
		match kind:
			"lp":
				b0 = (1.0 - cw) / 2.0
				b1 = 1.0 - cw
				b2 = (1.0 - cw) / 2.0
				a0 = 1.0 + alpha
				a1 = -2.0 * cw
				a2 = 1.0 - alpha
			"hp":
				b0 = (1.0 + cw) / 2.0
				b1 = -(1.0 + cw)
				b2 = (1.0 + cw) / 2.0
				a0 = 1.0 + alpha
				a1 = -2.0 * cw
				a2 = 1.0 - alpha
			"bp":
				b0 = alpha
				b1 = 0.0
				b2 = -alpha
				a0 = 1.0 + alpha
				a1 = -2.0 * cw
				a2 = 1.0 - alpha
		b0 /= a0
		b1 /= a0
		b2 /= a0
		a1 /= a0
		a2 /= a0

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


func _init() -> void:
	rng.seed = 20270101
	var t0 := Time.get_ticks_msec()
	gen_sfx()
	print("SFX listos: %d ms" % (Time.get_ticks_msec() - t0))
	gen_music()
	print("Audio generado en %d ms" % (Time.get_ticks_msec() - t0))
	quit()


# ------------------------------------------------------------------ utilidades

func mkbuf(sec: float, sr: int = SR) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * sr))
	b.fill(0.0)
	return b


func normalize(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for i in b.size():
		m = maxf(m, absf(b[i]))
	var g := peak / m
	for i in b.size():
		b[i] *= g


func fade_edges(b: PackedFloat32Array, fin: float, fout: float, sr: int = SR) -> void:
	var ni := int(fin * sr)
	var no := int(fout * sr)
	for i in mini(ni, b.size()):
		b[i] *= float(i) / float(ni)
	for i in mini(no, b.size()):
		b[b.size() - 1 - i] *= float(i) / float(no)


func save_mono(name: String, b: PackedFloat32Array, sr: int = SR) -> void:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		var v := clampf(b[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = data
	w.save_to_wav("res://audio/%s.wav" % name)


func save_stereo(name: String, l: PackedFloat32Array, r: PackedFloat32Array, sr: int) -> void:
	var n := mini(l.size(), r.size())
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		data.encode_s16(i * 4, int(clampf(l[i], -1.0, 1.0) * 32000.0))
		data.encode_s16(i * 4 + 2, int(clampf(r[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = true
	w.data = data
	w.save_to_wav("res://audio/%s.wav" % name)


func env(t: float, a: float, d: float) -> float:
	if t < 0.0:
		return 0.0
	if t < a:
		return t / a
	return exp(-(t - a) / d)


func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func add_sine(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, a: float, d: float, sr: int = SR) -> void:
	var s0 := int(start * sr)
	var n := int(dur * sr)
	var ph := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / sr
		var f := lerpf(f0, f1, minf(1.0, t / maxf(dur * 0.6, 0.001)))
		ph += TAU * f / sr
		b[idx] += sin(ph) * amp * env(t, a, d)


func add_noise(b: PackedFloat32Array, start: float, dur: float, amp: float, a: float, d: float, kind: String, freq: float, q: float, sr: int = SR) -> void:
	var s0 := int(start * sr)
	var n := int(dur * sr)
	var bq := Biquad.new()
	bq.setup(kind, freq, q, sr)
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / sr
		b[idx] += bq.process(rng.randf_range(-1.0, 1.0)) * amp * env(t, a, d)


func add_bell(b: PackedFloat32Array, start: float, f: float, amp: float, decay: float, sr: int = SR) -> void:
	var ratios := [1.0, 2.76, 5.40, 8.93]
	var amps := [1.0, 0.45, 0.22, 0.1]
	for k in ratios.size():
		add_sine(b, start, decay * 4.0 / (1.0 + k), f * ratios[k], f * ratios[k], amp * amps[k], 0.002, decay / (1.0 + k * 0.9), sr)


func add_fm(b: PackedFloat32Array, start: float, f: float, dur: float, amp: float, index: float, sr: int = SR, ratio: float = 1.0) -> void:
	# Piano eléctrico FM suave
	var s0 := int(start * sr)
	var n := int((dur + 1.2) * sr)
	var pc := 0.0
	var pm := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size() or idx < 0:
			break
		var t := float(i) / sr
		var e := env(t, 0.004, 0.55 + dur * 0.4)
		if t > dur:
			e *= exp(-(t - dur) / 0.25)
		var ie := index * exp(-t / 0.35)
		pm += TAU * f * ratio / sr
		pc += TAU * f / sr
		b[idx] += sin(pc + ie * sin(pm)) * amp * e


func add_pluck(b: PackedFloat32Array, start: float, f: float, dur: float, amp: float, decay: float, bright: float, sr: int = SR) -> void:
	var n := maxi(2, int(sr / f - 0.5))
	var line := PackedFloat32Array()
	line.resize(n)
	var lp := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * bright
		line[i] = lp
	var idx := 0
	var s0 := int(start * sr)
	var total := int(dur * sr)
	for i in total:
		var o := s0 + i
		if o >= b.size():
			break
		var cur := line[idx]
		var nx := line[(idx + 1) % n]
		line[idx] = decay * 0.5 * (cur + nx)
		idx = (idx + 1) % n
		var fade := 1.0
		var rem := total - i
		if rem < 400:
			fade = float(rem) / 400.0
		b[o] += cur * amp * fade


func add_saw_pad(b: PackedFloat32Array, start: float, dur: float, f: float, amp: float, attack: float, release: float, cutoff: float, detune: float, sr: int) -> void:
	var s0 := int(start * sr)
	var n := int((dur + release) * sr)
	var ph := [rng.randf(), rng.randf(), rng.randf()]
	var det := [1.0, 1.0 + detune, 1.0 - detune]
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 1.0 - exp(-TAU * cutoff / sr)
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / sr
		var e := minf(1.0, t / attack)
		if t > dur:
			e *= exp(-(t - dur) / (release * 0.35))
		var s := 0.0
		for k in 3:
			ph[k] = fmod(ph[k] + f * det[k] / sr, 1.0)
			s += ph[k] * 2.0 - 1.0
		lp1 += (s - lp1) * a
		lp2 += (lp1 - lp2) * a
		b[idx] += lp2 * amp * e


func reverb(b: PackedFloat32Array, sr: int, mix: float, room: float, seed_off: int) -> PackedFloat32Array:
	var comb_ms := [29.7, 37.1, 41.1, 43.7]
	var out := PackedFloat32Array()
	out.resize(b.size())
	out.fill(0.0)
	for c in comb_ms.size():
		var d := int((comb_ms[c] + seed_off * 1.3) * sr / 1000.0)
		var line := PackedFloat32Array()
		line.resize(d)
		line.fill(0.0)
		var p := 0
		var damp := 0.0
		for i in b.size():
			var y := line[p]
			damp += (y - damp) * 0.45
			line[p] = b[i] + damp * room
			p = (p + 1) % d
			out[i] += y * 0.25
	for ap_ms in [5.0, 1.7]:
		var d2 := int((ap_ms + seed_off * 0.3) * sr / 1000.0)
		var buf2 := PackedFloat32Array()
		buf2.resize(d2)
		buf2.fill(0.0)
		var q := 0
		for i in out.size():
			var bufout := buf2[q]
			var inp := out[i]
			buf2[q] = inp + bufout * 0.6
			out[i] = bufout - inp * 0.6
			q = (q + 1) % d2
	for i in out.size():
		out[i] = b[i] * (1.0 - mix * 0.5) + out[i] * mix
	return out


func wrap_loop(b: PackedFloat32Array, loop_len: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(loop_len)
	for i in loop_len:
		out[i] = b[i]
	var tail := b.size() - loop_len
	for i in tail:
		out[i % loop_len] += b[loop_len + i]
	return out


func soft_clip(b: PackedFloat32Array, drive: float) -> void:
	for i in b.size():
		var x := b[i] * drive
		b[i] = x / (1.0 + absf(x))


# ------------------------------------------------------------------ efectos

func gen_sfx() -> void:
	var b: PackedFloat32Array

	# click
	b = mkbuf(0.06)
	add_noise(b, 0.0, 0.01, 0.6, 0.0005, 0.002, "hp", 2000.0, 0.7)
	add_sine(b, 0.0, 0.05, 1900.0, 1500.0, 0.5, 0.001, 0.012)
	normalize(b, 0.55)
	save_mono("click", b)

	# hover
	b = mkbuf(0.05)
	add_sine(b, 0.0, 0.04, 2600.0, 2900.0, 0.4, 0.002, 0.01)
	normalize(b, 0.22)
	save_mono("hover", b)

	# open (whoosh arriba)
	b = mkbuf(0.4)
	var bq := Biquad.new()
	for i in b.size():
		var t := float(i) / SR
		bq.setup("bp", 300.0 + 3200.0 * (t / 0.4), 1.2, SR)
		b[i] = bq.process(rng.randf_range(-1.0, 1.0)) * sin(PI * t / 0.4)
	normalize(b, 0.4)
	save_mono("open", b)

	# close (whoosh abajo)
	b = mkbuf(0.35)
	bq = Biquad.new()
	for i in b.size():
		var t := float(i) / SR
		bq.setup("bp", 2600.0 - 2200.0 * (t / 0.35), 1.2, SR)
		b[i] = bq.process(rng.randf_range(-1.0, 1.0)) * sin(PI * t / 0.35)
	normalize(b, 0.35)
	save_mono("close", b)

	# papel deslizando
	b = mkbuf(0.45)
	bq = Biquad.new()
	bq.setup("bp", 4200.0, 0.8, SR)
	for i in b.size():
		var t := float(i) / SR
		var flutter := 0.6 + 0.4 * sin(t * 90.0 + sin(t * 37.0) * 2.0)
		b[i] = bq.process(rng.randf_range(-1.0, 1.0)) * sin(PI * t / 0.45) * flutter
	normalize(b, 0.5)
	save_mono("paper", b)

	# papel cogido (arrugado corto)
	b = mkbuf(0.3)
	for k in 9:
		add_noise(b, rng.randf_range(0.0, 0.22), 0.04, rng.randf_range(0.3, 1.0), 0.001, 0.008, "bp", rng.randf_range(2500.0, 6000.0), 1.5)
	normalize(b, 0.45)
	save_mono("paper2", b)

	# sello (golpe)
	b = mkbuf(0.4)
	add_sine(b, 0.0, 0.35, 95.0, 42.0, 1.0, 0.001, 0.07)
	add_sine(b, 0.0, 0.12, 190.0, 160.0, 0.5, 0.001, 0.03)
	add_noise(b, 0.0, 0.05, 0.9, 0.0005, 0.01, "lp", 2500.0, 0.7)
	add_noise(b, 0.0, 0.2, 0.25, 0.001, 0.05, "bp", 600.0, 2.0)
	soft_clip(b, 1.6)
	normalize(b, 0.9)
	save_mono("stamp", b)

	# teléfono de sobremesa (timbre de campana) - bucle de 3 s
	b = mkbuf(3.0)
	var strikes := 34
	for k in strikes:
		var tt := k * 0.047
		var f := 1480.0 if k % 2 == 0 else 1760.0
		add_bell(b, tt, f, 0.35, 0.07)
	fade_edges(b, 0.002, 0.05)
	normalize(b, 0.55)
	save_mono("ring", b)

	# teléfono rojo (electrónico urgente) - bucle 1.2 s
	b = mkbuf(1.2)
	for k in 2:
		var st := k * 0.5
		var n := int(0.36 * SR)
		for i in n:
			var t := float(i) / SR
			var f := 880.0 if int(t * 16.0) % 2 == 0 else 1100.0
			var v := signf(sin(TAU * f * t)) * 0.3 + sin(TAU * f * t) * 0.5
			var idx := int(st * SR) + i
			if idx < b.size():
				b[idx] += v * minf(1.0, t / 0.01) * minf(1.0, (0.36 - t) / 0.02)
	var lpv := 0.0
	for i in b.size():
		lpv += (b[i] - lpv) * 0.35
		b[i] = lpv
	normalize(b, 0.4)
	save_mono("ring_red", b)

	# golpes de puerta
	b = mkbuf(0.7)
	for k in 3:
		var tt := k * 0.17
		add_noise(b, tt, 0.08, 1.0, 0.0008, 0.012, "bp", 650.0, 1.4)
		add_sine(b, tt, 0.12, 210.0, 170.0, 0.8, 0.001, 0.035)
	normalize(b, 0.8)
	save_mono("knock", b)

	# notificación (campanita)
	b = mkbuf(1.4)
	add_bell(b, 0.0, 1318.5, 0.5, 0.35)
	add_bell(b, 0.11, 1975.5, 0.4, 0.4)
	normalize(b, 0.4)
	save_mono("notify", b)

	# alerta
	b = mkbuf(1.0)
	for k in 3:
		var st := k * 0.22
		var n := int(0.13 * SR)
		for i in n:
			var t := float(i) / SR
			var v := signf(sin(TAU * 988.0 * t)) * 0.4 + sin(TAU * 988.0 * t) * 0.4
			b[int(st * SR) + i] += v * minf(1.0, t / 0.005) * minf(1.0, (0.13 - t) / 0.01)
	lpv = 0.0
	for i in b.size():
		lpv += (b[i] - lpv) * 0.4
		b[i] = lpv
	normalize(b, 0.4)
	save_mono("alert", b)

	# éxito
	b = mkbuf(1.6)
	var notes := [72, 76, 79, 84]
	for k in notes.size():
		add_pluck(b, k * 0.075, midi(notes[k]), 1.4, 0.5, 0.997, 0.6)
		add_fm(b, k * 0.075, midi(notes[k]), 0.4, 0.25, 1.2)
	normalize(b, 0.5)
	save_mono("success", b)

	# fracaso
	b = mkbuf(1.6)
	notes = [67, 63, 60]
	for k in notes.size():
		add_fm(b, k * 0.16, midi(notes[k]), 0.5, 0.35, 2.0)
	normalize(b, 0.45)
	save_mono("fail", b)

	# tecla de máquina de escribir
	b = mkbuf(0.05)
	add_noise(b, 0.0, 0.03, 0.8, 0.0003, 0.004, "bp", 3200.0, 2.0)
	add_sine(b, 0.0, 0.03, 1100.0, 900.0, 0.2, 0.0005, 0.006)
	normalize(b, 0.3)
	save_mono("type", b)

	# mazo
	b = mkbuf(1.0)
	for k in 2:
		var tt := k * 0.32
		add_noise(b, tt, 0.1, 1.0, 0.0005, 0.015, "bp", 900.0, 1.2)
		add_sine(b, tt, 0.3, 240.0, 210.0, 0.7, 0.001, 0.06)
		add_sine(b, tt, 0.25, 720.0, 690.0, 0.25, 0.001, 0.03)
	var rb := reverb(b, SR, 0.35, 0.7, 0)
	normalize(rb, 0.85)
	save_mono("gavel", rb)

	# murmullo de multitud (bucle 6 s)
	b = mkbuf(6.0)
	for v in 14:
		var bqv := Biquad.new()
		var fc := rng.randf_range(350.0, 1600.0)
		bqv.setup("bp", fc, 3.0, SR)
		var rate := rng.randf_range(2.0, 5.0)
		var off := rng.randf() * TAU
		for i in b.size():
			var t := float(i) / SR
			var am := maxf(0.0, sin(t * rate + off) * 0.6 + sin(t * rate * 2.3 + off * 2.0) * 0.4)
			b[i] += bqv.process(rng.randf_range(-1.0, 1.0)) * am
	fade_edges(b, 0.3, 0.3)
	normalize(b, 0.45)
	save_mono("crowd", b)

	# aplausos
	b = mkbuf(3.2)
	for k in 700:
		var tt := rng.randf_range(0.0, 2.9)
		var dens := sin(PI * tt / 3.0)
		if rng.randf() < dens:
			add_noise(b, tt, 0.03, rng.randf_range(0.3, 1.0), 0.0005, 0.006, "bp", rng.randf_range(1200.0, 3000.0), 1.0)
	normalize(b, 0.55)
	save_mono("applause", b)

	# vítores (aplausos + gritos)
	b = mkbuf(4.0)
	for k in 1100:
		var tt := rng.randf_range(0.0, 3.8)
		var dens := minf(1.0, tt * 2.0) * minf(1.0, (4.0 - tt))
		if rng.randf() < dens:
			add_noise(b, tt, 0.03, rng.randf_range(0.3, 1.0), 0.0005, 0.006, "bp", rng.randf_range(1200.0, 3200.0), 1.0)
	for v in 10:
		var bqv := Biquad.new()
		bqv.setup("bp", rng.randf_range(500.0, 1100.0), 5.0, SR)
		var st := rng.randf_range(0.1, 1.5)
		var du := rng.randf_range(1.0, 2.2)
		for i in int(du * SR):
			var t := float(i) / SR
			var idx := int(st * SR) + i
			if idx < b.size():
				b[idx] += bqv.process(rng.randf_range(-1.0, 1.0)) * sin(PI * t / du) * 2.5
	normalize(b, 0.6)
	save_mono("cheer", b)

	# flash de cámara
	b = mkbuf(0.25)
	add_noise(b, 0.0, 0.02, 1.0, 0.0003, 0.004, "hp", 3000.0, 0.7)
	add_noise(b, 0.05, 0.03, 0.8, 0.0003, 0.006, "bp", 1800.0, 1.0)
	add_sine(b, 0.06, 0.18, 3000.0, 5200.0, 0.08, 0.02, 0.1)
	normalize(b, 0.45)
	save_mono("flash", b)

	# moneda
	b = mkbuf(0.6)
	add_bell(b, 0.0, 1567.0, 0.4, 0.12)
	add_bell(b, 0.07, 2093.0, 0.5, 0.2)
	normalize(b, 0.35)
	save_mono("coin", b)

	# latido
	b = mkbuf(1.0)
	add_sine(b, 0.0, 0.2, 70.0, 45.0, 1.0, 0.005, 0.05)
	add_sine(b, 0.22, 0.2, 62.0, 40.0, 0.7, 0.005, 0.05)
	normalize(b, 0.8)
	save_mono("heartbeat", b)

	# tic de reloj
	b = mkbuf(0.06)
	add_noise(b, 0.0, 0.02, 0.8, 0.0003, 0.003, "bp", 5000.0, 3.0)
	add_sine(b, 0.0, 0.03, 2400.0, 2400.0, 0.3, 0.0005, 0.005)
	normalize(b, 0.35)
	save_mono("tick", b)

	# tic de voto (escaño)
	b = mkbuf(0.05)
	add_sine(b, 0.0, 0.04, 1400.0, 1200.0, 0.5, 0.001, 0.008)
	normalize(b, 0.18)
	save_mono("vote_tick", b)

	# transición grande
	b = mkbuf(1.2)
	bq = Biquad.new()
	for i in b.size():
		var t := float(i) / SR
		var p := t / 1.2
		bq.setup("bp", 120.0 + 2600.0 * p * p, 0.9, SR)
		b[i] = bq.process(rng.randf_range(-1.0, 1.0)) * pow(sin(PI * p), 1.5)
	add_sine(b, 0.0, 1.2, 55.0, 80.0, 0.3, 0.6, 0.4)
	normalize(b, 0.5)
	save_mono("whoosh", b)

	# garabato de firma (bucle 1 s)
	b = mkbuf(1.0)
	bq = Biquad.new()
	bq.setup("bp", 3800.0, 0.9, SR)
	for i in b.size():
		var t := float(i) / SR
		var am := 0.5 + 0.5 * sin(t * 38.0 + sin(t * 11.0) * 3.0)
		b[i] = bq.process(rng.randf_range(-1.0, 1.0)) * am
	fade_edges(b, 0.02, 0.02)
	normalize(b, 0.35)
	save_mono("scribble", b)

	# lluvia (bucle 8 s)
	b = mkbuf(8.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.25
		lp2 += (lp - lp2) * 0.02
		b[i] = (lp - lp2) * 0.6
	for k in 900:
		add_noise(b, rng.randf_range(0.0, 7.95), 0.02, rng.randf_range(0.1, 0.5), 0.0003, 0.004, "bp", rng.randf_range(2000.0, 7000.0), 2.0)
	fade_edges(b, 0.4, 0.4)
	normalize(b, 0.4)
	save_mono("rain", b)

	# ambiente de despacho (bucle 10 s): tono de sala + ciudad lejana
	b = mkbuf(10.0)
	lp = 0.0
	lp2 = 0.0
	for i in b.size():
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.01
		lp2 += (lp - lp2) * 0.003
		b[i] = lp * 3.0 + lp2 * 2.0
	add_noise(b, 2.0, 3.0, 0.02, 1.2, 1.0, "bp", 700.0, 3.0)
	fade_edges(b, 0.6, 0.6)
	normalize(b, 0.25)
	save_mono("room", b)

	# trueno
	b = mkbuf(3.5)
	lp = 0.0
	for i in b.size():
		var t := float(i) / SR
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		var e := env(t, 0.05, 0.9) * (0.7 + 0.3 * sin(t * 13.0))
		b[i] = lp * e
	add_noise(b, 0.0, 0.3, 0.3, 0.005, 0.08, "lp", 1500.0, 0.7)
	normalize(b, 0.7)
	save_mono("thunder", b)

	# puerta (pestillo + apertura)
	b = mkbuf(0.8)
	add_noise(b, 0.0, 0.03, 0.9, 0.0005, 0.005, "bp", 2500.0, 3.0)
	add_sine(b, 0.0, 0.05, 1800.0, 1700.0, 0.3, 0.0005, 0.01)
	var bq3 := Biquad.new()
	bq3.setup("bp", 400.0, 0.8, SR)
	for i in int(0.6 * SR):
		var t := float(i) / SR
		b[int(0.1 * SR) + i] += bq3.process(rng.randf_range(-1.0, 1.0)) * sin(PI * t / 0.6) * 0.25
	normalize(b, 0.4)
	save_mono("door", b)

	# sirena lejana (bucle 4 s)
	b = mkbuf(4.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var f := 700.0 + 250.0 * sin(TAU * t / 2.0)
		ph += TAU * f / SR
		b[i] = sin(ph) * 0.5 + sin(ph * 2.0) * 0.12
	lp = 0.0
	for i in b.size():
		lp += (b[i] - lp) * 0.2
		b[i] = lp
	var rv := reverb(b, SR, 0.6, 0.8, 1)
	normalize(rv, 0.25)
	save_mono("siren", rv)

	# sintonía de noticias
	b = mkbuf(2.2)
	var nn := [67, 72, 76, 79]
	for k in nn.size():
		add_saw_pad(b, k * 0.11, 0.09, midi(nn[k]), 0.35, 0.005, 0.1, 3500.0, 0.004, SR)
	for n2 in [60, 67, 72, 76, 79]:
		add_saw_pad(b, 0.5, 1.1, midi(n2), 0.22, 0.01, 0.5, 2800.0, 0.006, SR)
	add_sine(b, 0.5, 0.6, 90.0, 50.0, 0.7, 0.002, 0.12)
	add_noise(b, 0.5, 1.5, 0.25, 0.002, 0.4, "hp", 5000.0, 0.7)
	rb = reverb(b, SR, 0.3, 0.75, 0)
	normalize(rb, 0.6)
	save_mono("news", rb)

	# sting victoria
	b = mkbuf(5.0)
	for n2 in [50, 57, 62, 66, 69, 74]:
		add_saw_pad(b, 0.0, 3.0, midi(n2), 0.18, 0.6, 1.8, 2200.0, 0.005, SR)
	for k in 16:
		add_sine(b, k * 0.04, 0.3, 75.0, 60.0, 0.25 * k / 16.0, 0.002, 0.08)
	add_sine(b, 0.66, 1.4, 75.0, 55.0, 0.9, 0.002, 0.4)
	add_noise(b, 0.66, 2.5, 0.3, 0.005, 0.8, "hp", 4000.0, 0.7)
	rb = reverb(b, SR, 0.4, 0.8, 0)
	normalize(rb, 0.7)
	save_mono("sting_win", rb)

	# sting derrota
	b = mkbuf(4.5)
	var chord := [50, 53, 57, 62]
	for n2 in chord:
		add_saw_pad(b, 0.0, 1.2, midi(n2), 0.2, 0.3, 1.2, 1400.0, 0.006, SR)
	for n2 in [49, 52, 56, 61]:
		add_saw_pad(b, 1.3, 1.8, midi(n2 - 2), 0.2, 0.3, 1.5, 1100.0, 0.006, SR)
	add_sine(b, 1.3, 2.0, 55.0, 40.0, 0.8, 0.01, 0.8)
	rb = reverb(b, SR, 0.45, 0.8, 0)
	normalize(rb, 0.6)
	save_mono("sting_lose", rb)


# ------------------------------------------------------------------ música

func gen_music() -> void:
	music_office()
	print(" - office")
	music_tension()
	print(" - tension")
	music_menu()
	print(" - menu")
	music_campaign()
	print(" - campaign")


func pad_chord(l: PackedFloat32Array, r: PackedFloat32Array, start: float, dur: float, notes: Array, amp: float, cutoff: float) -> void:
	for n in notes:
		add_saw_pad(l, start, dur, midi(n), amp, dur * 0.35, 1.4, cutoff, 0.004, MSR)
		add_saw_pad(r, start, dur, midi(n) * 1.001, amp, dur * 0.35, 1.4, cutoff, 0.005, MSR)


func finish_track(name: String, l: PackedFloat32Array, r: PackedFloat32Array, loop_len: int, rev_mix: float) -> void:
	var lr := reverb(l, MSR, rev_mix, 0.82, 0)
	var rr := reverb(r, MSR, rev_mix, 0.82, 2)
	var lw := wrap_loop(lr, loop_len)
	var rw := wrap_loop(rr, loop_len)
	var m := 0.0001
	for i in lw.size():
		m = maxf(m, maxf(absf(lw[i]), absf(rw[i])))
	var g := 0.8 / m
	for i in lw.size():
		lw[i] *= g
		rw[i] *= g
	save_stereo(name, lw, rw, MSR)


func music_office() -> void:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 16
	var loop_len := int(bar * bars * MSR)
	var total := bar * bars + 4.0
	var l := mkbuf(total, MSR)
	var r := mkbuf(total, MSR)
	var prog := [
		[57, 60, 64], [57, 60, 64], [53, 57, 60], [53, 57, 60],
		[55, 60, 64], [55, 60, 64], [55, 59, 62], [55, 59, 62],
		[57, 60, 64], [57, 60, 64], [53, 57, 60], [53, 57, 60],
		[53, 57, 62], [53, 57, 62], [52, 56, 59], [52, 56, 59]]
	var bass := [45, 45, 41, 41, 48, 48, 43, 43, 45, 45, 41, 41, 50, 50, 40, 40]
	for i in range(0, bars, 2):
		pad_chord(l, r, i * bar, bar * 2.0, prog[i], 0.05, 1100.0)
	for i in bars:
		add_sine(l, i * bar, bar * 0.95, midi(bass[i]), midi(bass[i]), 0.16, 0.05, bar * 0.6, MSR)
		add_sine(r, i * bar, bar * 0.95, midi(bass[i]), midi(bass[i]), 0.16, 0.05, bar * 0.6, MSR)
	var pat := [0, 1, 2, 1, 3, 2, 1, 2]
	for i in bars:
		var ch: Array = prog[i]
		var tones := [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
		for s in 8:
			if (i % 4 == 3 and s >= 6) or rng.randf() < 0.08:
				continue
			var t: float = i * bar + s * beat * 0.5 + rng.randf_range(-0.008, 0.008)
			var vel := 0.13 * (1.0 if s % 2 == 0 else 0.75) * rng.randf_range(0.85, 1.0)
			var note: int = tones[pat[s]]
			if s % 2 == 0:
				add_fm(l, t, midi(note), beat * 0.45, vel, 1.3, MSR)
				add_fm(r, t, midi(note), beat * 0.45, vel * 0.6, 1.3, MSR)
			else:
				add_fm(l, t, midi(note), beat * 0.45, vel * 0.6, 1.3, MSR)
				add_fm(r, t, midi(note), beat * 0.45, vel, 1.3, MSR)
	# melodía suave de campana en la segunda mitad
	var mel := [[8, 0.0, 76], [8, 2.0, 74], [9, 0.0, 72], [9, 3.0, 71], [10, 0.0, 72], [10, 2.0, 69],
		[11, 0.0, 72], [12, 0.0, 74], [12, 2.0, 77], [13, 0.0, 76], [14, 0.0, 71], [14, 2.0, 68], [15, 0.0, 71]]
	for m in mel:
		var t: float = m[0] * bar + m[1] * beat
		add_bell(l, t, midi(m[2]), 0.06, 0.5, MSR)
		add_bell(r, t + 0.012, midi(m[2]), 0.06, 0.5, MSR)
	# shaker suave
	for i in range(8, bars):
		for s in 8:
			if s % 2 == 1:
				var t := i * bar + s * beat * 0.5
				add_noise(l, t, 0.05, 0.03, 0.004, 0.02, "hp", 7000.0, 0.7, MSR)
				add_noise(r, t + 0.005, 0.05, 0.03, 0.004, 0.02, "hp", 7000.0, 0.7, MSR)
	finish_track("music_office", l, r, loop_len, 0.35)


func music_tension() -> void:
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 16
	var loop_len := int(bar * bars * MSR)
	var l := mkbuf(bar * bars + 4.0, MSR)
	var r := mkbuf(bar * bars + 4.0, MSR)
	var roots := [38, 38, 38, 38, 34, 34, 34, 34, 43, 43, 43, 43, 45, 45, 45, 45]
	var chords := {38: [50, 53, 57], 34: [46, 50, 53], 43: [50, 55, 58], 45: [49, 52, 57]}
	for i in range(0, bars, 4):
		pad_chord(l, r, i * bar, bar * 4.0, chords[roots[i]], 0.045, 800.0)
	var ost := [0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 12, 0, 0, 7, 0, 10]
	for i in bars:
		for s in 16:
			var t := i * bar + s * beat * 0.25
			var note: int = roots[i] + ost[s]
			var acc := 1.0 if s % 4 == 0 else 0.6
			add_pluck(l, t, midi(note + 12), beat * 0.24, 0.22 * acc, 0.985, 0.5, MSR)
			add_pluck(r, t, midi(note + 12), beat * 0.24, 0.22 * acc, 0.985, 0.5, MSR)
	for i in bars:
		for hit in [0.0, 1.5, 2.0]:
			var t: float = i * bar + hit * beat
			var a := 0.7 if hit == 0.0 else 0.45
			add_sine(l, t, 0.5, 95.0, 48.0, a, 0.002, 0.12, MSR)
			add_sine(r, t, 0.5, 95.0, 48.0, a, 0.002, 0.12, MSR)
			add_noise(l, t, 0.1, a * 0.3, 0.001, 0.03, "lp", 900.0, 0.7, MSR)
			add_noise(r, t, 0.1, a * 0.3, 0.001, 0.03, "lp", 900.0, 0.7, MSR)
		for s in 8:
			var t2 := i * bar + s * beat * 0.5
			add_noise(l, t2, 0.03, 0.05, 0.001, 0.006, "bp", 6000.0, 2.0, MSR)
			add_noise(r, t2, 0.03, 0.05, 0.001, 0.006, "bp", 6000.0, 2.0, MSR)
	# trémolo agudo en los últimos compases
	for i in range(12, 16):
		var t := i * bar
		var n := int(bar * MSR)
		var s0 := int(t * MSR)
		var f := midi(81 + (i - 12))
		for k in n:
			var tt := float(k) / MSR
			var v := sin(TAU * f * tt) * (0.5 + 0.5 * sin(TAU * 14.0 * tt)) * 0.035 * minf(1.0, tt / 0.5)
			l[s0 + k] += v
			r[s0 + k] += v
	finish_track("music_tension", l, r, loop_len, 0.3)


func music_menu() -> void:
	var bpm := 66.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 12
	var loop_len := int(bar * bars * MSR)
	var l := mkbuf(bar * bars + 5.0, MSR)
	var r := mkbuf(bar * bars + 5.0, MSR)
	var prog := [[50, 54, 57, 62], [50, 54, 57, 62], [47, 50, 54, 59], [47, 50, 54, 59],
		[43, 50, 55, 59], [43, 50, 55, 59], [45, 49, 52, 57], [45, 49, 52, 57],
		[43, 50, 55, 59], [45, 49, 52, 57], [50, 54, 57, 62], [50, 54, 57, 62]]
	for i in range(0, bars, 2):
		pad_chord(l, r, i * bar, bar * 2.0, prog[i], 0.04, 1300.0)
	for i in bars:
		var root: int = prog[i][0] - 12
		add_sine(l, i * bar, bar, midi(root), midi(root), 0.14, 0.2, bar * 0.8, MSR)
		add_sine(r, i * bar, bar, midi(root), midi(root), 0.14, 0.2, bar * 0.8, MSR)
		if i % 2 == 0:
			add_sine(l, i * bar, 1.2, 80.0, 70.0, 0.4, 0.004, 0.35, MSR)
			add_sine(r, i * bar, 1.2, 80.0, 70.0, 0.4, 0.004, 0.35, MSR)
	var mel := [[0, 0, 2, 66], [0, 2, 1, 69], [0, 3, 1, 74], [1, 0, 3, 73], [1, 3, 1, 71],
		[2, 0, 2, 74], [2, 2, 2, 78], [3, 0, 4, 76], [4, 0, 2, 74], [4, 2, 1, 71], [4, 3, 1, 67],
		[5, 0, 4, 69], [6, 0, 2, 73], [6, 2, 2, 76], [7, 0, 4, 76], [8, 0, 2, 74], [8, 2, 2, 71],
		[9, 0, 2, 73], [9, 2, 2, 76], [10, 0, 8, 74]]
	for m in mel:
		var t: float = m[0] * bar + m[1] * beat
		var d: float = m[2] * beat
		add_saw_pad(l, t, d * 0.95, midi(m[3]), 0.09, 0.12, 0.6, 1800.0, 0.003, MSR)
		add_saw_pad(r, t, d * 0.95, midi(m[3]), 0.09, 0.12, 0.6, 1800.0, 0.004, MSR)
		add_bell(l, t, midi(m[3] + 12), 0.025, 0.6, MSR)
	finish_track("music_menu", l, r, loop_len, 0.45)


func music_campaign() -> void:
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 16
	var loop_len := int(bar * bars * MSR)
	var l := mkbuf(bar * bars + 4.0, MSR)
	var r := mkbuf(bar * bars + 4.0, MSR)
	var prog := [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]]
	for i in bars:
		var ch: Array = prog[(i / 2) % 4]
		if i % 2 == 0:
			pad_chord(l, r, i * bar, bar * 2.0, [ch[0] + 12, ch[1] + 12, ch[2] + 12], 0.035, 1600.0)
		for s in 8:
			var t := i * bar + s * beat * 0.5
			add_pluck(l, t, midi(ch[0] - 12 + (12 if s % 4 == 2 else 0)), beat * 0.45, 0.25, 0.99, 0.45, MSR)
			add_pluck(r, t, midi(ch[0] - 12 + (12 if s % 4 == 2 else 0)), beat * 0.45, 0.25, 0.99, 0.45, MSR)
		for k in 4:
			var t := i * bar + k * beat
			if k % 2 == 0:
				add_sine(l, t, 0.3, 110.0, 50.0, 0.5, 0.001, 0.08, MSR)
				add_sine(r, t, 0.3, 110.0, 50.0, 0.5, 0.001, 0.08, MSR)
			else:
				add_noise(l, t, 0.15, 0.25, 0.001, 0.05, "bp", 1800.0, 0.8, MSR)
				add_noise(r, t, 0.15, 0.25, 0.001, 0.05, "bp", 1800.0, 0.8, MSR)
			add_noise(l, t + beat * 0.5, 0.04, 0.06, 0.001, 0.01, "hp", 7000.0, 0.7, MSR)
			add_noise(r, t + beat * 0.5, 0.04, 0.06, 0.001, 0.01, "hp", 7000.0, 0.7, MSR)
		if i >= 8:
			var tones := [ch[0] + 24, ch[1] + 24, ch[2] + 24, ch[1] + 24]
			for s in 4:
				add_fm(l, i * bar + s * beat, midi(tones[s]), beat * 0.8, 0.07, 1.0, MSR)
				add_fm(r, i * bar + s * beat + 0.01, midi(tones[s]), beat * 0.8, 0.07, 1.0, MSR)
	finish_track("music_campaign", l, r, loop_len, 0.3)
