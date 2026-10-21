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
const LAND_NAME := {"bosco": "Foresta", "lago": "Lago", "parco": "Parco"}
const LAND_PLURAL := {"bosco": "foreste", "lago": "laghi", "parco": "parchi"}
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

## Mestieri: numero stampato -> paesaggio, libertà, edificio
const PROFS := {
	1: {"name": "Matematico", "en": "Mathematician", "land": "lago", "free": "religione", "bld": "universita"},
	2: {"name": "Teologo", "en": "Theologian", "land": "parco", "free": "viaggio", "bld": "universita"},
	3: {"name": "Filosofo", "en": "Philosopher", "land": "bosco", "free": "opinione", "bld": "universita"},
	4: {"name": "Botanico", "en": "Botanist", "land": "parco", "free": "religione", "bld": "laboratorio"},
	5: {"name": "Alchimista", "en": "Alchemist", "land": "lago", "free": "opinione", "bld": "laboratorio"},
	6: {"name": "Fisico", "en": "Physicist", "land": "bosco", "free": "viaggio", "bld": "laboratorio"},
	7: {"name": "Orologiaio", "en": "Watchmaker", "land": "lago", "free": "viaggio", "bld": "bottega"},
	8: {"name": "Orafo", "en": "Goldsmith", "land": "parco", "free": "opinione", "bld": "bottega"},
	9: {"name": "Campanaro", "en": "Bell caster", "land": "bosco", "free": "religione", "bld": "bottega"},
	10: {"name": "Cartografo", "en": "Cartographer", "land": "lago", "free": "religione", "bld": "biblioteca"},
	11: {"name": "Giurista", "en": "Legal scholar", "land": "bosco", "free": "opinione", "bld": "biblioteca"},
	12: {"name": "Coreografo", "en": "Choreographer", "land": "bosco", "free": "viaggio", "bld": "opera"},
	13: {"name": "Compositore", "en": "Composer", "land": "lago", "free": "opinione", "bld": "opera"},
	14: {"name": "Scultore", "en": "Sculptor", "land": "bosco", "free": "religione", "bld": "studio"},
	15: {"name": "Pittore", "en": "Painter", "land": "lago", "free": "viaggio", "bld": "studio"},
	16: {"name": "Farmacista", "en": "Pharmacist", "land": "parco", "free": "opinione", "bld": "ospedale"},
	17: {"name": "Medico", "en": "Doctor", "land": "bosco", "free": "viaggio", "bld": "ospedale"},
	18: {"name": "Drammaturgo", "en": "Dramatist", "land": "parco", "free": "religione", "bld": "teatro"},
	19: {"name": "Poeta", "en": "Poet", "land": "lago", "free": "viaggio", "bld": "teatro"},
	20: {"name": "Astronomo", "en": "Astronomer", "land": "bosco", "free": "religione", "bld": "torre"},
	21: {"name": "Organista", "en": "Organ builder", "land": "bosco", "free": "opinione", "bld": "cappella"},
}

## Carte Bonus (B1..B20): aumentano il valore dell'opera
const BONUS := {
	1: "Ogni edificio: +1",
	2: "Ogni edificio grande: +2",
	3: "Ogni edificio medio e ogni foresta: +1",
	4: "Ogni edificio piccolo e ogni paesaggio: +1",
	5: "Ogni misura di edificio (grande, medio, piccolo): +2",
	6: "Ogni paesaggio: +1",
	7: "Ogni foresta: +2",
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
	18: "Ogni categoria (foresta, lago, parco, giullare, costruttore, Prestigio, libertà): +1",
	19: "Ogni carta Mestiere e Attrazione in mano (esclusa quella giocata): +1",
	20: "Ogni tua carta Mestiere e Attrazione, in mano o sul tavolo: +1",
}

## Carte Prestigio (P1..P14): punti a fine partita. full / tied (-1 = nessun pareggio)
const PRESTIGE := {
	1: {"text": "Più edifici", "pts": 6, "tie": 3},
	2: {"text": "Almeno due edifici grandi", "pts": 5, "tie": -1},
	3: {"text": "Meno caselle vuote", "pts": 8, "tie": 4},
	4: {"text": "Tutti e tre i tipi di paesaggio", "pts": 8, "tie": -1},
	5: {"text": "Più paesaggi", "pts": 7, "tie": 4},
	6: {"text": "Più foreste", "pts": 7, "tie": 4},
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
	"bosco": "Foresta", "lago": "Lago", "parco": "Parco", "paesaggio": "Paesaggio", "prestigio": "Carta Prestigio",
	"reclutamento": "Carta Attrazione", "giullare": "Giullare", "costruttore": "Costruttore",
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
	"principessa": "Completi un'opera senza carta Mestiere: ogni paesaggio +3, ogni edificio +2, ogni costruttore +2, ogni carta Mestiere/Attrazione +1. Niente Bonus.",
}
const CHAR_BIDS := {"banchiere": [0, 5]}
const CHAR_BIDS_DEFAULT := [3, 15]
const BANKER_START := 600

