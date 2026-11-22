extends Node

var save_location = "user://pokemon_overlord.save"
var save_dict = {
		"player_bp": 0, 

		"options": {
			"bgm_volume": 1.0, 
			"se_volume": 1.0, 
		}, 

		"decks": {
			"ivysaur": true, 
			"charmeleon": true, 
			"wartortle": true, 
			"pikachu": false, 

			"bayleef": false, 
			"quilava": false, 
			"croconaw": false, 
			"clefairy": false, 

			"grovyle": false, 
			"combusken": false, 
			"marshtomp": false, 
			"kirlia": false, 

			"grotle": false, 
			"monferno": false, 
			"prinplup": false, 
			"magmar": false, 

			"servine": false, 
			"pignite": false, 
			"dewott": false, 
			"zorua": false, 

			"quilladin": false, 
			"braixen": false, 
			"frogadier": false, 
			"doublade": false, 
		}, 

		"decks_cleared": {
			"ivysaur": false, 
			"charmeleon": false, 
			"wartortle": false, 
			"pikachu": false, 

			"bayleef": false, 
			"quilava": false, 
			"croconaw": false, 
			"clefairy": false, 

			"grovyle": false, 
			"combusken": false, 
			"marshtomp": false, 
			"kirlia": false, 

			"grotle": false, 
			"monferno": false, 
			"prinplup": false, 
			"magmar": false, 

			"servine": false, 
			"pignite": false, 
			"dewott": false, 
			"zorua": false, 

			"quilladin": false, 
			"braixen": false, 
			"frogadier": false, 
			"doublade": false, 
		}, 

		"LC": {
			"Brock": true, 
			"Misty": false, 
			"Surge": false, 
			"Erika": false, 
			"Koga": false, 
			"Sabrina": false, 
			"Blaine": false, 
			"Giovanni": false, 
			"Lorelei": false, 
			"Bruno": false, 
			"Agatha": false, 
			"Lance": false, 
			"Falkner": false, 
			"Bugsy": false, 
			"Whitney": false, 
			"Morty": false, 
			"Chuck": false, 
			"Janine": false, 
			"Jasmine": false, 
			"Clair": false, 
			"Karen": false, 
			"Koichi": false, 
			"Bill": false, 
			"Roxanne": false, 
			"Brawly": false, 
			"Wattson": false, 
			"Flannery": false, 
			"Norman": false, 
			"Winona": false, 
			"Wallace": false, 
			"Sidney": false, 
			"Phoebe": false, 
			"Drake": false, 
			"Steven": false, 
			"Roark": false, 
			"Gardenia": false, 
			"Fantina": false, 
			"Candice": false, 
			"Volkner": false, 
			"Flint": false, 
			"Cyrus": false, 
			"Cynthia": false, 
			"Cilan": false, 
			"Lenora": false, 
			"Burgh": false, 
			"Elesa": false, 
			"Clay": false, 
			"Skyla": false, 
			"Iris": false, 
			"Roxie": false, 
			"Alder": false, 
			"Red": false, 
			"Leaf": false, 
			"Blue": false, 
			"Gold": false, 
			"Kris": false, 
			"Silver": false, 
			"Brendan": false, 
			"May": false, 
			"Wally": false, 
			"Lucas": false, 
			"Dawn": false, 
			"Barry": false, 
			"Hilbert": false, 
			"Hilda": false, 
			"N": false, 
			"Calem": false, 
			"Serena": false, 
			"Tierno": false, 
			"Maxie": false, 
			"Archie": false, 
			"Ghetsis": false, 
			"Sycamore": false, 
			"Lysandre": false, 
			"Diantha": false, 
			"Wes": false, 
			"Oak": false, 
			"Elm": false, 
			"Birch": false, 
			"Rowan": false, 
			"Juniper": false, 
			"Demi-Fiend": false, 
			"Yugi": false, 
			"Kaiba": false
		}, 

		"LC_cleared": {
			"Brock": false, 
			"Misty": false, 
			"Surge": false, 
			"Erika": false, 
			"Koga": false, 
			"Sabrina": false, 
			"Blaine": false, 
			"Giovanni": false, 
			"Lorelei": false, 
			"Bruno": false, 
			"Agatha": false, 
			"Lance": false, 
			"Falkner": false, 
			"Bugsy": false, 
			"Whitney": false, 
			"Morty": false, 
			"Chuck": false, 
			"Janine": false, 
			"Jasmine": false, 
			"Clair": false, 
			"Karen": false, 
			"Koichi": false, 
			"Bill": false, 
			"Roxanne": false, 
			"Brawly": false, 
			"Wattson": false, 
			"Flannery": false, 
			"Norman": false, 
			"Winona": false, 
			"Wallace": false, 
			"Sidney": false, 
			"Phoebe": false, 
			"Drake": false, 
			"Steven": false, 
			"Roark": false, 
			"Gardenia": false, 
			"Fantina": false, 
			"Candice": false, 
			"Volkner": false, 
			"Flint": false, 
			"Cyrus": false, 
			"Cynthia": false, 
			"Cilan": false, 
			"Lenora": false, 
			"Burgh": false, 
			"Elesa": false, 
			"Clay": false, 
			"Skyla": false, 
			"Iris": false, 
			"Roxie": false, 
			"Alder": false, 
			"Red": false, 
			"Leaf": false, 
			"Blue": false, 
			"Gold": false, 
			"Kris": false, 
			"Silver": false, 
			"Brendan": false, 
			"May": false, 
			"Wally": false, 
			"Lucas": false, 
			"Dawn": false, 
			"Barry": false, 
			"Hilbert": false, 
			"Hilda": false, 
			"N": false, 
			"Calem": false, 
			"Serena": false, 
			"Tierno": false, 
			"Maxie": false, 
			"Archie": false, 
			"Ghetsis": false, 
			"Sycamore": false, 
			"Lysandre": false, 
			"Diantha": false, 
			"Wes": false, 
			"Oak": false, 
			"Elm": false, 
			"Birch": false, 
			"Rowan": false, 
			"Juniper": false, 
			"Demi-Fiend": false, 
			"Yugi": false, 
			"Kaiba": false
		}, 

		"event_flags":
			{
				"yugi": false, 
				"kaiba": false, 
				"demi_fiend": false, 
				"mewtwo_unlocked": false, 
				"mewtwo_cleared": false, 
		}, 

		"suspended_game":
			{
		}, 
	}




