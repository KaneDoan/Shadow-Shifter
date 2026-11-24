extends RefCounted

const BOUNDS := Vector2(1184, 1216)
const START_ANCHOR := "cart"
const SWITCH := Vector2(592, 96)
const EXIT := Vector2(1136, 416)
const ROOMS := [
	{"id": "courtyard", "name": "THE COURTYARD", "rect": Rect2(32, 448, 320, 320)},
	{"id": "gallery", "name": "THE GALLERY", "rect": Rect2(384, 288, 384, 480)},
	{"id": "alcove", "name": "THE LAMP ALCOVE", "rect": Rect2(384, 32, 256, 224)},
	{"id": "study", "name": "VEYR'S STUDY", "rect": Rect2(800, 160, 288, 384)},
	{"id": "hall", "name": "THE SERVANTS' HALL", "rect": Rect2(32, 832, 576, 256)},
	{"id": "garden", "name": "THE KITCHEN GARDEN", "rect": Rect2(672, 832, 480, 352)}
]
const CORRIDORS := [Rect2(352, 608, 32, 64), Rect2(480, 256, 64, 32), Rect2(768, 384, 32, 64), Rect2(1088, 384, 64, 64), Rect2(224, 768, 64, 64), Rect2(608, 928, 64, 64)]

static func anchors() -> Array[Dictionary]:
	return [
		{"id": "cart", "at": Vector2(1104, 880), "label": "Handcart"},
		{"id": "hedge", "at": Vector2(1056, 960), "label": "Hedge"},
		{"id": "woodpile", "at": Vector2(688, 960), "label": "Woodpile"},
		{"id": "larder", "at": Vector2(600, 960), "label": "Larder"},
		{"id": "table", "at": Vector2(264, 936), "label": "Table"},
		{"id": "stairs", "at": Vector2(256, 848), "label": "Back Stairs"},
		{"id": "ivy", "at": Vector2(256, 760), "label": "Ivy"},
		{"id": "well", "at": Vector2(96, 736), "label": "Well"},
		{"id": "crate", "at": Vector2(176, 728), "label": "Crates"},
		{"id": "foyer", "at": Vector2(448, 624), "label": "Pillar"},
		{"id": "statue", "at": Vector2(512, 576), "label": "Statue"},
		{"id": "bench", "at": Vector2(608, 576), "label": "Bench"},
		{"id": "cupboard", "at": Vector2(592, 128), "label": "Cupboard"},
		{"id": "curtain", "at": Vector2(960, 352), "label": "Curtain", "active": false}
	]

static func guards() -> Array[Dictionary]:
	return [
		{"id": "groundskeeper", "name": "Groundskeeper", "at": Vector2(1056, 1040), "style": "blade", "points": [Vector2(1056, 1040), Vector2(704, 1040)], "waits": [1.6, 1.6], "faces": [Vector2.DOWN, Vector2.UP]},
		{"id": "garden_sentry", "name": "Garden Sentry", "at": Vector2(896, 880), "style": "shot", "visual": "watchman", "points": [Vector2(896, 880)], "waits": [2.0], "faces": [Vector2.DOWN]},
		{"id": "steward", "name": "Steward", "at": Vector2(560, 1008), "style": "thrust", "points": [Vector2(560, 1008), Vector2(288, 1008)], "waits": [1.5, 1.5], "faces": [Vector2.UP, Vector2.LEFT]},
		{"id": "hall_sentry", "name": "Hall Sentry", "at": Vector2(96, 880), "style": "blade", "points": [Vector2(96, 880), Vector2(96, 1040)], "waits": [2.0, 2.0], "faces": [Vector2.RIGHT, Vector2.RIGHT]},
		{"id": "gatekeeper", "name": "Gatekeeper", "at": Vector2(240, 656), "style": "blade", "points": [Vector2(240, 656), Vector2(432, 656), Vector2(512, 656), Vector2(432, 656)], "waits": [1.4, 0.2, 1.5, 0.2], "faces": [Vector2.RIGHT, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]},
		{"id": "watchman", "name": "Watchman", "at": Vector2(512, 512), "style": "shot", "visual": "watchman", "points": [Vector2(512, 512), Vector2(512, 208), Vector2(560, 208), Vector2(512, 208)], "waits": [1.0, 0.4, 2.5, 0.3], "faces": [Vector2.DOWN, Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN]},
		{"id": "bodyguard", "name": "Bodyguard", "at": Vector2(688, 528), "style": "thrust", "points": [Vector2(688, 528), Vector2(688, 416), Vector2(912, 416), Vector2(688, 416)], "waits": [1.0, 0.4, 2.2, 0.4], "faces": [Vector2.DOWN, Vector2.RIGHT, Vector2.DOWN, Vector2.DOWN]},
		{"id": "courtyard_sentry", "name": "Courtyard Sentry", "at": Vector2(272, 496), "style": "blade", "points": [Vector2(272, 496), Vector2(304, 496)], "waits": [1.5, 1.5], "faces": [Vector2.RIGHT, Vector2.RIGHT]},
		{"id": "gallery_sentry", "name": "Gallery Sentry", "at": Vector2(704, 672), "style": "thrust", "points": [Vector2(704, 672)], "waits": [2.0], "faces": [Vector2.LEFT]},
		{"id": "study_sentry", "name": "Study Sentry", "at": Vector2(1056, 208), "style": "shot", "visual": "watchman", "points": [Vector2(1056, 208)], "waits": [2.0], "faces": [Vector2.LEFT]},
		{"id": "veyr", "name": "Lord Veyr", "at": Vector2(1008, 304), "style": "blade", "visual": "boss", "boss": true, "points": [Vector2(1008, 304), Vector2(1008, 368)], "waits": [2.0, 2.0], "faces": [Vector2.LEFT, Vector2.UP]}
	]
