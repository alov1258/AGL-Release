# AGL commands - AG (AGL without AP)

Commands available in the AG (AGL without AP). Type them in the command box; they are not case sensitive.

### Waypoints, routes and DC checks

| Command | What it does |
|---|---|
| `WP` | Loads the active route and shows its waypoints in the graphics. It only shows the waypoints; it does not start steering. |
| `FWP` | Shows waypoints and tiles, asking for a filter tolerance |
| `SFWP` | As FWP, and saves the filtered waypoints |
| `WC` | Waypoint checker: draws the waypoints and tiles |
| `SC` | Writes a DXF file of the waypoints and tiles |
| `VC` | Checks the route with the VMG waypoint maker and draws it |
| `WPCVMC` | As VC, with VMC instead of VMG |
| `WP2DC` | Turns the route into DCs, puts them in the DC area and loads them for editing in the graphics |
| `WPE` | The VMC button: makes the active route the route of the VMC or VMG box |
| `WE B` | Which End Checker: which end of the finish line the boat reaches, from the boat's position (only `WE,B` exists) |
| `CDC` | DC Checker: checks the DCs in the DC area and draws the trace (PL as the server's list) |
| `CDCPL` | DC Checker with PL |
| `CDCPLS` | DC Checker with PL, as set |
| `DB` | DC BBQ Checker: plots the DC monitor's waypoints to find land crossings (BBQs) |
| `PC` | Checks performance loss (PL) for the given parameters |

### Running the autopilot and steering

| Command | What it does |
|---|---|
| MC `<ct> <lat> <lon>` | The same mark as M, checked only (autopilot not started) |
| MT `<ct> <lat> <lon>` | The same mark, checked and the DCs made, autopilot not started |
| `X` | Exits normally, stopping any running steer first |

### Immediate boat commands (steerVMG, server DCs)

| Command | What it does |
|---|---|
| `MU` `<P/S>` | Max VMG to windward |
| `MD` `<P/S>` | Max VMG downwind |
| `MS` `<P/S>` | Max speed |
| `TM` | Tack now to Max VMG |
| `TN` | Tack now, no dialog |
| `GM` | Gybe now to Max VMG |
| `GN` | Gybe now, no dialog |
| CC `<brg>` | Change to a compass bearing |
| CP `<brg>` | Change to a bearing with minimum PL |
| TT `<twa>` | Change to a TWA |
| TP `<twa>` | Change to a TWA with minimum PL |
| `DL` | Sets the DCs now (DC list to the server) |
| `DD` | Deletes all DCs on the server now |
| `CD` | Sets the first DC in the DC list |
| `DR` | Refreshes the DC list from the server |
| SM `<text>` | Sends a message to the race |

### Weather, grib and boat data

| Command | What it does |
|---|---|
| `NG` | Runs the NOAA grib download once |
| `NGT` | Starts the NOAA grib download thread |
| `NGS` | Stops the NOAA grib download thread |
| `WX` | Asks for a new Wx update |
| `CG` | Checks the grib at the boat's position |
| `GD` | Checks the grib at the start time and position |
| `GC` | Plots the grib contours |
| `BD` | Prepares the grib data for the graphics |
| `SPD` | Shows the boat polar display |
| `OBDT` | Opens the Boat Data Table (AIS) |
| `ST` | Waits for the server time and prints it |
| `AA` | Applies a changed alternate polar file and reloads the race info |

### Windows and display

| Command | What it does |
|---|---|
| `GL` | Shows or restores the graphics window |
| `RG` | Rebuilds the graphics window |
| `SF` | Saves the settings and redraws the course in the graphics |
| `DCE` | Opens the DC area (DC editor) |
| `DCT` | Opens the DC table |
| FS `<size>` | Sets the font size |
| `TS` | Takes a snapshot of the feedback area to a file |
| `IP` | Prints the current values |
| TILE `<lat,lon>` | Says which coastline tile that position is in |
| `PL` | Plays the boat horn sound |

### Test and diagnostic commands

| Command | What it does |
|---|---|
| `SIM` | Test server simulator (`SIM lat,lon`, `WIND`, `SPEED`, `DC`, `STATUS`, `OFF`) |
| `ICTEST` | Isochrones from the boat (or route) to a point in a window of their own; nothing changes in the race |
| `ICSWEEP` | Isochrone search over a grid of steps, angles and cones on given routes; table of times |
| QT TEST / WATCH / DEBUG | Changes the qtVlm testing switches while AGL runs |
| PLJITTER `<ms>` | Test: random delay of 0 to ms on each DC sent |
| PLSUSPECT `<ms>` | Test: a DC in a PL block whose POST takes this long is sent again at once (`AUTO` resets) |
| PLFORCE ON/OFF | Test: next Sets delete every server DC and send all DCs |
| PLRESEND ON/OFF | Test: after a Set, a PL gap outside recoveryTime to +1 s is sent again |
| MEM `[secs]` | Diagnostic: heap, grib lists, live classes, thread allocation |
| CRASH `[THREAD/CMD]` | Test: throws an uncaught exception to check console and exit code 2 |
