# I Principi di Firenze — versione digitale

Adattamento digitale per uso personale di **I Principi di Firenze** (*The Princes of Florence*) di Wolfgang Kramer, Richard Ulrich e Jens Christopher Ulrich, nell'edizione con le illustrazioni di Lukas Siegmon. Fatto con Godot 4.7, si gioca nel browser:

**https://tannoiser2.github.io/Principi-di-Firenze/**

## Cosa c'è

- Partita da 2 a 5 casate, ognuna su Umano, IA (facile, normale, esperta) o Assente.
- **La Musa e la Principessa**: l'asta dei sei personaggi (Banchiere, Cardinale, Mercante, Musa, Professore, Principessa).
- **Costruzioni in comune**: plance del principato sul lato B, edifici a cavallo del confine con il vicino, che paga la cifra proposta e può rifiutare.
- **Solitario contro Wolfgang**: le 21 carte dell'Automa, il dado, 2 o 3 casate fantasma, tre livelli di difficoltà.
- **Gioco online** con Firebase (stesso progetto degli altri giochi della ludoteca, radice `principi/rooms`): chi crea la stanza dà il codice di 4 lettere agli amici; i posti liberi li gioca l'IA, chi si disconnette viene sostituito dall'IA finché non rientra.
- **Tavolo 3D**: si ruota trascinando, si avvicina con la rotella, si sposta col tasto destro; doppio clic su un principato per inquadrarlo. Gli edifici e i paesaggi sono modelli dipinti generati con Meshy a partire dalle tessere del gioco (tools/ e `assets/models`). «Vista 2D» mostra il tavolo dall'alto con le sole tessere.

## Testi provvisori

Le carte vengono dal modulo Tabletop Simulator in inglese; nomi e testi dell'interfaccia sono in italiano ma provvisori, da allineare alla scatola italiana (scansione in arrivo).

## Struttura

- `scripts/data/pf_data.gd` — professioni, edifici e sagome, carte Bonus e Prestigio, carte dell'Automa, personaggi.
- `scripts/core/state.gd` — regole immediate: piazzamenti, costi, valore delle opere, punteggi.
- `scripts/core/engine.gd` — svolgimento della partita (aste, personaggi, azioni, Wolfgang).
- `scripts/core/ai.gd` — l'IA degli avversari.
- `scripts/net/` — Firebase (accesso anonimo, stanze, registro delle mosse).
- `scripts/ui/` — menu, tavolo 3D, interfaccia della partita, piazzamento delle tessere, regole.
- `tools/prepara_asset.py` — ricava immagini, carte e tessere dal modulo TTS.
- `tests/` — partite simulate (`sim.gd`), prova dell'app senza schermo (`ui_smoke.gd`), fotografie (`shot.gd`).

```
godot --headless --path . --script tests/sim.gd -- 5
```

A ogni aggiornamento del ramo `main` la GitHub Action costruisce la versione web e la pubblica su Pages (Impostazioni → Pages → Sorgente: GitHub Actions).