## Plance del principato: lato A (7x7, palazzo in basso a sinistra) e lato B (10x5, palazzo al centro in basso)
const BOARD_A := {"w": 7, "h": 7, "palazzo": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6)],
	"img": "res://assets/board/principato_a.jpg", "img_w": 2048, "img_h": 1627, "x0": 52.0, "y0": 96.0, "cell": 203.9}
## Plance italiane (principato e plancia del giocatore insieme), una per colore
const BOARD_IT := {
	"giallo": {"w": 7, "h": 7, "palazzo": BOARD_A["palazzo"], "img": "res://assets/board/plancia_it_giallo.jpg", "img_w": 2048, "img_h": 1470, "x0": 490.9, "y0": 90.7, "cell": 145.13, "cell_h": 140.34},
	"verde": {"w": 7, "h": 7, "palazzo": BOARD_A["palazzo"], "img": "res://assets/board/plancia_it_verde.jpg", "img_w": 2048, "img_h": 1472, "x0": 490.9, "y0": 92.6, "cell": 145.40, "cell_h": 144.42},
	"blu": {"w": 7, "h": 7, "palazzo": BOARD_A["palazzo"], "img": "res://assets/board/plancia_it_blu.jpg", "img_w": 2048, "img_h": 1474, "x0": 485.3, "y0": 91.3, "cell": 145.31, "cell_h": 143.71},
	"nero": {"w": 7, "h": 7, "palazzo": BOARD_A["palazzo"], "img": "res://assets/board/plancia_it_nero.jpg", "img_w": 2048, "img_h": 1469, "x0": 487.8, "y0": 91.3, "cell": 145.31, "cell_h": 144.51},
	"rosso": {"w": 7, "h": 7, "palazzo": BOARD_A["palazzo"], "img": "res://assets/board/plancia_it_rosso.jpg", "img_w": 2048, "img_h": 1473, "x0": 488.4, "y0": 88.9, "cell": 145.40, "cell_h": 144.69},
}

## Retro delle plance italiane (costruzioni in comune): griglia 10x5 lungo il bordo
const BOARD_B_IT := {
	"giallo": {"w": 10, "h": 5, "palazzo": [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "img": "res://assets/board/principato_b_it_giallo.jpg", "img_w": 2048, "img_h": 1024, "x0": 0.0, "y0": 0.0, "cell": 204.8},
	"verde": {"w": 10, "h": 5, "palazzo": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)], "img": "res://assets/board/principato_b_it_verde.jpg", "img_w": 2048, "img_h": 1024, "x0": 0.0, "y0": 0.0, "cell": 204.8},
	"blu": {"w": 10, "h": 5, "palazzo": [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "img": "res://assets/board/principato_b_it_blu.jpg", "img_w": 2048, "img_h": 1024, "x0": 0.0, "y0": 0.0, "cell": 204.8},
	"nero": {"w": 10, "h": 5, "palazzo": [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "img": "res://assets/board/principato_b_it_nero.jpg", "img_w": 2048, "img_h": 1024, "x0": 0.0, "y0": 0.0, "cell": 204.8},
	"rosso": {"w": 10, "h": 5, "palazzo": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)], "img": "res://assets/board/principato_b_it_rosso.jpg", "img_w": 2048, "img_h": 1024, "x0": 0.0, "y0": 0.0, "cell": 204.8},
}
## Parte del retro con libertà e costruttori (coordinate in pixel della scansione)
const PLANCIA_B_IT := {
	"giallo": {"img": "res://assets/board/plancia_b_it_giallo.jpg", "w": 3271, "h": 1226, "free": {"viaggio": Vector2(494, 399), "religione": Vector2(496, 658), "opinione": Vector2(488, 912)}, "builders": [Vector2(1357, 584), Vector2(1899, 584), Vector2(2441, 584)]},
	"verde": {"img": "res://assets/board/plancia_b_it_verde.jpg", "w": 3275, "h": 1214, "free": {"viaggio": Vector2(2806, 395), "religione": Vector2(2804, 653), "opinione": Vector2(2804, 908)}, "builders": [Vector2(630, 490), Vector2(1172, 490), Vector2(1714, 490)]},
	"blu": {"img": "res://assets/board/plancia_b_it_blu.jpg", "w": 2382, "h": 2105, "free": {"viaggio": Vector2(1698, 1116), "religione": Vector2(1700, 1373), "opinione": Vector2(1694, 1628)}, "builders": [Vector2(544, 416), Vector2(1086, 416), Vector2(1628, 416)]},
	"nero": {"img": "res://assets/board/plancia_b_it_nero.jpg", "w": 3272, "h": 1215, "free": {"viaggio": Vector2(480, 390), "religione": Vector2(478, 647), "opinione": Vector2(480, 900)}, "builders": [Vector2(1350, 574), Vector2(1892, 574), Vector2(2434, 574)]},
	"rosso": {"img": "res://assets/board/plancia_b_it_rosso.jpg", "w": 3277, "h": 1214, "free": {"viaggio": Vector2(2814, 393), "religione": Vector2(2812, 650), "opinione": Vector2(2814, 907)}, "builders": [Vector2(640, 484), Vector2(1182, 484), Vector2(1724, 484)]},
}

