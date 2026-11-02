# 10 Problemi e Bug Noti

1.  Cambiare l'elenco delle barche AIS può non causare l'aggiornamento delle tracce per le nuove barche. È necessario riavviare.

2.  Ci sono blocchi occasionali causati da problemi di livello più basso nel sistema operativo e nel Java Runtime Environment. Quando succede, di solito viene generata un'eccezione nella finestra dei comandi o nel Terminale. Variano, ma di solito sono simili a questa:

*Exception in thread "Thread-2" java.lang.NullPointerException: Cannot invoke "String.length()" because "text" is null*

*at java.base/java.text.SimpleDateFormat.parse(SimpleDateFormat.java:1471)*

*at java.base/java.text.DateFormat.parse(DateFormat.java:394)*

*at grib.GribFactory.waitForGrib(GribFactory.java:332)*

*at grib.GribFactory.run(GribFactory.java:154)*

*at java.base/java.lang.Thread.run(Thread.java:832)*

In genere è necessario riavviare.
