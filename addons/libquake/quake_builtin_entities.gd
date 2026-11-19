@tool
class_name QuakeBuiltinEntities
extends RefCounted
## What libquake reads on its own, for the FGD: worldspawn and light keys, known brush entities.

## An Area3D in this group, for a character controller to climb.
const LADDER := "func_ladder"


static func classes() -> Array[QuakeEntityClass]:
	return [
		_entity("worldspawn", QuakeEntityClass.Type.BRUSH, "The world", {
			"wad": "",
			"_meshlib": false,
			"_minlight": 0,
			"_sunlight": 0,
			"_sun_mangle": "0 -90 0",
			"_sunlight_color": Color(1, 1, 1),
			"_wateralpha": 0.6,
			"_slimealpha": 0.7,
			"_lavaalpha": 0.85,
			"_telealpha": 1.0,
		}, {
			"wad": "Semicolon separated wad files",
			"_meshlib": "The map is a set of pieces: each group becomes a scene to place in levels",
			"_minlight": "Minimum light level",
			"_sunlight": "Brightness of the sun",
			"_sun_mangle": "Direction of the sun: yaw pitch roll",
		}),
		_entity("light", QuakeEntityClass.Type.POINT, "Point light, baked into the lightmap", {
			"light": 300,
			"_color": Color(1, 1, 1),
			"wait": 1.0,
			"delay": 0,
			"style": 0,
			"targetname": "",
			"mangle": "",
		}, {
			"light": "Brightness, also the radius in units",
			"wait": "Falloff scale, higher is shorter",
			"delay": "Falloff: 0 linear, 1 inverse, 2 inverse square, 3 none, 4 local minlight, 5 inverse square b",
			"style": "Light style, 1-31 animated",
			"mangle": "Spotlight direction: yaw pitch roll",
		}),
		_entity("func_detail", QuakeEntityClass.Type.BRUSH, "Detail brushes, own collision", {}, {}),
		_entity("func_illusionary", QuakeEntityClass.Type.BRUSH, "Visible, not solid", {}, {}),
		_ground_fog(),
		_entity(LADDER, QuakeEntityClass.Type.BRUSH,
				"Ladder volume, not drawn: an Area3D in the group func_ladder. Let it end a little above the upper floor",
				{}, {}),
	]


## The style choices are filled in when the FGD is exported.
static func _ground_fog() -> QuakeEntityClass:
	return _entity(QuakeGroundFog.CLASSNAME, QuakeEntityClass.Type.BRUSH,
			"Ground fog lying on the floor of the brush's bounds, the brush is not drawn", {
		"style": QuakeGroundFogStyle.names(),
	}, {
		"style": "Its look, a QuakeGroundFogStyle by file name",
	})


static func _entity(classname: String, type: QuakeEntityClass.Type, description: String,
		properties: Dictionary, property_descriptions: Dictionary) -> QuakeEntityClass:
	var entity_class := QuakeEntityClass.new()
	entity_class.classname = classname
	entity_class.type = type
	entity_class.description = description
	entity_class.properties.assign(properties)
	entity_class.property_descriptions.assign(property_descriptions)
	return entity_class
