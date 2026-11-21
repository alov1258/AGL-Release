# 1 Overview

AGL (AutoGribLoader) is a Java 25 application that helps SailOnline sailors run their race. It takes over the repetitive jobs, and it checks your course and your DCs so that you avoid BBQs, missed marks and missing the finish line. It runs on Windows, macOS and Linux.

## 1.1 What AGL Does

**Weather**

1.  Creates the grib file for you each time the SOL weather is updated.

2.  Can download the NOAA GFS weather as it becomes available, for up to 16 days. For the first 180 hours the result matches the SOL grib. NOAA CFS data can extend this for long races (see [7 NOAA Server](0700-noaa-server.md#7-noaa-server)).

**DCs and waypoints**

3.  A DC Editor that shows the DCs of the DC area as a table you can edit directly, with a graphical DC Checker that checks and edits the series against the map tiles, allowing for performance loss. Traces and Stored Sets keep your earlier checks and Sets so you can compare them with the current ones.

4.  Routes and waypoints kept in a database by the hub, with a Routes form, editing on the graphics, and conversion of waypoints to DCs, including maxVMG waypoints.

5.  A DC Data Table that loads a route from Expedition or qtVlm, to check and set as DCs (see [6 DC Data Table](0600-dc-data-table.md#6-dc-data-table)).

6.  Imports a .wpt or .gpx file as a route, and exports a route as a GPX file, to load into routing packages.

7.  Creates detailed qtVlm and Expedition polar files for the race.

**Checks while you race (members only)**

8.  Checks your course and DCs for BBQs, missed marks and the finish line, offers fixes, and keeps checking as the race goes on (see [5.2 Checking the Course](0500-using-agl.md#52-checking-the-course)). (Members only.)

**Phone messages (members only)**

9.  The Chats tab shows the SOL chat rooms, and has a Messaging box that sends key events to your phone through Pushover and Telegram. Messaging is set up once in the hub for every race. Telegram lets you answer from your phone (see [8 Chats](0800-chats.md#8-chats)).

**Working with other software**

10. Integrates with qtVlm: AGL can create and launch a race-specific qtVlm for you (members only).

11. An NMEA server that updates your boat position in real time in routing packages, including AIS messages for SOL boats.

**Running AGL**

12. Sounds a boat horn when you run aground and are racing.

13. The AGL Hub is the one AGL window on your taskbar. It has a tab for each race, so you can run several races, and it manages your SailOnline login, updates and restarts. It can also watch for new SailOnline races and register you in them (see [2 Installing AGL](0200-installing-agl.md#2-installing-agl)).

14. Logs boat data to a csv file, with position data accurate to one second, and keeps a log file for later analysis. The Logger tab holds the essentials, and View > Detailed logging adds the working detail. The Help menu can gather your logs and start an email to the author when you need help.

15. A Simulator that stands in for the SOL server, so you can test AGL and what you will see on your phone without touching your real boat (see [9 Simulator](0900-simulator.md#9-simulator)). (Members only.)

## 1.2 Quick Start

These are the key steps to get you going. Each one points to the part of the manual that explains it in full.

1.  **Install AGL.** Run the installer for your system. See [2.1 Installing and Upgrading AGL 25](0200-installing-agl.md#21-installing-and-upgrading-agl-25).

2.  **Start AGL.** Double click the AGL25 icon. The AGL Hub opens. The first time, AGL asks for your **races directory**: the folder that will hold all of your race folders, for example D:\sailonline\Races. Do not use the Java25 folder. See [2.3.2 Starting AGL for the First Time](0200-installing-agl.md#232-starting-agl-for-the-first-time).

3.  **Add a race.** Click **Add Race** and choose a race folder, or make a new one. **Open** starts AGL in the folder and waits for you to press Apply. **Start** starts it and presses Apply for you. Or tick **Watch for new races** on the hub's Launcher tab, and the hub offers you each new race and registers you. See [2.3.3.5 Adding a Race](0200-installing-agl.md#2335-adding-a-race).

4.  **Log in and fill in the Parameters tab.** Enter your SOL user name and password once in the hub, with **SOL > Login...**. On the Parameters tab leave **Use the hub login** ticked, choose the **Race** from the drop-down list, and press **Apply**. See [2.3.3.9 The SOL Login](0200-installing-agl.md#2339-the-sol-login) and [3 Configuration](0300-configuration.md#3-configuration).

5.  **Wait for initialisation.** It can take up to 30 seconds. When it is done, AGL shows the DC Checker tab, and your boat data starts to appear. See [4 Initialisation](0400-initialisation.md#4-initialisation).

6.  **Check and set your DCs.** Your current DCs are loaded into the Delay Commands window and the DC Editor. Edit them, check them against the map, then press **Set** to send them to the server. See [5.1 DC Checker Tab](0500-using-agl.md#51-dc-checker-tab).

7.  **Switch the checks on (members only).** Tick **In Control** on the DC Checker tab, and AGL warns you about BBQs and missed marks while you race. **Check for BBQ** and **Check mark roundings** on the Parameters tab decide whether AGL also offers a fix. See [5.2 Checking the Course](0500-using-agl.md#52-checking-the-course).

**If something goes wrong,** send your logs to the author. Choose **Help > Mail logs...** in the hub or in a race window. If the author asks, tick **View > Detailed logging** first and repeat the problem. AGL gathers the logs, removes anything secret such as passwords and tokens, and opens a new email for you, with the folder holding the zip file beside it. Add what you were doing and what went wrong, drag the zip into the email, and send it. Nothing leaves your computer until you press **Send**. See [Mailing Your Logs](0200-installing-agl.md#mailing-your-logs).

When that works, you may want to add:

- **qtVlm integration**, to launch a race-specific qtVlm (see [3.7 qtVlm](0300-configuration.md#37-qtvlm)).

- **NOAA grib download**, for weather beyond what SOL gives (see [7 NOAA Server](0700-noaa-server.md#7-noaa-server)).

- **Messages to your phone** through Pushover or Telegram (see [8 Chats](0800-chats.md#8-chats)).

- **The Simulator**, to try things out safely (see [9 Simulator](0900-simulator.md#9-simulator)).

## 1.3 How This Manual Is Organised

- [2 Installing AGL](0200-installing-agl.md#2-installing-agl): installing, launching, the hub and updating.

- [3 Configuration](0300-configuration.md#3-configuration): every field on the Parameters tab.

- [4 Initialisation](0400-initialisation.md#4-initialisation): what happens after you press Apply.

- [5 Using AGL](0500-using-agl.md#5-using-agl): the DC Checker, the course checks and the graphics.

- [6 DC Data Table](0600-dc-data-table.md#6-dc-data-table): loading routes from your routing package.

- [7 NOAA Server](0700-noaa-server.md#7-noaa-server): downloading weather from NOAA.

- [8 Chats](0800-chats.md#8-chats): SOL chats, Pushover and Telegram.

- [9 Simulator](0900-simulator.md#9-simulator): testing without a real boat.

- **Chapters 10 and 11** [10 Known Issues and Bugs](1000-known-issues-and-bugs.md#10-known-issues-and-bugs) and [11 Acknowledgements](1100-acknowledgements.md#11-acknowledgements).
