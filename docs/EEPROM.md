# EEPROM Layout

This is the layout of the EEPROM.
If the magic bytes do not match the EEPROM is considred invalid and the default values are used.

| Offset | Size | Description|
|---|---|---|
| 0 | 2 | `0x4F`, `0x53` Magic bytes |
| 2 | 1 | Length of device name (max. 20) |
| 3 | 20 | Device name, UTF-8 |
