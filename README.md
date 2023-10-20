# X4-SimPit 

Simulated Cockpit Telemetry: Get ship telemetry data from X4: Foundations to connect to your home cockpit.

This collects data from X4: Foundations and converts it to a format similar to the well known Elite Dangerous Status as described on https://elite-journal.readthedocs.io/en/latest/Status%20File/ 

The following events are (to some extend) implemented:

* [Status](https://elite-journal.readthedocs.io/en/latest/Status%20File/)
* [Commander](https://elite-journal.readthedocs.io/en/latest/Startup/#commander)
* [Loadout](https://elite-journal.readthedocs.io/en/latest/Startup/#loadout)
* [ShipTargeted](https://elite-journal.readthedocs.io/en/latest/Combat/#shiptargetted)

I wrote this to connect X4: Foundations to my simulated home cockpit (https://SimPit.dev) to bring my status indicators and my Primary Flight Display to live when flying around in my favourite Space Pew Pew sandbox.

![Photo of the "Primary Buffer Panel" home cockpit by BekoPharm](https://beko.famkos.net/wp-content/uploads/2023/10/simpit-x4-foundations-but-battlestar-galactica-maybe.jpg)

Maybe it is of use for others too. Probably not. Anyway here goes.

---
## Requirements

Setting up the required game extension is out of the scope of this but this basically builds on the work of `SirNukes Mod Support APIs` (see https://github.com/bvbohnen/x4-projects/releases). I wrote this for Linux PC though and this requires (for now) my special branch of the `SirNukes Mod Support APIs` extension as described here: https://github.com/bekopharm/x4-projects/wiki/Quick-manual

Windows users can _probably_ just use this but editing the `pipe_external.txt` file may be required. 

**I am looking for testers for both!**

## Installation

Clone this repository to the `game/extensions/` folder.

    $ cd /path/to/X4_Foundations/game/extensions/
    $ git clone https://github.com/bekopharm/x4-simpit

And launch the game. The new extension `Simulated Cockpit Telemetry` should show up in the `Extensions` menu and a (socket|NamedPipe Server) should start (see above) on game launch.

## Deinstallation

Just remove the `x4-simpit` folder from `/path/to/X4_Foundations/game/extensions/` again.

This does not affect game saves so any former saves *should* be fine (the **modified** tag will however not vanish again, of course, but that is from what I can tell not the fault of `x4-simpit`).

## Run X4 for debug/development

Have some ideas how this may look:

> ./X4 -nosoundthrottle -nocputhrottle -skipintro -debug scripts -logfile debuglog.txt -scriptlogfile scriptlog.txt