func save_data():
	print("saving")
	if FileAccess.file_exists(save_location):
		save_dict["player_bp"] = globals.player_bp
		save_dict["options"] = globals.options.duplicate()
		save_dict["decks"] = globals.decks_unlocked.duplicate()
		save_dict["decks_cleared"] = globals.decks_cleared.duplicate()
		save_dict["LC"] = globals.LC_unlocked.duplicate()
		save_dict["LC_cleared"] = globals.LC_cleared.duplicate()
		save_dict["event_flags"] = globals.event_flags.duplicate()
		save_dict["options"] = globals.options.duplicate()
		save_dict["suspended_game"] = globals.suspended_game.duplicate()

	var file = FileAccess.open(save_location, FileAccess.WRITE)

	file.store_var(save_dict.duplicate())
	file.close()

func load_data():
	var save_file
	var data

	if not FileAccess.file_exists(save_location):
		print("save not found")
		await save_data()

		return
	print("loading")
	save_file = FileAccess.open(save_location, FileAccess.READ)
	data = save_file.get_var()

	save_file.close()

	var saved_data = data.duplicate()
	globals.player_bp = saved_data["player_bp"]
	globals.options = saved_data["options"]
	globals.decks_unlocked = saved_data["decks"]
	globals.decks_cleared = saved_data["decks_cleared"]
	globals.LC_unlocked = saved_data["LC"]
	globals.LC_cleared = saved_data["LC_cleared"]
	globals.event_flags = saved_data["event_flags"]
	globals.options = saved_data["options"]
	globals.suspended_game = saved_data["suspended_game"]

func initialize():
	var file = FileAccess.open(save_location, FileAccess.WRITE)
	file.store_var(save_dict.duplicate())
	file.close()
