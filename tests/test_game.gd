extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error('FAIL: '+message)
	else: print('PASS: '+message)
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var game = load('res://main.tscn').instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.muted = true
	check(game.mode == 'title','Initial title mode')
	check(game.holes.size() == 9,'Nine holes')
	game.start_round()
	check(game.left == 60 and game.score == 0,'Round reset')
	game.holes[0].kind = 'mole'
	game.strike(0)
	check(game.score == 10 and game.combo == 1,'Normal hit scores ten')
	game.strike(0)
	check(game.score == 10 and game.combo == 0,'Repeated click cannot score twice')
	game.holes[1].kind = 'gold'
	game.strike(1)
	check(game.score == 40,'Golden mole scores thirty')
	for i in 4:
		game.holes[2].kind = 'mole'
		game.strike(2)
	check(game.combo == 5 and game.score == 90,'Fifth combo enables x2')
	game.combo = 19
	game.holes[0].kind = 'gold'
	game.strike(0)
	check(game.score == 210 and game.combo == 20,'Multiplier capped at four')
	game.holes[0].kind = 'bomb'
	game.strike(0)
	check(game.score == 180 and game.combo == 0 and game.bombs == 1,'Bomb penalty and combo reset')
	game.score = 5
	game.holes[0].kind = 'bomb'
	game.strike(0)
	check(game.score == 0,'Score cannot become negative')
	game.toggle_pause()
	var before = game.left
	game._process(2)
	game.holes[0].kind = 'gold'
	game.strike(0)
	check(game.left == before and game.score == 0,'Pause freezes timer and ignores strikes')
	game.toggle_pause()
	game.holes[0].kind = 'mole'
	game.holes[0].life = .01
	game.combo = 5
	game.spawn_clock = 10
	game._process(.02)
	check(game.combo == 0 and game.holes[0].kind == '','Escaped mole resets combo')
	game.combo = 4
	game.holes[0].kind = 'bomb'
	game.holes[0].life = .01
	game._process(.02)
	check(game.combo == 4,'Avoided bomb preserves combo')
	game.left = .01
	game.score = 777
	game._process(.02)
	check(game.mode == 'results' and game.best >= 777,'Timer ends round and records best')
	game.strike(0)
	check(game.score == 777,'Results screen ignores strikes')
	game.start_round()
	check(game.score == 0 and game.combo == 0 and game.hits == 0 and game.attempts == 0 and game.left == 60,'Restart clears all round state')
	for i in 25: game.spawn_mole()
	check(game.holes.filter(func(h): return h.kind != '').size() == 9,'Spawn respects occupied holes and full grid')
	game.mode = 'title'
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	game._unhandled_input(key)
	check(game.mode == 'playing','Enter starts round')
	game.holes[2].kind = 'mole'
	key.keycode = KEY_9
	game._unhandled_input(key)
	check(game.score == 10,'Keyboard nine maps top-right hole')
	game.click(game.holes[4].pos)
	check(game.attempts == 2,'Pointer maps center hole')
	game.mode = 'paused'
	game.click(Vector2(560,540))
	check(game.mode == 'playing','Resume button works')
	game.mode = 'title'
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(340,540)
	game._unhandled_input(mouse)
	check(game.mode == 'playing','Mouse event coordinates start title without moving pointer')
	game.holes[3].kind = 'mole'
	mouse.position = game.holes[3].pos
	game._unhandled_input(mouse)
	check(game.score == 10,'Mouse event coordinates strike intended hole')
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.holes[6].pos
	game.holes[6].kind = 'gold'
	game._unhandled_input(touch)
	check(game.score == 40,'Touch event coordinates strike intended hole')
	var expected_numbers := [7,8,9,4,5,6,1,2,3]
	check(game.HOLE_NUMBERS == expected_numbers,'Visible labels use keypad spatial layout')
	for first_key in [KEY_1,KEY_KP_1]:
		for index in 9:
			game.start_round()
			for h in game.holes: h.kind = 'mole'
			key.keycode = first_key + expected_numbers[index] - 1
			game._unhandled_input(key)
			check(game.score == 10 and game.holes[index].kind == '' and game.holes.filter(func(h): return h.kind == 'mole').size() == 8,
				'%s %d maps exactly to hole index %d' % ['Number row' if first_key == KEY_1 else 'Numpad',expected_numbers[index],index])
	for input_kind in ['mouse','touch']:
		for index in 9:
			game.start_round()
			for h in game.holes: h.kind = 'mole'
			var event: InputEvent = mouse if input_kind == 'mouse' else touch
			event.position = game.holes[index].pos
			game._unhandled_input(event)
			check(game.score == 10 and game.holes[index].kind == '' and game.holes.filter(func(h): return h.kind == 'mole').size() == 8,
				'%s still hits spatial hole index %d' % [input_kind,index])
	print('TEST SUMMARY: %d checks, %d failures' % [checks,failures])
	quit(1 if failures else 0)
