# 7 NOAA Server

The NOAA server is an optional data server that can be enabled to download the same Wx data that SOL uses. The first 180 hours of gribs that it downloads are identical to SOL. TWA and TWS returned at any point and at any time up to 180 hours from grib creation time will be the same for both gribs.

In addition to the 180 hours that SOL uses, additional gribs up to 384 hours from creation time can be downloaded, or 16 days. The number of days can be specified and may be any number from 1 to 16 (the default is 16). For races that extend longer than 16 days, NOAA CFS (Climate Forecast System) data can be used, going out to 9 months.

## 7.1 What Is Downloaded

To conserve memory and reduce file sizes, GFS data is downloaded in two parts:

- **0.25 degree** data for the first 192 hours (8 days). This is blended onto the SOL grid, so it joins the SOL grib seamlessly.
- **1 degree** data from 192 hours to 384 hours. This is kept as downloaded, with its own grid, which keeps the files small.

If the number of days you ask for is 8 or less, only the 0.25 degree data is downloaded. The final grib is re-interpolated to match the SOL grib resolution.

### 7.1.1 CFS: Beyond 16 Days (Members Only)

If you ask for more than 16 days, members can have the forecast carried on past the end of the GFS data with the NOAA CFS (Climate Forecast System) model. CFS gives wind and pressure at 1 degree, every 6 hours, starting at the first 6 hourly time after the last GFS frame.

CFS is not tied to the GFS cycle. NOAA publishes a CFS cycle every 6 hours, and the frames AGL needs appear on the NOAA server about 7 hours 40 minutes after the cycle time. AGL starts looking a few minutes before that, checks every minute until they are there, and fetches them at once. The Feedback area tells you what is happening, for example (times are UTC):

- "CFS gribs expected. Checking for gribs"
- "Checking for CFS gribs. 15 minutes late"
- "CFS gribs are being published: 12 of 20 frames so far. Checking again every minute."
- "CFS cycle 2026/10/31 06 is in use. Next CFS cycle (2026/10/31 12) is expected on the server about 2026/10/31 19:40:00."

NOAA publishes the frames of a CFS cycle in forecast order while the model runs, so a cycle can be only partly there. AGL fetches what is there and picks up the rest on later checks.

## 7.2 Interrupted Downloads

If a download is interrupted (AGL is closed, the computer sleeps or goes offline, or NOAA stops responding), AGL does not start again. The next time it runs it reads the file already on your disk, keeps the frames that are complete, discards a half-received last frame, and carries on from there. This applies to the 0.25 degree file, the 1 degree file and the CFS file.

The frames already on disk are put into memory straight away, so they are available for routing and for the checks while the rest is still downloading.

## 7.3 The Files

The server creates files in the grib folder, and in the NOAA folder below that.

1.  A_GFS_SOLNOAA\_{race id}\_{grib_time}.grb. This is the composite file that can be used for routing. e.g. A_GFS_SOLNOAA_1820_2024070218.grb. Mean Sea Level Pressure is added to this file if that option is selected.
2.  GFS_NOAA\_{race id}\_{grib_time}\_0p25.grb2. This is the raw 0.25 degree data for the first 192 hours, downloaded from NOAA and stored in the grib\NOAA folder. e.g. GFS_NOAA_1820_2024070218_0p25.grb2
3.  GFS_NOAA\_{race id}\_{grib_time}\_1p00.grb2. This is the raw 1 degree data for hours 192 to 384, in the grib\NOAA folder.
4.  CFS_NOAA\_{race id}\_{cfs_cycle_time}\_1p00.grb2. Members only. This is the CFS data, one file for each CFS cycle, in the grib\NOAA folder.

Note that the A grib can be loaded and used as it is created, so there is no need to wait for the NOAA download to complete. It will only contain the frames up to the last frame downloaded. For more frames, look at [current_grib.grb](#731-current_gribgrb).

### 7.3.1 current_grib.grb

AGL also keeps one more file in the grib folder, **current_grib.grb** (GRIB1 format). It is a snapshot of the Wx that AGL has in memory at that moment, and it is rewritten every time something new arrives: a new SOL grib, or each NOAA (or CFS) frame as it is downloaded. It holds the SOL grib followed by the NOAA frames and then CFS frames. The 0.25 degree frames occur first, re-interpolated to match the SOL grib resolution and number of frames. After those, the 1 degree NOAA frames and then the CFS frames follow. Wind and pressure are both in it if selected. Frames earlier than the present time are left out.

In memory a new SOL grib replaces the NOAA frames over its own range, but the NOAA frames beyond the end of the SOL grib stay until a newer NOAA cycle replaces them.

For long range routing in qtVlm, load **current_grib.grb** in slot 1. It is always the newest and longest Wx AGL has, so there is no need to pick the right A grib or to reload as the download progresses. When you open Routing settings in qtVlm, AGL checks the first date of the grib qtVlm has loaded and warns you if it is older than the one AGL is using.
