extends RefCounted
## Dati del gioco: professioni, edifici, paesaggi, libertà, carte Bonus e Prestigio,
## carte dell'Automa (Wolfgang), personaggi dell'espansione «La Musa e la Principessa».
## I nomi italiani sono provvisori: verranno allineati alla scatola italiana.

const ROUNDS := 7
## valore minimo dell'opera per round (1..7)
const MIN_WORK := [0, 7, 10, 12, 14, 15, 16, 17]
const START_MONEY := 3500
const START_MONEY_2P := 2500

## colori dei giocatori (ordine delle plance)
const COLORS := [
	{"id": "rosso", "name": "Rosso", "hex": "#b3283a", "ink": "#ffffff"},
	{"id": "blu", "name": "Blu", "hex": "#2a5aa8", "ink": "#ffffff"},
	{"id": "giallo", "name": "Giallo", "hex": "#d9a520", "ink": "#2a1a05"},
	{"id": "verde", "name": "Verde", "hex": "#3d8a3a", "ink": "#ffffff"},
	{"id": "nero", "name": "Nero", "hex": "#55585e", "ink": "#ffffff"},
]
const PRINCES := {
	"rosso": ["Lucrezia", "Cosimo"], "blu": ["Bianca", "Lorenzo"], "giallo": ["Caterina", "Giuliano"],
	"verde": ["Isabella", "Piero"], "nero": ["Beatrice", "Federico"],
}

const LANDS := ["bosco", "lago", "parco"]
const LAND_NAME := {"bosco": "Bosco", "lago": "Lago", "parco": "Parco"}
const LAND_COUNT := 6
const FREEDOMS := ["viaggio", "religione", "opinione"]
const FREEDOM_NAME := {"viaggio": "Libertà di viaggio", "religione": "Libertà di religione", "opinione": "Libertà di opinione"}
const FREEDOM_SHORT := {"viaggio": "Viaggio", "religione": "Religione", "opinione": "Opinione"}

## sagome (righe dall'alto, # = casella occupata)
const SHAPES := {
	"universita": ["##.", "###", ".##"],
	"laboratorio": ["##.", "###", "#.#"],
	"bottega": ["###", "###", "..#"],
	"biblioteca": [".#.", "###", "#.."],
	"opera": ["###", "#..", "#.."],
	"studio": ["###", "#.#"],
	"ospedale": ["..#", "###", "#.."],
	"teatro": [".###", "##.."],
	"torre": ["#.", "##"],
	"cappella": ["#", "#", "#"],
	"bosco": [".##", "###"],
	"lago": ["##", "##"],
	"parco": ["#", "#", "#"],
}

const BUILDINGS := ["universita", "laboratorio", "bottega", "biblioteca", "opera", "studio", "ospedale", "teatro", "torre", "cappella"]
const BUILDING_NAME := {
	"universita": "Università", "laboratorio": "Laboratorio", "bottega": "Bottega", "biblioteca": "Biblioteca",
	"opera": "Teatro dell'Opera", "studio": "Studio", "ospedale": "Ospedale", "teatro": "Teatro", "torre": "Torre", "cappella": "Cappella",
}
## grande / medio / piccolo
const BUILDING_SIZE := {
	"universita": "G", "laboratorio": "G", "bottega": "G", "biblioteca": "M", "opera": "M",
	"studio": "M", "ospedale": "M", "teatro": "M", "torre": "P", "cappella": "P",
}
const SIZE_NAME := {"G": "grande", "M": "medio", "P": "piccolo"}
const BUILDING_COPIES := 3

