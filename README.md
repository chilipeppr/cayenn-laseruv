# cayenn-laseruv
ChiliPeppr Cayenn driver for ESP8266 (NodeMCU) implemented in Lua

This code is for a 3A laser driver that works with ChiliPeppr's Cayenn protocol. It runs on a NodeMCU. It talks back and forth to ChiliPeppr to let commands get uploaded to it, it then watches the Coolant pin on the CNC controller and increments a counter every time it sees it go high, and then executes the relevant command based on the ID of the counter.

The reason to do this via the Coolant pin counter is to enable synchronous execution of commands as the main CNC controller plays back the Gcode. For a laser, this makes a lot of sense to correspond with where the CNC machine has moved, and then to turn the laser on at different power levels based on the pre-uploaded list of commands.

This code assumes you have installed the Lua firmware on your ESP8266 including the i2c, pwm, and ws2812 libraries. The firmware used for this build is located at: https://github.com/chilipeppr/workspace-nodemcu/releases/download/v0.13/nodemcu_integer_chilipeppr_cjson_i2c_pwm_ws2812.bin

The laser.lua file also includes code to toggle a main power relay.

