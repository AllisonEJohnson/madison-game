class_name SafeNames
extends RefCounted
## Kid-safe naming and chat. Players never type free text that other players
## can see: display names and pet names are built from word lists, and chat
## uses preset phrases. The server re-checks everything it receives.

const NAME_ADJECTIVES := [
	"Sunny", "Happy", "Brave", "Sparkly", "Cozy", "Bouncy", "Clever", "Gentle", "Lucky", "Mighty",
	"Silly", "Speedy", "Starry", "Sleepy", "Jolly", "Fuzzy", "Golden", "Rainbow", "Cosmic", "Breezy",
]
const NAME_NOUNS := [
	"Otter", "Panda", "Fox", "Koala", "Penguin", "Tiger", "Dolphin", "Owl", "Bunny", "Turtle",
	"Comet", "Cloud", "Maple", "Pebble", "Rocket", "Muffin", "Dragon", "Pixel", "Meadow", "Star",
]
const PET_NAMES := [
	"Biscuit", "Pepper", "Noodle", "Mochi", "Pickles", "Waffles", "Sprout", "Bean", "Ziggy", "Clover",
	"Peanut", "Toffee", "Bubbles", "Pip", "Sunny", "Nugget", "Marble", "Juniper", "Taco", "Button",
	"Cinnamon", "Pudding", "Rascal", "Willow", "Echo", "Doodle", "Puddle", "Sherbet", "Ember", "Gizmo",
]
const CHAT_PHRASES := [
	"Hi!", "Bye!", "Nice house!", "I love your pet!", "Want to be friends?", "Follow me!",
	"Come visit my house!", "Cool outfit!", "Thank you!", "Yes!", "No thanks!", "Good game!",
	"Let's explore!", "Wait for me!", "Haha!", "Wow!",
]


static func make_display_name(adjective: int, noun: int, number: int) -> String:
	adjective = clampi(adjective, 0, NAME_ADJECTIVES.size() - 1)
	noun = clampi(noun, 0, NAME_NOUNS.size() - 1)
	return "%s%s%d" % [NAME_ADJECTIVES[adjective], NAME_NOUNS[noun], clampi(number, 0, 99)]


static func random_name_parts(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"adjective": rng.randi_range(0, NAME_ADJECTIVES.size() - 1),
		"noun": rng.randi_range(0, NAME_NOUNS.size() - 1),
		"number": rng.randi_range(1, 99),
	}


static func clean_name_parts(parts: Variant) -> Dictionary:
	var out := {"adjective": 0, "noun": 0, "number": 1}
	if parts is Dictionary:
		for key in out:
			var v = parts.get(key)
			if v is int or v is float:
				out[key] = int(v)
	out["adjective"] = clampi(out["adjective"], 0, NAME_ADJECTIVES.size() - 1)
	out["noun"] = clampi(out["noun"], 0, NAME_NOUNS.size() - 1)
	out["number"] = clampi(out["number"], 0, 99)
	return out


static func display_name(parts: Variant) -> String:
	var p := clean_name_parts(parts)
	return make_display_name(p["adjective"], p["noun"], p["number"])


static func clean_pet_name(pet_name: String) -> String:
	return pet_name if pet_name in PET_NAMES else PET_NAMES[0]


static func phrase(index: Variant) -> String:
	if not (index is int or index is float):
		return ""
	var i := int(index)
	return CHAT_PHRASES[i] if i >= 0 and i < CHAT_PHRASES.size() else ""
