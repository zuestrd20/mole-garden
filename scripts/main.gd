extends Node2D

const ROUND_SECONDS := 60.0
const HOLE_NUMBERS := [7, 8, 9, 4, 5, 6, 1, 2, 3]
const CREAM := Color('#f9edc7')
const MUTED := Color('#a5bfa8')
const GREEN := Color('#75b97a')
const GOLD := Color('#f7c565')
const PANEL := Color('#244c3c')
const DARK := Color('#122b25')
var font: Font = preload('res://assets/garden_font.otf')
var cover: Texture2D = preload('res://gallery/cover.png')
var art := {}
var sounds := {}
var voices: Array[AudioStreamPlayer] = []
var holes: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var persistence_enabled := true
var mode := 'title'
var score := 0
var combo := 0
var best_combo := 0
var hits := 0
var attempts := 0
var bombs := 0
var best := 0
var left := ROUND_SECONDS
var spawn_clock := 0.0
var elapsed := 0.0
var muted := false
var cursor := Vector2(560,400)
var swing := 0.0
var shake := 0.0
var voice_index := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for key in ['mole','gold','bomb','hole','hammer','flower','background']:
		art[key] = load('res://assets/' + key + '.png')
	for key in ['hit','gold_sound','bomb_sound','miss','start']:
		sounds[key] = load('res://assets/' + key + '.wav')
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		voices.append(player)
	for i in 9:
		holes.append({'pos':Vector2(350 + (i % 3)*210,340 + (i / 3)*135), 'kind':'', 'life':0.0, 'maxlife':1.0, 'flash':0.0})
	var file := ConfigFile.new()
	if persistence_enabled and file.load('user://garden.cfg') == OK:
		best = int(file.get_value('records','best',0))
		muted = bool(file.get_value('settings','muted',false))
	if '--qa-play' in OS.get_cmdline_user_args():
		start_round()
		for i in [0,2,4,7]:
			holes[i].kind = 'gold' if i == 2 else ('bomb' if i == 7 else 'mole')
			holes[i].life = 40.0
			holes[i].maxlife = 40.0
		set_process(false)
	queue_redraw()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--qa-screenshot='):
			capture_screenshot.call_deferred(arg.trim_prefix('--qa-screenshot='))

func capture_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	print('SCREENSHOT: ',path,' status=',result)
	get_tree().quit(0 if result == OK else 1)

func save_settings() -> void:
	if not persistence_enabled: return
	var file := ConfigFile.new()
	file.set_value('records','best',best)
	file.set_value('settings','muted',muted)
	file.save('user://garden.cfg')

func sfx(key: String) -> void:
	if muted: return
	var player := voices[voice_index % voices.size()]
	voice_index += 1
	player.stream = sounds[key]
	player.play()

func start_round() -> void:
	mode = 'playing'
	score = 0
	combo = 0
	best_combo = 0
	hits = 0
	attempts = 0
	bombs = 0
	left = ROUND_SECONDS
	spawn_clock = 0.25
	particles.clear()
	for h in holes:
		h.kind = ''
		h.life = 0.0
		h.flash = 0.0
	sfx('start')
	queue_redraw()

func finish_round() -> void:
	mode = 'results'
	best = maxi(best,score)
	save_settings()
	for h in holes: h.kind = ''
	sfx('gold_sound')

func toggle_pause() -> void:
	if mode == 'playing': mode = 'paused'
	elif mode == 'paused': mode = 'playing'
	queue_redraw()

func spawn_mole() -> void:
	var free: Array[int] = []
	for i in holes.size():
		if holes[i].kind == '': free.append(i)
	if free.is_empty(): return
	var h: Dictionary = holes[free[rng.randi_range(0,free.size()-1)]]
	var roll := rng.randf()
	h.kind = 'bomb' if roll < 0.16 else ('gold' if roll < 0.28 else 'mole')
	h.maxlife = lerpf(1.65,0.85,1.0-left/ROUND_SECONDS)
	h.life = h.maxlife