## Professioni: numero stampato -> paesaggio, libertà, edificio
const PROFS := {
	1: {"name": "Matematica", "en": "Mathematician", "land": "lago", "free": "religione", "bld": "universita"},
	2: {"name": "Teologo", "en": "Theologian", "land": "parco", "free": "viaggio", "bld": "universita"},
	3: {"name": "Filosofa", "en": "Philosopher", "land": "bosco", "free": "opinione", "bld": "universita"},
	4: {"name": "Botanica", "en": "Botanist", "land": "parco", "free": "religione", "bld": "laboratorio"},
	5: {"name": "Alchimista", "en": "Alchemist", "land": "lago", "free": "opinione", "bld": "laboratorio"},
	6: {"name": "Fisico", "en": "Physicist", "land": "bosco", "free": "viaggio", "bld": "laboratorio"},
	7: {"name": "Orologiaio", "en": "Watchmaker", "land": "lago", "free": "viaggio", "bld": "bottega"},
	8: {"name": "Orafa", "en": "Goldsmith", "land": "parco", "free": "opinione", "bld": "bottega"},
	9: {"name": "Fonditrice di campane", "en": "Bell caster", "land": "bosco", "free": "religione", "bld": "bottega"},
	10: {"name": "Cartografa", "en": "Cartographer", "land": "lago", "free": "religione", "bld": "biblioteca"},
	11: {"name": "Giurista", "en": "Legal scholar", "land": "bosco", "free": "opinione", "bld": "biblioteca"},
	12: {"name": "Coreografo", "en": "Choreographer", "land": "bosco", "free": "viaggio", "bld": "opera"},
	13: {"name": "Compositore", "en": "Composer", "land": "lago", "free": "opinione", "bld": "opera"},
	14: {"name": "Scultore", "en": "Sculptor", "land": "bosco", "free": "religione", "bld": "studio"},
	15: {"name": "Pittore", "en": "Painter", "land": "lago", "free": "viaggio", "bld": "studio"},
	16: {"name": "Farmacista", "en": "Pharmacist", "land": "parco", "free": "opinione", "bld": "ospedale"},
	17: {"name": "Medica", "en": "Doctor", "land": "bosco", "free": "viaggio", "bld": "ospedale"},
	18: {"name": "Drammaturgo", "en": "Dramatist", "land": "parco", "free": "religione", "bld": "teatro"},
	19: {"name": "Poetessa", "en": "Poet", "land": "lago", "free": "viaggio", "bld": "teatro"},
	20: {"name": "Astronomo", "en": "Astronomer", "land": "bosco", "free": "religione", "bld": "torre"},
	21: {"name": "Organara", "en": "Organ builder", "land": "bosco", "free": "opinione", "bld": "cappella"},
}

## Carte Bonus (B1..B20): aumentano il valore dell'opera
const BONUS := {
	1: "Ogni edificio: +1",
	2: "Ogni edificio grande: +2",
	3: "Ogni edificio medio e ogni bosco: +1",
	4: "Ogni edificio piccolo e ogni paesaggio: +1",
	5: "Ogni misura di edificio (grande, medio, piccolo): +2",
	6: "Ogni paesaggio: +1",
	7: "Ogni bosco: +2",
	8: "Ogni lago: +2",
	9: "Ogni parco: +2",
	10: "Ogni libertà: +2",
	11: "Ogni giullare: +2",
	12: "Ogni giullare e ogni libertà: +1",
	13: "Ogni costruttore: +2",
	14: "Ogni costruttore e ogni lago: +1",
	15: "Ogni carta Prestigio: +2",
	16: "Ogni carta Prestigio e ogni libertà: +1",
	17: "Ogni tipo di paesaggio: +2",
	18: "Ogni categoria (parco, lago, bosco, giullare, costruttore, Prestigio, libertà): +1",
	19: "Ogni carta Professione e Reclutamento in mano (esclusa quella giocata): +1",
	20: "Ogni tua carta Professione e Reclutamento sul tavolo (compresa quella giocata): +1",
}

