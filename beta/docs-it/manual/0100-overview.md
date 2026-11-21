# 1 Panoramica

AGL (AutoGribLoader) è un'applicazione Java 25 che aiuta i velisti di SailOnline a gestire la loro regata. Si occupa dei compiti ripetitivi e controlla il tuo percorso e i tuoi DC, in modo da evitare BBQ, boe mancate e la mancata linea di arrivo. Funziona su Windows, macOS e Linux.

## 1.1 Cosa Fa AGL

**Meteo**

1.  Crea per te il file grib ogni volta che il meteo SOL viene aggiornato.

2.  Può scaricare il meteo NOAA GFS man mano che diventa disponibile, fino a 16 giorni. Per le prime 180 ore il risultato coincide con il grib SOL. I dati NOAA CFS possono estenderlo per le regate lunghe (vedi [7 Server NOAA](0700-noaa-server.md#7-server-noaa)).

**DC e waypoint**

3.  Un Editor DC che mostra i DC dell'area DC come una tabella che puoi modificare direttamente, con un DC Checker grafico che controlla e modifica la serie rispetto alle tile delle mappe, tenendo conto della perdita di prestazioni. Tracce e Set salvati conservano i tuoi controlli e Set precedenti, così puoi confrontarli con quelli attuali.

4.  Percorsi e waypoint conservati in un database dall'hub, con un modulo Percorsi, la modifica nella grafica e la conversione dei waypoint in DC, compresi i waypoint maxVMG.

5.  Una DC Data Table che carica una rotta da Expedition o qtVlm, da controllare e impostare come DC (vedi [6 DC Data Table](0600-dc-data-table.md#6-dc-data-table)).

6.  Importa un file .wpt o .gpx come percorso, ed esporta un percorso come file GPX, da caricare nei pacchetti di routing.

7.  Crea file polari dettagliati per qtVlm ed Expedition per la regata.

**Controlli durante la regata (solo per i membri)**

8.  Controlla il tuo percorso e i tuoi DC per BBQ, boe mancate e linea di arrivo, propone soluzioni e continua a controllare mentre la regata prosegue (vedi [5.2 Verifica del Percorso](0500-using-agl.md#52-verifica-del-percorso)). (Solo per i membri.)

**Messaggi sul telefono (solo per i membri)**

9.  La scheda Chat mostra le chat room di SOL, e ha un riquadro Messaggi che invia gli eventi principali al telefono tramite Pushover e Telegram. I messaggi si configurano una volta nell'hub per tutte le regate. Telegram ti permette di rispondere dal telefono (vedi [8 Chat](0800-chats.md#8-chat)).

**Lavorare con altro software**

10. Si integra con qtVlm: AGL può creare e avviare per te un qtVlm specifico per la regata (solo per i membri).

11. Un server NMEA che aggiorna in tempo reale la posizione della tua barca nei pacchetti di routing, compresi i messaggi AIS per le barche SOL.

**Eseguire AGL**

12. Suona una sirena da nave quando vai in secca durante la regata.

13. L'AGL Hub è l'unica finestra di AGL nella barra delle applicazioni. Ha una scheda per ogni regata, così puoi eseguire più regate, e gestisce il tuo accesso a SailOnline, gli aggiornamenti e i riavvii. Può anche controllare le nuove regate SailOnline e iscriverti (vedi [2 Installazione di AGL](0200-installing-agl.md#2-installazione-di-agl)).

14. Registra i dati della barca in un file csv, con dati di posizione precisi al secondo, e conserva un file di log per analisi successive. La scheda Registro contiene l'essenziale, e Vista > Registro dettagliato aggiunge il dettaglio di lavoro. Il menu Aiuto può raccogliere i tuoi log e preparare un'email all'autore quando hai bisogno di aiuto.

15. Un Simulatore che sostituisce il server SOL, così puoi provare AGL e ciò che vedrai sul telefono senza toccare la tua barca reale (vedi [9 Simulatore](0900-simulator.md#9-simulatore)). (Solo per i membri.)

## 1.2 Avvio Rapido

Questi sono i passaggi principali per iniziare. Ognuno rimanda alla parte del manuale che lo spiega per intero.

1.  **Installa AGL.** Esegui l'installer per il tuo sistema. Vedi [2.1 Installazione e Aggiornamento di AGL 25](0200-installing-agl.md#21-installazione-e-aggiornamento-di-agl-25).

2.  **Avvia AGL.** Fai doppio clic sull'icona AGL25. Si apre l'AGL Hub. La prima volta, AGL ti chiede la tua **cartella delle regate** (races directory): la cartella che conterrà tutte le tue cartelle di regata, ad esempio D:\sailonline\Races. Non usare la cartella Java25. Vedi [2.3.2 Avvio di AGL per la Prima Volta](0200-installing-agl.md#232-avvio-di-agl-per-la-prima-volta).

3.  **Aggiungi una regata.** Fai clic su **Aggiungi regata** e scegli una cartella di regata, oppure creane una nuova. **Apri** avvia AGL nella cartella e attende che tu prema Applica. **Avvia** lo avvia e preme Applica al posto tuo. Oppure seleziona **Controlla le nuove regate** nella scheda Launcher dell'hub, e l'hub ti propone ogni nuova regata e ti iscrive. Vedi [2.3.3.5 Aggiungere una Regata](0200-installing-agl.md#2335-aggiungere-una-regata).

4.  **Accedi e compila la scheda Parametri.** Inserisci il tuo nome utente e la tua password SOL una volta nell'hub, con **SOL > Accesso...**. Nella scheda Parametri lascia selezionato **Usa l'accesso dell'hub**, scegli la **Regata** dall'elenco a discesa e premi **Applica**. Vedi [2.3.3.9 L'Accesso SOL](0200-installing-agl.md#2339-laccesso-sol) e [3 Configurazione](0300-configuration.md#3-configurazione).

5.  **Attendi l'inizializzazione.** Può richiedere fino a 30 secondi. Al termine, AGL mostra la scheda Controllo DC e iniziano ad apparire i dati della tua barca. Vedi [4 Inizializzazione](0400-initialisation.md#4-inizializzazione).

6.  **Controlla e imposta i tuoi DC.** I tuoi DC attuali vengono caricati nella finestra Comandi ritardati e nell'Editor DC. Modificali, controllali rispetto alla mappa, poi premi **Set** per inviarli al server. Vedi [5.1 Scheda Controllo DC](0500-using-agl.md#51-scheda-controllo-dc).

7.  **Attiva i controlli (solo per i membri).** Seleziona **In controllo** nella scheda Controllo DC, e AGL ti avvisa dei BBQ e delle boe mancate mentre fai regata. **Controllo BBQ** e **Controllo delle boe** nella scheda Parametri decidono se AGL propone anche una soluzione. Vedi [5.2 Verifica del Percorso](0500-using-agl.md#52-verifica-del-percorso).

**Se qualcosa va storto,** invia i tuoi log all'autore. Scegli **Aiuto > Invia i log...** nell'hub o in una finestra di regata. Se l'autore lo chiede, seleziona prima **Vista > Registro dettagliato** e ripeti il problema. AGL raccoglie i log, rimuove tutto ciò che è segreto, come password e token, e apre una nuova email per te, con la cartella che contiene il file zip accanto. Aggiungi cosa stavi facendo e cosa è andato storto, trascina lo zip nell'email e invia. Nulla lascia il tuo computer finché non premi **Invia**. Vedi [Invio dei Log per Email](0200-installing-agl.md#invio-dei-log-per-email).

Quando tutto funziona, puoi voler aggiungere:

- **L'integrazione con qtVlm**, per avviare un qtVlm specifico per la regata (vedi [3.7 qtVlm](0300-configuration.md#37-qtvlm)).

- **Il download dei grib NOAA**, per un meteo oltre quello fornito da SOL (vedi [7 Server NOAA](0700-noaa-server.md#7-server-noaa)).

- **I messaggi sul telefono** tramite Pushover o Telegram (vedi [8 Chat](0800-chats.md#8-chat)).

- **Il Simulatore**, per provare le cose in sicurezza (vedi [9 Simulatore](0900-simulator.md#9-simulatore)).

## 1.3 Come È Organizzato Questo Manuale

- [2 Installazione di AGL](0200-installing-agl.md#2-installazione-di-agl): installazione, avvio, hub e aggiornamento.

- [3 Configurazione](0300-configuration.md#3-configurazione): ogni campo della scheda Parametri.

- [4 Inizializzazione](0400-initialisation.md#4-inizializzazione): cosa succede dopo aver premuto Apply.

- [5 Utilizzo di AGL](0500-using-agl.md#5-utilizzo-di-agl): il DC Checker, i controlli del percorso e la grafica.

- [6 DC Data Table](0600-dc-data-table.md#6-dc-data-table): caricare le rotte dal tuo pacchetto di routing.

- [7 Server NOAA](0700-noaa-server.md#7-server-noaa): scaricare il meteo da NOAA.

- [8 Chat](0800-chats.md#8-chat): chat SOL, Pushover e Telegram.

- [9 Simulatore](0900-simulator.md#9-simulatore): provare senza una barca reale.

- **Capitoli 10 e 11** [10 Problemi e Bug Noti](1000-known-issues-and-bugs.md#10-problemi-e-bug-noti) e [11 Ringraziamenti](1100-acknowledgements.md#11-ringraziamenti).