func strike(index: int) -> void:
	if mode != 'playing' or index < 0 or index >= 9: return
	var h: Dictionary = holes[index]
	attempts += 1
	swing = 0.16
	cursor = h.pos + Vector2(5,-22)
	var caption := ''
	var color := CREAM
	if h.kind == 'bomb':
		score = maxi(0,score-30)
		combo = 0
		bombs += 1
		shake = 0.25
		caption = '−30'
		color = Color('#f39a82')
		sfx('bomb_sound')
	elif h.kind != '':
		combo += 1
		hits += 1
		best_combo = maxi(best_combo,combo)
		var multiplier := 1 + mini(3,combo/5)
		var points := (30 if h.kind == 'gold' else 10)*multiplier
		score += points
		caption = '+' + str(points)
		color = GOLD if h.kind == 'gold' else CREAM
		sfx('gold_sound' if h.kind == 'gold' else 'hit')
		for i in 9:
			particles.append({'pos':h.pos+Vector2(0,-35),'vel':Vector2(rng.randf_range(-110,110),rng.randf_range(-170,-60)),'life':0.55,'text':'','color':color})
	else:
		combo = 0
		caption = '落空'
		color = MUTED
		sfx('miss')
	h.kind = ''
	h.life = 0.0
	h.flash = 0.18
	particles.append({'pos':h.pos+Vector2(0,-50),'vel':Vector2(0,-45),'life':0.8,'text':caption,'color':color})
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	swing = maxf(0,swing-delta)
	shake = maxf(0,shake-delta)
	if mode == 'playing':
		left = maxf(0,left-delta)
		if left <= 0:
			finish_round()
		else:
			spawn_clock -= delta
			if spawn_clock <= 0:
				spawn_mole()
				spawn_clock = lerpf(0.72,0.32,1.0-left/ROUND_SECONDS)
			for h in holes:
				if h.kind != '':
					h.life -= delta
					if h.life <= 0:
						if h.kind != 'bomb': combo = 0
						h.kind = ''
	if mode != 'paused':
		for h in holes: h.flash = maxf(0,h.flash-delta)
		for p in particles:
			p.life -= delta
			p.pos += p.vel*delta
			if p.text == '': p.vel.y += 300*delta
		particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor = get_global_mouse_position()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			muted = not muted
			save_settings()
		elif event.keycode in [KEY_ESCAPE,KEY_P]: toggle_pause()
		elif event.keycode in [KEY_ENTER,KEY_SPACE]:
			if mode in ['title','results']: start_round()
			elif mode == 'paused': toggle_pause()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9: strike(HOLE_NUMBERS.find(event.keycode-KEY_1+1))
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9: strike(HOLE_NUMBERS.find(event.keycode-KEY_KP_1+1))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventScreenTouch and event.pressed:
		click(get_global_transform_with_canvas().affine_inverse() * event.position)

func click(pos: Vector2) -> void:
	if Rect2(916,42,152,42).has_point(pos):
		muted = not muted
		save_settings()
	elif Rect2(792,42,112,42).has_point(pos): toggle_pause()
	elif mode == 'playing':
		for i in holes.size():
			if Rect2(holes[i].pos-Vector2(83,97),Vector2(166,132)).has_point(pos):
				strike(i)
				break
	elif (Rect2(182,510,326,60) if mode == 'title' else Rect2(397,510,326,60)).has_point(pos):
		if mode == 'paused': toggle_pause()
		else: start_round()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == 'playing':
		mode = 'paused'

func box(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT, width: float = 2) -> void:
	draw_rect(rect,color)
	if border.a > 0: draw_rect(rect,border,false,width)

func label_at(text: String, pos: Vector2, size: int, color: Color = CREAM) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(text: String, x: float, y: float, size: int, color: Color = CREAM) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	label_at(text,Vector2(x-width/2,y),size,color)

func button(rect: Rect2, text: String, primary := false) -> void:
	var hover := rect.has_point(get_global_mouse_position())
	box(Rect2(rect.position+Vector2(0,4),rect.size),DARK)
	box(rect,Color('#f9d583') if primary and hover else (GOLD if primary else (Color('#42694c') if hover else PANEL)),Color('#ead59c') if primary else Color('#547c56'))
	centered(text,rect.get_center().x,rect.position.y+rect.size.y/2+8,21,DARK if primary else CREAM)

