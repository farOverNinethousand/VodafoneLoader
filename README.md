# VodafoneLoader | VfLoader
Automatisiertes Einlösen von Vodafone CallYa Aufladecodes über ADB (Android Debug Bridge).

Das Script verbindet sich per USB mit einem Android-Gerät, sendet die USSD-Codes automatisch, liest die Antwort aus dem Dialog aus und speichert die Ergebnisse in einer Datei.  
Es merkt sich den Fortschritt und fragt beim nächsten Start, ob es fortfahren soll.

---

## Hintergrund
Vodafone erlaubt es, auch Laufzeitverträge mit CallYa "Prepaid" Codes aufzuladen.  
Diese Codes gibt es immer mal wieder rabattiert.  
Mehr Infos dazu:  
https://www.handyhase.de/magazin/vodafone-vertrag-guthaben-bezahlen/  
https://www.mydealz.de/diskussion/kaufland-vodafone-guthaben-ean-2323482
Leider ist der Einlöseprozess zeitaufwändig und man bekommt oft nur Codes in den Wertstufen 15€ oder 25€ d.h. am Ende braucht man sehr viele Codes.  
Dieses Projekt soll die Einlösung mehrerer solcher Codes vereinfachen.  
Wenn du einen frischen Vodafone Vertrag hast und möglichst alle Vertragskosten mit Guthaben bezahlen möchtest empfielt es sich, mindestens 120€ aufzuladen, sobald man die (s)SIM Karte erhält.

## Voraussetzungen

### Hardware
- Windows
- Android Gerät mit ADB (Android Debug Bridge) – ADB wird beim ersten Start optional automatisch heruntergeladen

### Vorbereitungen
1. Die 15-stelligen CallYa Aufladecodes zeilengetrennt in ein Textdokument speichern. Dieser zeitaufwändige Schritt wird in Zukunft evtl ebenfalls automatisiert.
2. Android Gerät vorbereiten siehe Anleitung unten.
3. Falls du mehr als eine SIM Karte in dem Gerät hast stelle sicher, dass nur die Vodafone SIM aktiviert ist, die mit CallYa Codes aufgeladen werden soll.
4. Stelle sicher, dass das Gerät mindestens dauerhaft einen Balken Empfang hat.
5. Die Systemsprache des Geräte muss Deutsch sein.
6Fahre mit "Installation & Guthabeneinlösung" unten fort.

### Android-Gerät vorbereiten
1. USB-Debugging aktivieren (Einstellungen → Entwickleroptionen → USB-Debugging)
2. Gerät per USB mit dem PC verbunden
3. USB-Debugging beim ersten Verbinden auf dem Gerät bestätigen. Genauere Anleitung siehe URLs unten.

**Anleitung zur ADB-Einrichtung auf dem Gerät:**
- EN: https://www.xda-developers.com/install-adb-windows-macos-linux/
- DE: https://support.isafe-mobile.com/de/support/solutions/articles/77000569929-wie-installiere-ich-adb-auf-meinem-pc-

---

## Installation & Guthabeneinlösung

1. Powershell starten und folgenden Befehl eintippen:  
`irm https://raw.githubusercontent.com/farOverNinethousand/VodafoneLoader/main/vfloader-install.ps1 | iex`  
Powershell muss **nicht** als Admin gestartet werden!
2. Das Script leitet dich durch den Einlösevorgang.  
Die meisten Probleme dürfte es mit der Einrichtung von ADB geben.  
3. Wichtig: Benutze dein Handy nicht mehr, sobald das Script mit der Einlösung startet.  
Sollten unerwartete Dinge währenddessen passieren, kannst du das Script jederzeit schließen oder die Ausführung mit der Tastenkombination STRG + C stoppen.

## FAQ  
**Wie viele Codes kann man pro Tag einlösen?**  
Keine Ahnung.

**Woher bekommt man die Codes typischerweise rabattiert?**  
* Wunschgutschein.de
* Kaufland offline

**Gute Quellen für aktuelle Rabattaktionen:**  
* MyDealz.de
* CashbackOptimizer: https://cashback-optimizer.de/?filter=vodafone

## Links und sonstiger Kram
Testcodes:
`108000000000001
108000000000002
108000000000003`

USSD Codes Infos:  
https://www.handyhase.de/magazin/vodafone-ussd-codes/

Haupt-Commands:

Guthaben abfragen:  
`adb shell am start -a android.intent.action.CALL -d tel:*100*%23`

Vf Code einlösen:  
`adb shell am start -a android.intent.action.CALL -d tel:*100*108000000000001%23`

ENTER drücken:  
`adb shell input keyevent KEYCODE_ENTER`

Bildschirminhalt als XML auslesen:  
```
adb shell uiautomator dump /sdcard/screen.xml
adb pull /sdcard/screen.xml
```

## Ideen
* Blablub