## Carte Prestigio (P1..P14): punti a fine partita. full / tied (-1 = nessun pareggio)
const PRESTIGE := {
	1: {"text": "Più edifici", "pts": 6, "tie": 3},
	2: {"text": "Almeno due edifici grandi", "pts": 5, "tie": -1},
	3: {"text": "Meno caselle vuote", "pts": 8, "tie": 4},
	4: {"text": "Tutti e tre i tipi di paesaggio", "pts": 8, "tie": -1},
	5: {"text": "Più paesaggi", "pts": 7, "tie": 4},
	6: {"text": "Più boschi", "pts": 7, "tie": 4},
	7: {"text": "Più laghi", "pts": 6, "tie": 3},
	8: {"text": "Tutte e tre le libertà", "pts": 8, "tie": -1},
	9: {"text": "4 edifici + 2 libertà + 4 opere", "pts": 6, "tie": -1},
	10: {"text": "Più giullari", "pts": 6, "tie": 3},
	11: {"text": "Più costruttori", "pts": 6, "tie": 3},
	12: {"text": "Più parchi", "pts": 5, "tie": 3},
	13: {"text": "1 costruttore + 1 giullare + 2 paesaggi", "pts": 7, "tie": -1},
	14: {"text": "Più opere", "pts": 7, "tie": 4},
}

## Oggetti all'asta
const OBJECTS := ["bosco", "lago", "parco", "prestigio", "reclutamento", "giullare", "costruttore"]
const OBJECT_NAME := {
	"bosco": "Bosco", "lago": "Lago", "parco": "Parco", "paesaggio": "Paesaggio", "prestigio": "Carta Prestigio",
	"reclutamento": "Carta Reclutamento", "giullare": "Giullare", "costruttore": "Costruttore",
}
const JESTERS := 7
const BUILDERS := 6
const RECRUITS := 5

