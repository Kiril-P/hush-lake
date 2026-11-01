extends Node
## Shared incremental core: one currency, upgrades with scaling costs, autosave.
## Games put their own serialisable state in `extra` (filled in on `about_to_save`).

signal currency_changed(amount: float)
signal upgrade_bought(id: String, level: int)
signal about_to_save

const SAVE_INTERVAL := 10.0

var currency: float = 0.0
var upgrades: Dictionary = {}  # id -> level
var extra: Dictionary = {}     # game-specific state
var meta: Dictionary = {}      # permanent progress that survives starting a new run (e.g. pearls, perks)
var save_slot := "default"     # each game sets its own before load_game()
var autosave := true
var _since_save := 0.0

func _process(delta: float) -> void:
	_since_save += delta
	if autosave and _since_save >= SAVE_INTERVAL:
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave:
		save_game()

func add(amount: float) -> void:
	currency += amount
	currency_changed.emit(currency)

func level(id: String) -> int:
	return upgrades.get(id, 0)

func cost(id: String, base: float, growth: float = 1.15) -> float:
	return ceil(base * pow(growth, level(id)))

func try_buy(id: String, base: float, growth: float = 1.15) -> bool:
	var c := cost(id, base, growth)
	if currency < c:
		return false
	currency -= c
	upgrades[id] = level(id) + 1
	currency_changed.emit(currency)
	upgrade_bought.emit(id, upgrades[id])
	return true

func _path() -> String:
	return "user://%s.save.json" % save_slot

func has_save() -> bool:
	return FileAccess.file_exists(_path())

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(_path())

## Wipes the current run. `keep_meta` keeps permanent progress (used when starting a new run on purpose).
func reset(keep_meta := false) -> void:
	currency = 0.0
	upgrades = {}
	extra = {}
	if not keep_meta:
		meta = {}

## `snapshot` = ask the game to fill `extra` first; pass false to write the state exactly as it is.
func save_game(snapshot := true) -> void:
	_since_save = 0.0
	if snapshot:
		about_to_save.emit()
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"currency": currency, "upgrades": upgrades, "extra": extra, "meta": meta,
			"saved_at": Time.get_unix_time_from_system()}))

## Returns seconds elapsed since last save (0 if no save), for offline progress.
func load_game() -> float:
	if not has_save():
		return 0.0
	var data = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	if typeof(data) != TYPE_DICTIONARY:
		return 0.0
	currency = data.get("currency", 0.0)
	upgrades = {}
	for k in data.get("upgrades", {}):
		upgrades[k] = int(data["upgrades"][k])
	extra = data.get("extra", {})
	meta = data.get("meta", {})
	currency_changed.emit(currency)
	var now := Time.get_unix_time_from_system()
	return maxf(0.0, now - data.get("saved_at", now))
