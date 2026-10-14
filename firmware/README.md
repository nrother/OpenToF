# Firmware

This currently targets the [XIAO M24 Sense Board](www.seeedstudio.com/Seeed-XIAO-MG24-Sense-p-6248.html)
See the [Getting Started Guide](https://wiki.seeedstudio.com/xiao_mg24_getting_started/) for development setup instructions.
The firmware is build using the Arduino IDE.

Short version:
- Arduino-Board URL: https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json 
- Protocol Stack "BLE (Arduino)" (not "BLE (Silabs)")
- SeedStdio LSM6DS3 library

## LED status

The board has two LEDs. The firmware (`OpenToF_Firmware/`) only controls the orange **user LED**; the red
**charge LED** is driven by the charger chip.

The app explains the same signals to users under Settings → LED signals
(`app/lib/ui/settings/led_help_screen.dart`, texts in `app/lib/l10n/`). When a signal or timing changes here,
change it there too.

### User LED (orange)

| What you see | Timing | Meaning | What to do |
| --- | --- | --- | --- |
| Slow blinking | 0.3 s on, 0.7 s off, repeating | Awake and waiting for the app to connect. | Connect with the app. |
| On, steady | on all the time | The app is connected. The sensor does not go to sleep in this state. | — |
| 6 quick blinks, then off | 0.15 s on, 0.15 s off, 6 times (1.8 s) | Going to deep sleep now: either no app was connected and no jump was detected for 1 minute (`SLEEP_AFTER_IDLE_MS`), or the app sent the sleep command. | Shake or hit the sensor to wake it up. |
| Off | off all the time | Deep sleep. The sensor checks for motion every 3 s (`SLEEP_POLL_INTERVAL_MS`). | Shake or hit the sensor: it answers within about 4 s. |
| 3 short blinks, then slow blinking | 0.08 s on, 0.08 s off, 3 times (0.5 s) | Woke up from deep sleep because it was moved. | Connect with the app. |
| Fast blinking without stopping | 0.1 s on, 0.1 s off, forever | Start-up failed: either Bluetooth or the motion sensor (IMU) did not start. The sensor does not work and does not sleep. | Press reset or power-cycle. The serial log says which one (`BLE init failed` / `IMU init failed`). |
| On, steady, but the app cannot find the sensor | on all the time | Held awake for flashing: pin D1 was low during a reset. The firmware is not running. | Release D1 and press reset. |

A start by the reset button or by plugging in power has no signal of its own: the LED goes straight to
slow blinking (after about 0.3 s).

The slow blinking can be changed with `LED_WAITING_ON_MS` / `LED_WAITING_OFF_MS` in
`OpenToF_Firmware/config/FirmwareConfig.h`.

### Charge LED (red)

Driven by the charger chip (SGM40567-4.2, about 200 mA charge current) while USB power is connected. It is
the second LED inside the same part as the orange user LED (dual LED D2 on the schematic), so the two sit
right next to each other. The firmware cannot read or change it, and the charging state is not sent to the app.

| What you see | Timing | Meaning |
| --- | --- | --- |
| Short flash about once a second | 0.16 s on, 1.12 s off, repeating | Charging. The last part is slow: it can keep flashing for half an hour or more above 90 %. |
| On, steady, then off | on for about 51 s | Charging finished. |
| Off | off all the time | On USB: usually full (it can start flashing again when the charger tops up). Without USB: always off. |

Source: board schematic (`docs/hardware/XIAO_MGM240S_KICAD_Prj.pdf`) and the SGM40567 data sheet. Only the
flashing has been seen on a real sensor so far; the other two rows are from the data sheet.

### Where this is in the code

- Slow blinking / steady on: `updateStatusLed()` in `OpenToF_Firmware.ino`
- Sleep and wake-up blinks: `sleepWhenIdle()` and `setup()` in `OpenToF_Firmware.ino` (`blinkLed()`)
- Start-up failure: `fatalBlink()` in `OpenToF_Firmware.ino`
- Held awake for flashing: `escape_hatch()` in the Arduino core's `ArduinoLowPower` library
