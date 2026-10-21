extends Control
## Le regole in breve, su pergamena. Dal menu sostituisce la schermata; in partita si apre sopra il tavolo.

var main
var overlay := false

const RULES := [
	["Lo scopo", "Sei a capo di una grande casata del Rinascimento. In 7 round costruisci edifici, coltivi paesaggi, introduci libertà e inviti artisti e sapienti nel tuo palazzo perché completino le loro opere. Le opere portano fiorini e fama: vince chi, dopo il 7° round e le carte Prestigio, ha più punti di fama (in caso di pareggio, più fiorini)."],
	["Preparazione", "Ognuno parte con 3500 fiorini (2500 in due) e riceve 4 carte Mestiere: ne tiene 3. Le libertà disponibili sono una per tipo in meno del numero di giocatori (in due: 5 libertà, una per tipo più due a caso)."],
	["Il round", "Ogni round ha un'asta (ognuno può prendere al massimo un oggetto) e poi la fase azioni (2 azioni a testa, nell'ordine del turno). Alla fine del round chi ha completato l'opera di valore più alto guadagna 3 punti (in pareggio, tutti). Poi il primo giocatore passa a sinistra."],
	["L'asta", "Il primo giocatore sceglie una pila (bosco, lago, parco, carta Prestigio, carta Attrazione, giullare, costruttore) e offre 200 fiorini (300 in due). A turno si rilancia di 100 o si passa. Chi vince paga e mette la pedina sulla pila: quella pila e quel giocatore sono fuori per il round. Se chi ha aperto l'asta perde, ne apre un'altra. Chi apre può invece ritirarsi dalle aste del round. L'ultimo rimasto può prendere un oggetto per 200 fiorini. Si può offrire più di quanto si ha, cedendo punti di fama (100 fiorini l'uno). In due i tre paesaggi sono un solo oggetto."],
	["Gli oggetti", "Foresta, lago, parco: si mettono subito nel principato; danno +3 alle opere degli artisti che li amano; dal secondo paesaggio dello stesso tipo +3 punti. Carta Prestigio: peschi 5, ne tieni 1, punti a fine partita (dimezzati in caso di pareggio sui «più»). Carta Attrazione: si scambia con una carta Mestiere già giocata da un avversario, subito o più avanti (azione gratuita); conta come carta Mestiere. Giullare: +2 a ogni tua opera. Costruttore (al massimo 3): col 1° gli edifici costano 300 invece di 700; col 2° (+3 punti) gli edifici possono toccarsi; col 3° (+3 punti) costano 0."],
	["Le azioni", "Completare un'opera (fino a 2 volte), costruire un edificio (fino a 2), prendere una carta Mestiere (300, una volta: peschi 5 e ne tieni 1), introdurre una libertà (300, una volta), prendere una carta Bonus (300: peschi 5 e ne tieni 1)."],
	["L'opera", "Giochi una carta Mestiere dalla mano. Il valore dell'opera è: +3 se hai il paesaggio che l'artista ama, +3 se hai la sua libertà, +4 se hai il suo edificio, +2 per giullare, +1 per ogni carta Mestiere o Attrazione in mano e sul tavolo (compresa quella giocata), più le carte Bonus che aggiungi (si scartano). Deve arrivare al minimo del round: 7, 10, 12, 14, 15, 16, 17. La banca paga 100 fiorini per punto di valore: subito puoi trasformarne una parte in fama, 200 fiorini per punto."],
	["Gli edifici", "10 edifici in 3 copie: grandi (Università, Laboratorio, Bottega, 7 caselle), medi (Biblioteca, Teatro dell'Opera, Studio, Ospedale, Teatro, 5 caselle), piccoli (Torre, Cappella, 3 caselle). Ogni edificio dà subito 3 punti. Si piazzano in qualsiasi orientamento, dentro la griglia, senza sovrapporsi; senza 2 costruttori non possono toccare (di lato) altri edifici né il palazzo. Ogni edificio una volta sola. I paesaggi possono toccare tutto."],
	["Fine della partita", "Dopo il 7° round si contano le carte Prestigio. Vince chi ha più punti; a parità, chi ha più fiorini."],
	["Espansione: la Musa e la Principessa", "Dopo l'asta normale c'è l'asta dei personaggi: a turno si mette la pedina su un personaggio con un'offerta (il numero sotto la pedina × 100) più alta di quella già presente, oppure si passa. Se tocca di nuovo a te e la tua pedina è ancora lì, lo prendi e paghi. Banchiere: prendi i fiorini che ha sopra (600 + 100 per ogni round in cui nessuno lo prende). Cardinale: una terza azione. Mercante: un oggetto vinto all'asta è gratis, oppure 1 punto + 1 per ogni avversario davanti a te. Musa: le tue opere del round valgono in più quanto il numero del round. Professore: una carta Bonus o Prestigio gratis. Principessa: un'opera senza carta Mestiere (paesaggi +3, edifici +2, costruttori +2, carte +1). Con i personaggi non si può cedere fama per avere fiorini."],
	["Espansione: costruzioni in comune", "Le plance del principato sono sul lato B e si toccano: ognuno ha come vicini i giocatori accanto. Un edificio può essere costruito a cavallo del confine con un vicino, se è d'accordo: almeno una casella per parte, regole di piazzamento rispettate in ciascun principato. Paghi il costo con i tuoi costruttori, il vicino ti paga la cifra concordata; l'edificio vale per entrambi e tutti e due guadagnate 3 punti. Costruendo da soli si può toccare il confine solo con 2 costruttori, oppure con 1 se dall'altra parte non c'è niente."],
	["Solitario contro Wolfgang", "Wolfgang (l'Automa) gioca con le carte dell'Automa e un dado, insieme a 2 o 3 casate fantasma che tengono solo carte Mestiere (bersagli per le tue carte Attrazione). All'asta scegli un oggetto alla volta: si tira il dado, (dado + modificatore) × 100 è l'ultima offerta e tu puoi comprare per 100 in più, o rinunciare. Con 1 o 2 senza modificatore devi comprare. All'ultima asta compri per 200 (non i due oggetti col modificatore più alto). Poi Wolfgang compra l'oggetto più a sinistra sulla carta che può prendere. Nelle azioni Wolfgang segue le carte dell'Automa: le sue opere valgono il minimo del round + giullari + carte Attrazione + Bonus, e prende sempre il massimo in fama."],
	["Comandi", "Sul tavolo: trascina per ruotare, rotella per lo zoom, tasto destro (o Maiusc+trascina) per spostare, doppio clic su un principato per inquadrarlo. «Vista 2D» mostra il tavolo dall'alto con le sole tessere. Nel piazzamento: R o tasto destro per ruotare, F per girare la tessera. F11: schermo intero."],
]


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.06, 0.03, 0.88 if overlay else 1.0)
	shade.size = size
	add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.paper(false, 34))
	box.position = Vector2(240, 40)
	box.size = Vector2(1440, 1000)
	box.custom_minimum_size = Vector2(1440, 1000)
	add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var h := HBoxContainer.new()
	var t := UI.label("Le regole in breve", 44, UI.RED, UI.font_deco)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var close := UI.button("Chiudi", 180, 52, 22)
	UI.primary(close)
	close.pressed.connect(func():
		if overlay:
			queue_free()
		else:
			main.show_menu())
	h.add_child(close)
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1360, 860)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	sc.add_child(body)
	for r in RULES:
		body.add_child(UI.label(r[0], 28, UI.INK, UI.font_title))
		body.add_child(UI.wrap(r[1], 22, 1330, UI.INK))
	var ref := UI.icon_rect(UI.tex("res://assets/board/riepilogo_carte.jpg"), Vector2(1330, 860))
	body.add_child(ref)


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if overlay:
			queue_free()
		else:
			main.show_menu()
