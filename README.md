# MT5 Forex Trading Bot

1. Technische Analyse & Mustererkennung
Verwendete Indikatoren & Logik:
ATR (Average True Range) zur Volatilitätsmessung
Momentum: Preisveränderung über 20 Perioden
Trendstärke: Verhältnis von aufwärts/abwärts Bewegungen
Pattern-Erkennung:
Double Top / Double Bottom anhand von Hoch-/Tiefpunkten
---
2. Künstliche Intelligenz / Neuronales Netz
Eigenes, einfaches Feedforward-Netzwerk mit:
10 Preis-Inputs (M5-Zeitrahmen)
1 Hidden Layer (5 Neuronen)
Sigmoid-Aktivierung
Ziel: Vorhersage des nächsten Preises
Preisdaten werden normalisiert, dann verarbeitet und wieder denormalisiert.
---
3. Trendbewertung durch Scoring
Score =Momentum * 0.4 + Volatilität * 0.3 + Trendstärke * 0.3
Wird verwendet zur Risikobewertung und Trade-Stärke-Einschätzung
---
4. Adaptives Risikomanagement
Basis-Risiko: 1%
Dynamisch angepasst je nach:
Drawdown
Tagesgewinn/-verlust
Trendbewertung
Mustererkennung
Vorhersagegüte
---
5. Live-Betrieb (Handelslogik)
Sobald der Bot läuft:
Holt ATR- und Preisdaten in Echtzeit
Analysiert Trend, Momentum, Muster
Trifft Entscheidung über Positionsgröße auf Basis des adaptiveRisk
Berechnet täglichen Profit
Wenn z. B. Vorhersage sehr nahe am Marktpreis liegt, wird Risiko leicht erhöht

---

Beim Strategie Tester haben die Bots gut abgeschlossen, nach einem Jahr wurde mit 20% Profit abgeschlossen, war aber kurzzeitig auch -15% deswegen mit Vorsicht genießen ist keine Anlage Empfehlung. 

---

## ⚠️ Wichtiger Hinweis

> Diese Projekt dienen ausschließlich **zu Lern- und Forschungszwecken**.  
> Es handelt sich **nicht um eine Finanzberatung** oder eine Aufforderung zum Handel.  
> Die Verwendung dieser Software erfolgt **auf eigene Verantwortung und Gefahr**.

Ich übernehme **keine Haftung** für finanzielle Verluste, technische Fehler oder unerwünschte Ergebnisse, die durch die Nutzung dieses Bots entstehen könnten.  
**Mach dir deine eigenen Gedanken. Teste Strategien immer zuerst auf einem Demokonto.**

---

## Voraussetzungen

- MetaTrader 5 mit EUR/USD verfügbar
- Ein Demokonto oder Livekonto bei einem MT5-kompatiblen Broker
- Installation des Bots im MetaEditor unter `Experts`

---

## Installation für ein Bot

1. Starte den **MetaEditor**
2. Erstelle eine neue Datei im Ordner `Experts`, z. B. `EURUSD_Bot.mq5`
3. Füge den vollständigen Code aus dieser Repository-Datei ein
4. Kompiliere den Bot
5. Starte ihn im MetaTrader 5 Terminal auf einem **EUR/USD Chart im M1-Zeitrahmen**

---

## Lizenz

Dieses Projekt steht unter der **MIT-Lizenz**.  
Die Nutzung erfolgt **ohne Garantie**, Haftung oder finanzielle Verpflichtung gegenüber dem Entwickler.

---