# 7 Server NOAA

Il server NOAA è un server dati opzionale che può essere abilitato per scaricare gli stessi dati meteo (Wx) utilizzati da SOL. Le prime 180 ore di grib che scarica sono identiche a quelle di SOL. Il TWA e il TWS restituiti in qualsiasi punto e in qualsiasi momento fino a 180 ore dall'orario di creazione del grib saranno gli stessi per entrambi i grib.

Oltre alle 180 ore che usa SOL, si possono scaricare altri grib fino a 384 ore dal momento di creazione, ovvero 16 giorni. Il numero di giorni può essere specificato e può essere qualsiasi numero da 1 a 16 (il valore predefinito è 16). Per le regate che durano più di 16 giorni si possono usare i dati NOAA CFS (Climate Forecast System), che arrivano fino a 9 mesi.

## 7.1 Cosa Viene Scaricato

Per risparmiare memoria e ridurre la dimensione dei file, i dati GFS vengono scaricati in due parti:

- Dati a **0,25 gradi** per le prime 192 ore (8 giorni). Vengono fusi sulla griglia SOL, quindi si uniscono al grib SOL senza discontinuità.
- Dati a **1 grado** dalle 192 alle 384 ore. Vengono conservati come scaricati, con una griglia propria, il che mantiene piccoli i file.

Se il numero di giorni richiesti è 8 o meno, vengono scaricati solo i dati a 0,25 gradi. Il grib finale viene reinterpolato per corrispondere alla risoluzione del grib SOL.

### 7.1.1 CFS: Oltre i 16 Giorni (Solo per i Membri)

Se chiedi più di 16 giorni, i membri possono far proseguire la previsione oltre la fine dei dati GFS con il modello NOAA CFS (Climate Forecast System). CFS fornisce vento e pressione a 1 grado, ogni 6 ore, a partire dal primo orario a 6 ore dopo l'ultimo frame GFS.

CFS non è legato al ciclo GFS. NOAA pubblica un ciclo CFS ogni 6 ore, e i frame di cui AGL ha bisogno compaiono sul server NOAA circa 7 ore e 40 minuti dopo l'ora del ciclo. AGL inizia a controllare qualche minuto prima, controlla ogni minuto finché ci sono, e li scarica tutti insieme. L'area Riscontro ti dice cosa sta succedendo, ad esempio (orari UTC):

- "CFS gribs expected. Checking for gribs"
- "Checking for CFS gribs. 15 minutes late"
- "CFS gribs are being published: 12 of 20 frames so far. Checking again every minute."
- "CFS cycle 2026/10/31 06 is in use. Next CFS cycle (2026/10/31 12) is expected on the server about 2026/10/31 19:40:00."

NOAA pubblica i frame di un ciclo CFS in ordine di previsione mentre il modello è in esecuzione, quindi un ciclo può essere presente solo in parte. AGL scarica ciò che c'è e recupera il resto nei controlli successivi.

## 7.2 Download Interrotti

Se un download viene interrotto (AGL viene chiuso, il computer va in sospensione o perde la connessione, oppure NOAA smette di rispondere), AGL non ricomincia da capo. La volta successiva legge il file già presente sul disco, conserva i frame completi, scarta l'ultimo frame ricevuto a metà e prosegue da lì. Vale per il file a 0,25 gradi, per il file a 1 grado e per il file CFS.

I frame già presenti sul disco vengono messi subito in memoria, quindi sono disponibili per il routing e per i controlli mentre il resto è ancora in download.

## 7.3 I File

Il server crea file nella cartella grib, e nella cartella NOAA sotto di essa.

1.  A_GFS_SOLNOAA\_{race id}\_{grib_time}.grb. Questo è il file composito che può essere utilizzato per il routing, ad es. A_GFS_SOLNOAA_1820_2024070218.grb. A questo file viene aggiunta la pressione al livello medio del mare se tale opzione è selezionata.
2.  GFS_NOAA\_{race id}\_{grib_time}\_0p25.grb2. Questi sono i dati grezzi a 0,25 gradi per le prime 192 ore, scaricati da NOAA e memorizzati nella cartella grib\NOAA, ad es. GFS_NOAA_1820_2024070218_0p25.grb2
3.  GFS_NOAA\_{race id}\_{grib_time}\_1p00.grb2. Questi sono i dati grezzi a 1 grado per le ore da 192 a 384, nella cartella grib\NOAA.
4.  CFS_NOAA\_{race id}\_{cfs_cycle_time}\_1p00.grb2. Solo per i membri. Sono i dati CFS, un file per ogni ciclo CFS, nella cartella grib\NOAA.

Nota che il grib A può essere caricato e usato non appena viene creato, quindi non c'è bisogno di aspettare il completamento del download NOAA. Conterrà solo i frame fino all'ultimo frame scaricato. Per avere più frame, vedi [current_grib.grb](#731-current_gribgrb).

### 7.3.1 current_grib.grb

AGL conserva nella cartella grib anche un altro file, **current_grib.grb** (formato GRIB1). È un'istantanea del Wx che AGL ha in memoria in quel momento, e viene riscritto ogni volta che arriva qualcosa di nuovo: un nuovo grib SOL, oppure ogni frame NOAA (o CFS) man mano che viene scaricato. Contiene il grib SOL seguito dai frame NOAA e poi dai frame CFS. I frame a 0,25 gradi vengono per primi, reinterpolati per corrispondere alla risoluzione e al numero di frame del grib SOL. Dopo questi, seguono i frame NOAA a 1 grado e poi i frame CFS. Vento e pressione ci sono entrambi, se selezionati. I frame precedenti all'ora attuale vengono esclusi.

In memoria un nuovo grib SOL sostituisce i frame NOAA sul proprio intervallo, ma i frame NOAA oltre la fine del grib SOL restano finché un ciclo NOAA più recente non li sostituisce.

Per il routing a lungo raggio in qtVlm, carica **current_grib.grb** nello slot 1. È sempre il Wx più recente e più lungo che AGL possiede, quindi non c'è bisogno di scegliere il grib A giusto né di ricaricarlo mentre il download procede. Quando apri Routing settings in qtVlm, AGL controlla la prima data del grib che qtVlm ha caricato e ti avvisa se è più vecchia di quella che AGL sta usando.