## Carte Automa: ordine degli oggetti (il primo a sinistra è quello che Wolfgang preferisce),
## modificatori del dado [4 giocatori, 5 giocatori] (0 = nessun modificatore), azioni 1 e 2.
## B costruttore, J giullare, R reclutamento, P prestigio, L paesaggio
const AUTOMA := {
	1: {"o": ["B", "J", "R", "P", "L"], "m": {"B": [2, 2], "J": [6, 6], "R": [0, 3], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["freedom"]},
	2: {"o": ["B", "J", "R", "P", "L"], "m": {"B": [2, 2], "J": [6, 6], "R": [0, 3], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "freedom"], "a2": ["build"]},
	3: {"o": ["J", "R", "B", "P", "L"], "m": {"J": [6, 6], "R": [0, 2], "B": [3, 3], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["freedom"]},
	4: {"o": ["J", "R", "B", "P", "L"], "m": {"J": [6, 6], "R": [0, 2], "B": [3, 3], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "freedom"], "a2": ["build"]},
	5: {"o": ["R", "B", "J", "P", "L"], "m": {"R": [0, 4], "B": [2, 2], "J": [6, 6], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["freedom"]},
	6: {"o": ["R", "B", "J", "P", "L"], "m": {"R": [0, 4], "B": [2, 2], "J": [6, 6], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "freedom"], "a2": ["work"]},
	7: {"o": ["B", "J", "R", "P", "L"], "m": {"B": [2, 2], "J": [5, 5], "R": [1, 4], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "freedom"], "a2": ["work"]},
	8: {"o": ["B", "J", "R", "P", "L"], "m": {"B": [3, 3], "J": [5, 5], "R": [2, 4], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["work"]},
	9: {"o": ["J", "R", "B", "P", "L"], "m": {"J": [6, 6], "R": [2, 3], "B": [1, 1], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["work"]},
	10: {"o": ["J", "R", "B", "P", "L"], "m": {"J": [6, 6], "R": [3, 3], "B": [1, 1], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["work"]},
	11: {"o": ["R", "B", "J", "P", "L"], "m": {"R": [1, 4], "B": [2, 2], "J": [5, 5], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "bonus"], "a2": ["work"]},
	12: {"o": ["R", "B", "J", "P", "L"], "m": {"R": [1, 4], "B": [2, 2], "J": [5, 5], "P": [0, 0], "L": [0, 0]}, "a1": ["prof", "build"], "a2": ["work"]},
	13: {"o": ["P", "L", "R", "J", "B"], "m": {"P": [3, 3], "L": [0, 0], "R": [2, 4], "J": [1, 1], "B": [0, 0]}, "a1": ["build", "work"], "a2": ["work", "build"]},
	14: {"o": ["P", "L", "R", "J", "B"], "m": {"P": [3, 3], "L": [0, 0], "R": [2, 4], "J": [1, 1], "B": [0, 0]}, "a1": ["bonus", "work"], "a2": ["work", "build"]},
	15: {"o": ["P", "L", "R", "J", "B"], "m": {"P": [3, 3], "L": [0, 0], "R": [2, 4], "J": [1, 1], "B": [0, 0]}, "a1": ["build", "work"], "a2": ["work", "build"]},
	16: {"o": ["L", "R", "P", "J", "B"], "m": {"L": [0, 0], "R": [4, 4], "P": [3, 3], "J": [2, 2], "B": [0, 0]}, "a1": ["bonus", "work"], "a2": ["work", "build"]},
	17: {"o": ["L", "R", "P", "J", "B"], "m": {"L": [0, 0], "R": [4, 4], "P": [3, 3], "J": [2, 2], "B": [0, 0]}, "a1": ["build", "work"], "a2": ["work", "build"]},
	18: {"o": ["L", "R", "P", "J", "B"], "m": {"L": [0, 0], "R": [4, 4], "P": [3, 3], "J": [2, 2], "B": [0, 0]}, "a1": ["bonus", "work"], "a2": ["work", "build"]},
	19: {"o": ["R", "P", "L", "J", "B"], "m": {"R": [3, 4], "P": [2, 2], "L": [0, 0], "J": [1, 1], "B": [0, 0]}, "a1": ["build", "work"], "a2": ["work", "build"]},
	20: {"o": ["R", "L", "P", "J", "B"], "m": {"R": [3, 5], "L": [0, 0], "P": [2, 2], "J": [1, 1], "B": [0, 0]}, "a1": ["bonus", "work"], "a2": ["work", "build"]},
	21: {"o": ["R", "P", "L", "J", "B"], "m": {"R": [3, 3], "P": [2, 2], "L": [0, 0], "J": [1, 1], "B": [0, 0]}, "a1": ["build", "work"], "a2": ["work", "build"]},
}
const AUTOMA_OBJ := {"B": "costruttore", "J": "giullare", "R": "reclutamento", "P": "prestigio", "L": "paesaggio"}
const WOLFGANG_MONEY := [0, 1500, 3500]

## Personaggi (espansione «La Musa e la Principessa»): offerte possibili
const CHARACTERS := ["banchiere", "cardinale", "mercante", "musa", "professore", "principessa"]
const CHAR_NAME := {"banchiere": "Banchiere", "cardinale": "Cardinale", "mercante": "Mercante", "musa": "Musa", "professore": "Professore", "principessa": "Principessa"}
const CHAR_TEXT := {
	"banchiere": "Prendi subito i fiorini sul Banchiere (meno la tua offerta). Si parte da 600 e si aggiungono 100 a ogni round in cui nessuno lo prende. A fine partita: 200 fiorini → 1 punto.",
	"cardinale": "Nella fase azioni puoi fare una terza azione.",
	"mercante": "Quando vinci un'asta, prendi l'oggetto gratis; oppure guadagni 1 punto più 1 per ogni avversario con più punti di te.",
	"musa": "Ogni opera che completi in questo round vale in più quanto il numero del round.",
	"professore": "Prendi gratis una carta Bonus oppure una carta Prestigio.",
	"principessa": "Completi un'opera senza carta Professione: ogni paesaggio +3, ogni edificio +2, ogni costruttore +2, ogni carta Professione/Reclutamento +1. Niente Bonus.",
}
const CHAR_BIDS := {"banchiere": [0, 5]}
const CHAR_BIDS_DEFAULT := [3, 15]
const BANKER_START := 600

## Plance del principato: lato A (7x7, palazzo in basso a sinistra) e lato B (10x5, palazzo al centro in basso)
const BOARD_A := {"w": 7, "h": 7, "palazzo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6)],
	"img": "res://assets/board/principato_a.jpg", "img_w": 2048, "img_h": 1627, "x0": 52.0, "y0": 96.0, "cell": 203.9}
const BOARD_B := {"w": 10, "h": 5, "palazzo": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)],
	"img": "res://assets/board/principato_b.jpg", "img_w": 2048, "img_h": 1635, "x0": 4.0, "y0": 4.0, "cell": 204.2}

## Posizioni sul tabellone (frazioni dell'immagine 8500x4204), misurate confrontando le tessere
## con le sagome stampate (tools/misura_tabellone.py)
const BOARD_POS := {
	"bosco": Vector2(0.3312, 0.5086), "lago": Vector2(0.2256, 0.5086), "parco": Vector2(0.1209, 0.542),
	"prestigio": Vector2(0.1239, 0.7969), "reclutamento": Vector2(0.2473, 0.7969),
	"costruttore": Vector2(0.3449, 0.679), "giullare": Vector2(0.3455, 0.8494),
	"universita": Vector2(0.7613, 0.229), "laboratorio": Vector2(0.6377, 0.229), "bottega": Vector2(0.5137, 0.2315),
	"biblioteca": Vector2(0.514, 0.4648), "opera": Vector2(0.7616, 0.4642), "ospedale": Vector2(0.6386, 0.4654),
	"studio": Vector2(0.5143, 0.6648), "teatro": Vector2(0.6563, 0.6636), "cappella": Vector2(0.4811, 0.8654), "torre": Vector2(0.551, 0.8673),
	"viaggio": Vector2(0.6636, 0.9), "opinione": Vector2(0.7772, 0.9012), "religione": Vector2(0.8913, 0.9),
	"bonus": Vector2(0.8889, 0.271), "professioni": Vector2(0.8901, 0.6105),
}
## Sagome stampate ruotate (quarti di giro orari)
const BOARD_ROT := {"parco": 3}

## Casella della traccia della fama (0..49) sul tabellone, in frazioni
static func fame_pos(i: int) -> Vector2:
	i = posmod(i, 50)
	if i <= 11:
		return Vector2(0.0088, (773.0 - i * 58.6) / 791.0)
	if i <= 38:
		return Vector2((40.0 + (i - 12) * 59.2) / 1600.0, 0.022)
	return Vector2(0.99, (128.0 + (i - 39) * 58.6) / 791.0)

static func round_pos(r: int) -> Vector2:
	return Vector2((160.0 + (r - 1) * 64.0) / 1600.0, 151.0 / 791.0)


## Celle di una sagoma ruotata (r = 0..3, quarti di giro orari) e specchiata (f).
static func shape_cells(id: String, r: int, f: bool) -> Array:
	var rows: Array = SHAPES[id]
	var cells := []
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				cells.append(Vector2i(x, y))
	if f:
		var mx := 0
		for c in cells:
			mx = maxi(mx, c.x)
		for i in cells.size():
			cells[i] = Vector2i(mx - cells[i].x, cells[i].y)
	for _k in posmod(r, 4):
		for i in cells.size():
			var c: Vector2i = cells[i]
			cells[i] = Vector2i(-c.y, c.x)
	var minx := 999
	var miny := 999
	for c in cells:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
	for i in cells.size():
		cells[i] = cells[i] - Vector2i(minx, miny)
	cells.sort()
	return cells


## Orientamenti distinti di una sagoma: [[r, f, celle], ...]
static func orientations(id: String) -> Array:
	var seen := {}
	var out := []
	for f in [false, true]:
		for r in 4:
			var cells := shape_cells(id, r, f)
			var key := str(cells)
			if seen.has(key):
				continue
			seen[key] = true
			out.append([r, f, cells])
	return out
