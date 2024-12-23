extends Spatial

var games = []
var index : int
var current_game_pid : int
var game_starting := false
var game_starting_timer : Timer
var tween_speed := 0.5

var settings : Dictionary

var move_just_pressed := false
var move_timer : Timer

onready var tween := get_node("Tween")
onready var header := get_node("Header")
onready var game_description := get_node("GameDescription")

func _ready() -> void:
  if OS.has_feature("standalone"):
    OS.window_fullscreen = true
    Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

  OS.execute("./bin/create_pid_file", [OS.get_process_id(), "menu"], true)

  move_timer = Timer.new()
  move_timer.connect("timeout", self, "_move_timeout")
  move_timer.set_one_shot(true)
  add_child(move_timer)

  game_starting_timer = Timer.new()
  game_starting_timer.connect("timeout", self, "_game_started")
  game_starting_timer.set_one_shot(true)
  add_child(game_starting_timer)

  settings = _import_json("./settings.json")
  print("current settings:")
  print(settings)

  if settings.has("header_color"):
    header.set("custom_colors/font_color", Color(settings.header_color))

  print("---")
  print("games:")

  var configs = []
  var dir = Directory.new()
  dir.open('./configs')
  dir.list_dir_begin()

  var filename = dir.get_next()
  while filename != "":
    if filename.ends_with(".json"):
      configs.append(dir.get_current_dir() + "/" + filename)
    filename = dir.get_next()

  dir.list_dir_end()

  configs.sort()

  for config_path in configs:
    var json_data = _import_json(config_path)
    # TODO: validate config data
    games.append(json_data)
    print(json_data)

  var i := 0
  while games.size() <= 9:
    games.push_back(games[i].duplicate())
    i += 1

  index = floor(games.size() / 2)

  for g in games:
    var thumb := MeshInstance.new()
    thumb.mesh = PlaneMesh.new()

    var image = Image.new()
    image.load("./games/" + g.thumb)
    var texture = ImageTexture.new()
    texture.create_from_image(image, 0)
    var material = SpatialMaterial.new()
    material.albedo_texture = texture
    thumb.mesh.surface_set_material(0, material)
    thumb.rotation_degrees.x = 90

    add_child(thumb)
    g.thumb_instance = thumb

  _update_thumbs()


func _update_thumbs(direction = 0) -> void:
  for i in games.size():
    var x = 2 + 0.3 * abs(i - index)
    var thumb = games[i].thumb_instance

    if i < index:
      if direction > 0 && i == 0:
        _interpolate_thumb_translation(thumb, -1 * x, -1.5, false)
        _interpolate_thumb_rotation(thumb, 75, false)
      else:
        _interpolate_thumb_translation(thumb, -1 * x, -1.5)
        _interpolate_thumb_rotation(thumb, 75)
    elif i > index:
      if direction < 0 && i == games.size() - 1:
        _interpolate_thumb_translation(thumb, x, -1.5, false)
        _interpolate_thumb_rotation(thumb, -75, false)
      else:
        _interpolate_thumb_translation(thumb, x, -1.5)
        _interpolate_thumb_rotation(thumb, -75)
    else:
      _interpolate_thumb_translation(thumb, 0, 0)
      _interpolate_thumb_rotation(thumb, 0)

      _update_game_description(games[i])

  tween.start()


func _interpolate_thumb_translation(thumb, x, z, animate = true) -> void:
  if animate:
    tween.interpolate_property(thumb, "translation", thumb.translation, Vector3(x, 0, z), tween_speed, Tween.TRANS_LINEAR, Tween.EASE_IN)
  else:
    thumb.translation = Vector3(x, 0, z)


func _interpolate_thumb_rotation(thumb, degrees, animate = true) -> void:
  if animate:
    tween.interpolate_property(thumb, "rotation_degrees", thumb.rotation_degrees, Vector3(90, degrees, 0), tween_speed, Tween.TRANS_LINEAR, Tween.EASE_IN)
  else:
    thumb.rotation_degrees = Vector3(90, degrees, 0)


func _update_game_description(data) -> void:
  game_description.text = data.title + "\n" + data.authors


func _set_system_volume(data) -> void:
  if data.has("volume"):
    OS.execute("./bin/set_volume", [data.volume], true)
  else:
    OS.execute("./bin/set_volume", [70], true)


func _input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed:
    match event.scancode:
      KEY_LEFT, KEY_A:
        if _can_move():
          _move_index(-1)
          _update_thumbs(-1)
      KEY_RIGHT, KEY_D:
        if _can_move():
          _move_index(1)
          _update_thumbs(1)
      KEY_ENTER, KEY_V, KEY_B, KEY_K, KEY_L:
        if !game_starting:
          print("launching " + games[index].title)
          current_game_pid = OS.execute("./games/" + games[index].filename, [], false)
          print("current game PID - " + str(current_game_pid))
          game_starting = true
          game_starting_timer.set_wait_time(3)
          game_starting_timer.start()
          OS.execute("./bin/create_pid_file", [current_game_pid, "game"], true)
          _set_system_volume(games[index])


func _notification(what) -> void:
  if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
    game_starting = false
    print("focus in")
  elif what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
    print("focus out")


func _game_started() -> void:
  game_starting = false


func _can_move() -> bool:
  if move_just_pressed:
    return false
  else:
    move_just_pressed = true
    print('cantmove')
    move_timer.set_wait_time(0.5)
    move_timer.start()
    return true

func _move_timeout() -> void:
  print('can move again')
  move_just_pressed = false


func _move_index(n: int) -> void:
  if n > 0:
    games.push_front(games.pop_back())
  elif n < 0:
    games.push_back(games.pop_front())


func _import_json(path: String) -> Dictionary:
  var file = File.new()
  file.open(path, file.READ)
  var json = file.get_as_text()
  var data = JSON.parse(json).result
  file.close()

  if data:
    return data
  else:
    return {}