func _draw() -> void:
	if art.is_empty(): return
	draw_texture_rect(art.background,Rect2(0,0,1120,800),false)
	# Framed arcade cabinet and editorial header.
	box(Rect2(24,24,1072,752),Color.TRANSPARENT,Color('#47664a'))
	label_at('MOLE GARDEN',Vector2(52,53),16,GOLD)
	label_at('地鼠小花園',Vector2(50,99),37)
	label_at('一槌一朵好心情',Vector2(290,92),17,MUTED)
	button(Rect2(792,42,112,42),'繼續' if mode == 'paused' else '暫停 P')
	button(Rect2(916,42,152,42),'音效：關 M' if muted else '音效：開 M')
	# HUD
	var cards := [Rect2(52,126,308,82),Rect2(376,126,308,82),Rect2(700,126,368,82)]
	for r in cards: box(r,PANEL,Color('#42664a'))
	label_at('本局得分',Vector2(70,153),15,MUTED)
	label_at('%04d' % score,Vector2(70,193),34,GOLD)
	label_at('最佳  %04d' % best,Vector2(221,185),17,CREAM)
	label_at('連擊加成',Vector2(394,153),15,MUTED)
	label_at('%02d' % combo,Vector2(394,193),34)
	label_at('×%d  /  每 5 連擊升級' % (1+mini(3,combo/5)),Vector2(476,185),16,GOLD)
	label_at('剩餘時間',Vector2(718,153),15,MUTED)
	label_at('%02d' % ceili(left),Vector2(988,166),30,GOLD if left > 10 else Color('#f49c81'))
	box(Rect2(718,180,330,8),DARK)
	box(Rect2(718,180,330*left/ROUND_SECONDS,8),GREEN if left > 10 else Color('#f49c81'))
	# Garden bed with pixel scalloped rim and planted border.
	box(Rect2(52,227,1016,489),Color('#101f1e'))
	box(Rect2(60,221,1000,487),Color('#426546'),Color('#96a069'),4)
	box(Rect2(70,231,980,467),Color('#78935b'))
	for y in range(240,697,24):
		for x in range(80,1048,24):
			if (x/24+y/24)%3 == 0: box(Rect2(x,y,3,3),Color('#849e63'))
	# fence sides / flowers
	for x in [100,980]:
		for y in [288,418,548,646]:
			draw_texture_rect(art.flower,Rect2(x,y,32,40),false)
	for i in 9:
		var h: Dictionary = holes[i]
		var pos: Vector2 = h.pos
		if shake > 0: pos += Vector2(sin(elapsed*100)*4,0)
		draw_texture_rect(art.hole,Rect2(pos-Vector2(90,20),Vector2(180,75)),false)
		var kind: String = h.kind
		if mode == 'title' and i in [0,2,7]: kind = 'gold' if i == 2 else 'mole'
		if kind != '':
			var lift := 0.0
			if mode == 'playing': lift = maxf(0,(0.13-minf(h.life,h.maxlife-h.life))/.13)*26
			draw_texture_rect(art[kind],Rect2(pos-Vector2(72,105-lift),Vector2(144,144)),false)
			# Front soil lip naturally masks sprite feet.
			box(Rect2(pos+Vector2(-64,28),Vector2(128,9)),Color('#9a713f'))
			box(Rect2(pos+Vector2(-48,37),Vector2(96,6)),Color('#65814c'))
		if h.flash > 0:
			draw_arc(pos,51,0,TAU,20,CREAM,3)
		box(Rect2(pos+Vector2(-12,51),Vector2(24,23)),Color('#527445'))
		centered(str(HOLE_NUMBERS[i]),pos.x,pos.y+69,16,Color('#dfdfb1'))
	for p in particles:
		var col: Color = p.color
		col.a = minf(1,p.life*3)
		if p.text == '': box(Rect2(p.pos,Vector2(6,6)),col)
		else: centered(p.text,p.pos.x,p.pos.y,27,col)
	# Legend
	draw_texture_rect(art.mole,Rect2(70,728,39,39),false)
	label_at('+10',Vector2(114,755),18)
	draw_texture_rect(art.gold,Rect2(204,726,39,39),false)
	label_at('+30',Vector2(248,755),18,GOLD)
	draw_texture_rect(art.bomb,Rect2(338,726,39,39),false)
	label_at('−30，別敲！',Vector2(382,755),18,Color('#f5ad92'))
	label_at('點擊 / 觸控 / 數字 1–9',Vector2(734,752),18,MUTED)
	if mode == 'title':
		draw_texture_rect_region(cover,Rect2(70,231,980,467),Rect2(0,70,1672,796))
		draw_texture_rect_region(cover,Rect2(580,231,470,467),Rect2(363,5,946,936))
	if mode in ['title','paused','results']: draw_overlay()
	elif swing > 0:
		draw_set_transform(cursor+Vector2(14,-65),-0.55)
		draw_texture_rect(art.hammer,Rect2(-30,-30,96,96),false)
		draw_set_transform(Vector2.ZERO)

func draw_overlay() -> void:
	box(Rect2(70,231,980,467),Color(0.06,0.14,0.11,0.16 if mode == 'title' else 0.70))
	if mode == 'title': draw_set_transform(Vector2(-215,0))
	box(Rect2(294,281,532,357),DARK)
	box(Rect2(286,273,548,357),Color('#234535'),GOLD,3)
	box(Rect2(298,285,524,333),Color.TRANSPARENT,Color('#64815a'))
	if mode == 'title':
		centered('WELCOME TO THE GARDEN',560,316,14,GOLD)
		centered('地鼠出沒，準備開槌！',560,365,32)
		centered('60 秒花園挑戰',560,404,21,GOLD)
		centered('敲地鼠、抓金鼠，避開炸彈。',560,450,20)
		centered('每 5 次連擊提升倍率，最高 ×4！',560,481,18,MUTED)
		button(Rect2(397,510,326,60),'開始遊戲  ENTER',true)
		centered('數字鍵排列：上排 7 8 9 · 中排 4 5 6 · 下排 1 2 3',560,602,15,MUTED)
		draw_set_transform(Vector2.ZERO)
	elif mode == 'paused':
		centered('TAKE A LITTLE BREAK',560,325,14,GOLD)
		centered('花園休息中',560,386,37)
		centered('時間已停下，隨時可以回來。',560,449,21,MUTED)
		button(Rect2(397,510,326,60),'繼續遊戲  P',true)
	else:
		centered('A GOOD DAY IN THE GARDEN',560,316,14,GOLD)
		centered('採收完成！',560,361,31)
		centered(str(score)+' 分',560,421,48,GOLD)
		var accuracy := roundi(float(hits)/maxi(1,attempts)*100)
		centered('最高連擊 %d   ·   命中率 %d%%' % [best_combo,accuracy],560,469,20)
		button(Rect2(397,510,326,60),'再玩一次  ENTER',true)
		centered('個人最佳  '+str(best)+'  /  炸彈誤擊 '+str(bombs),560,602,16,MUTED)
