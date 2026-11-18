extends QuakeTest


func test_comments_describe_the_fgd() -> void:
	var docs := QuakeEntityClass.script_docs(load("res://fixtures/documented_entity.gd"))
	check_equal(docs.get(""), "Slides open. Second line.", "the class, right below extends")
	check_equal(docs.get("wait"), "Seconds before closing.", "an @export variable")
	check_equal(docs.get("lip"), "Units it sticks out.", "the annotation on its own line")
	check_equal(docs.get("speed"), "Units per second.", "a variable of the base script")
	check(not docs.has("bare") and not docs.has("hidden"), "no comment, no export: %s" % docs)
	check(not QuakeEntityClass.script_docs(load("res://fixtures/undocumented_class.gd")).has(""),
			"a comment after an empty line belongs to the variable")


func test_explicit_descriptions_win() -> void:
	var entity_class := QuakeEntityClass.new()
	entity_class.classname = "func_documented"
	entity_class.type = QuakeEntityClass.Type.BRUSH
	entity_class.node_script = load("res://fixtures/documented_entity.gd")
	entity_class.property_descriptions.assign({"wait": "Own text"})
	var fgd := entity_class.to_fgd()
	check(fgd.contains('= func_documented : "Slides open. Second line."'), fgd)
	check(fgd.contains('wait(float) : "Own text"'), fgd)
	check(fgd.contains('speed(float) : "Units per second."'), fgd)
	entity_class.description = "Own class text"
	check(entity_class.to_fgd().contains(': "Own class text"'), "the description wins")
