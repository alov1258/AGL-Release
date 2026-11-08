# Download

Gli installer di AGL. Scegli il sistema, poi il canale. **Production** è la versione rilasciata. **Beta** è una versione preliminare che può contenere bug; si installa accanto a Production, nella sua cartella Java25Beta, così puoi tenerle entrambe. Lo stesso installer aggiorna anche un'installazione esistente.

Come eseguirli è spiegato in [Installazione e Aggiornamento di AGL 25](manual/0200-installing-agl.md#21-installazione-e-aggiornamento-di-agl-25). Tutti i file sono anche nella [pagina delle Release](https://github.com/alov1258/AGL-Release/releases).

## Windows

### Production

[agl-install-windows.bat](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-windows.bat) - l'ultima versione rilasciata. Passaggi: [Windows](manual/0200-installing-agl.md#211-windows).

### Beta

[agl-install-windows-beta.bat](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-windows-beta.bat) - l'ultima beta.

## Linux

### Production

[agl-install-linux.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-linux.sh) - l'ultima versione rilasciata. Passaggi: [Linux](manual/0200-installing-agl.md#213-linux).

### Beta

[agl-install-linux-beta.sh](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-linux-beta.sh) - l'ultima beta.

## macOS

### Production

[agl-install-macos.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-macos.sh) - l'ultima versione rilasciata. Passaggi: [macOS](manual/0200-installing-agl.md#212-macos).

### Beta

[agl-install-macos-beta.sh](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-macos-beta.sh) - l'ultima beta.

## Tornare a una versione precedente

Se una nuova versione ti dà problemi, puoi tornare alla versione rilasciata precedente. Lo script di ripristino rimette il jar di una versione **Production** precedente e non cambia nient'altro: le tue gare, le impostazioni e gli altri file di AGL restano come sono. Salva lo script nella cartella di AGL (quella che contiene `AGL_start.bat` o `AGL_start.sh`, per esempio `C:\SOL\Java25`), chiudi AGL ed eseguilo. Mostra le versioni rilasciate e propone quella prima della più recente. Il jar più recente viene conservato nella cartella `rolled-back`, così puoi rimetterlo al suo posto per annullare. AGL ti proporrà di nuovo la versione più recente al prossimo controllo degli aggiornamenti: scegli **Ricordamelo tra una settimana**.

- [agl-rollback-windows.bat](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-windows.bat) - Windows: fai doppio clic.
- [agl-rollback-linux.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-linux.sh) - Linux: in un terminale, `bash ./agl-rollback-linux.sh`.
- [agl-rollback-macos.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-macos.sh) - macOS: nel Terminale, `bash ./agl-rollback-macos.sh`.
