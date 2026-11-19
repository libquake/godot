@tool
class_name QuakeLiquids
extends RefCounted
## Liquid kinds by texture name and their look, after quaken and Quake's v_cshift.

const GROUP := &"quake_liquid"
const KIND_META := &"quake_liquid_kind"
const COLOR_META := &"quake_liquid_color"

## above 1 the surface glows
const BRIGHTNESS := {"lava": 3.0}

## worldspawn keys of modern engines, they win over the import options
const ALPHA_KEYS := {
	"water": "_wateralpha",
	"slime": "_slimealpha",
	"lava": "_lavaalpha",
	"teleport": "_telealpha",
}

## shift is Quake's cshift percent
const VIEWS := {
	"water": {"shift": 128.0 / 255.0, "fog_density": 0.2},
	"slime": {"shift": 150.0 / 255.0, "fog_density": 0.35},
	"lava": {"shift": 150.0 / 255.0, "fog_density": 0.6},
}

## for liquid textures without pixels
const FALLBACK_COLORS := {
	"water": Color8(130, 80, 50),
	"slime": Color8(0, 25, 5),
	"lava": Color8(255, 80, 0),
	"teleport": Color8(0, 0, 0),
}


static func is_liquid(texture_name: String) -> bool:
	return texture_name.get_file().begins_with("*")


static func kind_of(texture_name: String) -> String:
	var name := texture_name.get_file().to_lower().trim_prefix("*")
	if name.begins_with("lava"):
		return "lava"
	if name.begins_with("slime"):
		return "slime"
	if name.begins_with("tele"):
		return "teleport"
	return "water"