## La plancia del principato di un giocatore
static func board_info(p: Dictionary) -> Dictionary:
	if p["board"] == "B":
		return BOARD_B_IT.get(p["color"], BOARD_B)
	return BOARD_IT.get(p["color"], BOARD_A)

const BOARD_B := {"w": 10, "h": 5, "palazzo": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)],
	"img": "res://assets/board/principato_b.jpg", "img_w": 2048, "img_h": 1635, "x0": 4.0, "y0": 4.0, "cell": 204.2}

## Posizioni sul tabellone italiano (frazioni dell'immagine), misurate sulla scansione
const BOARD_POS := {
	"bosco": Vector2(0.1207, 0.3446), "lago": Vector2(0.2223, 0.3045), "parco": Vector2(0.2038, 0.4737),
	"giullare": Vector2(0.1207, 0.7018), "costruttore": Vector2(0.2254, 0.802),
	"prestigio": Vector2(0.3524, 0.3258), "reclutamento": Vector2(0.3524, 0.7206),
}
## Ritratti dei personaggi sul tabellone (asta dei personaggi)
const CHAR_POS := {
	"musa": Vector2(0.4731, 0.2256), "principessa": Vector2(0.4731, 0.4637), "professore": Vector2(0.4731, 0.7268),
	"cardinale": Vector2(0.6922, 0.3195), "mercante": Vector2(0.6922, 0.589), "banchiere": Vector2(0.6922, 0.8333),
}
## Sagome stampate ruotate (quarti di giro orari)
const BOARD_ROT := {"bosco": 1, "parco": 1}
const BOARD_ASPECT := 3192.0 / 6299.0
const FAME := [Vector2(0.0445, 0.0777), Vector2(0.1143, 0.0526), Vector2(0.1689, 0.0526), Vector2(0.2235, 0.0526), Vector2(0.2781, 0.0526), Vector2(0.3328, 0.0526), Vector2(0.3874, 0.0526), Vector2(0.4420, 0.0526), Vector2(0.4966, 0.0526), Vector2(0.5512, 0.0526), Vector2(0.6034, 0.0542), Vector2(0.6557, 0.0558), Vector2(0.7079, 0.0573), Vector2(0.7601, 0.0589), Vector2(0.8124, 0.0605), Vector2(0.8646, 0.0620), Vector2(0.9168, 0.0636), Vector2(0.9690, 0.0652), Vector2(0.9906, 0.2130), Vector2(0.9906, 0.3216), Vector2(0.9906, 0.4302), Vector2(0.9906, 0.5388), Vector2(0.9906, 0.6475), Vector2(0.9906, 0.7561), Vector2(0.9906, 0.8647), Vector2(0.9856, 0.8922), Vector2(0.9322, 0.9499), Vector2(0.8778, 0.9499), Vector2(0.8234, 0.9499), Vector2(0.7689, 0.9499), Vector2(0.7145, 0.9499), Vector2(0.6601, 0.9499), Vector2(0.6056, 0.9499), Vector2(0.5512, 0.9499), Vector2(0.4966, 0.9499), Vector2(0.4420, 0.9499), Vector2(0.3874, 0.9499), Vector2(0.3328, 0.9499), Vector2(0.2781, 0.9499), Vector2(0.2235, 0.9499), Vector2(0.1689, 0.9499), Vector2(0.1143, 0.9499), Vector2(0.0667, 0.9248), Vector2(0.0286, 0.8396), Vector2(0.0283, 0.7356), Vector2(0.0279, 0.6316), Vector2(0.0276, 0.5276), Vector2(0.0273, 0.4236), Vector2(0.0270, 0.3195), Vector2(0.0267, 0.2155)]
const ROUND_X := [0.7671, 0.7989, 0.8306, 0.863, 0.896, 0.9284, 0.9602]

## Casella della traccia della fama (0..49) sul tabellone, in frazioni
static func fame_pos(i: int) -> Vector2:
	return FAME[posmod(i, 50)]


static func round_pos(r: int) -> Vector2:
	return Vector2(ROUND_X[clampi(r, 1, 7) - 1], 0.268)


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
