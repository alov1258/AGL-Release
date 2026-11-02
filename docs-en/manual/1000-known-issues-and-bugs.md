# 10 Known Issues and Bugs

1.  Changing the AIS boat list may not cause an update of boat traces for new boats. A restart is needed.

2.  There are occasional hangs that are caused by lower level issues in the operating system and Java Runtime Environment. When these happen, an exception is typically thrown in the command window or Terminal. They will vary, but typically look like this:

*Exception in thread "Thread-2" java.lang.NullPointerException: Cannot invoke "String.length()" because "text" is null*

*at java.base/java.text.SimpleDateFormat.parse(SimpleDateFormat.java:1471)*

*at java.base/java.text.DateFormat.parse(DateFormat.java:394)*

*at grib.GribFactory.waitForGrib(GribFactory.java:332)*

*at grib.GribFactory.run(GribFactory.java:154)*

*at java.base/java.lang.Thread.run(Thread.java:832)*

A restart is typically required.
