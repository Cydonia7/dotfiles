#!/usr/bin/env python3
"""
A daemon that listens for Bluetooth device connection/disconnection events
and switches the default audio sink using pactl.
"""

import dbus
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess
import time

TARGET_DEVICE_ADDRESS = "C8:7B:23:5C:7C:27"
TARGET_SINK = "bluez_output.C8_7B_23_5C_7C_27.1"
DEFAULT_SINK = "alsa_output.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.analog-stereo"

def sink_exists(sink_name):
    """Return True if the sink exists in the current PulseAudio sinks."""
    try:
        sinks = subprocess.check_output(["pactl", "list", "sinks", "short"]).decode().splitlines()
        return any(sink_name in line for line in sinks)
    except subprocess.CalledProcessError:
        return False

def wait_for_sink(sink_name, timeout=10, interval=0.5):
    """
    Wait until a sink with the given name appears or until timeout.
    Returns True if the sink is found, False if timed out.
    """
    start_time = time.time()
    while time.time() - start_time < timeout:
        if sink_exists(sink_name):
            return True
        time.sleep(interval)
    return False

def switch_sink(sink_name):
    """Switch default sink and move all sink inputs to the new sink."""
    print(f"Switching default sink to {sink_name}...")

    # Wait for the sink to appear before switching.
    if not wait_for_sink(sink_name):
        print(f"Timeout waiting for sink '{sink_name}' to appear. Aborting switch.")
        return

    # Change default sink.
    subprocess.run(["pactl", "set-default-sink", sink_name])
    
    # Move all current sink inputs (audio streams) to the new sink.
    try:
        sink_inputs = subprocess.check_output(["pactl", "list", "sink-inputs", "short"]).decode().splitlines()
        for line in sink_inputs:
            if line.strip():
                sink_input_id = line.split()[0]
                subprocess.run(["pactl", "move-sink-input", sink_input_id, sink_name])
    except subprocess.CalledProcessError:
        print("Could not list sink inputs; perhaps none are active.")
    print("Switch complete.")


def properties_changed(interface, changed, invalidated, path):
    """
    Called whenever any properties change on a DBus object.
    We filter events for org.bluez.Device1 objects and look for changes to "Connected".
    """
    if "Connected" not in changed:
        return  # nothing to do if the connection status didn’t change

    connected = changed["Connected"]
    print(f"Device at {path} changed connected status to {connected}")

    # Get the device properties to check if it is the one we care about.
    bus = dbus.SystemBus()
    device_object = bus.get_object("org.bluez", path)
    props_interface = dbus.Interface(device_object, "org.freedesktop.DBus.Properties")
    try:
        address = props_interface.Get("org.bluez.Device1", "Address")
    except Exception as e:
        print("Error getting device address:", e)
        return

    if address != TARGET_DEVICE_ADDRESS:
        return  # not our device

    if connected:
        # When the headset connects, wait for its sink to appear and then switch to it.
        switch_sink(TARGET_SINK)
    else:
        # When it disconnects, switch back to your default sink.
        switch_sink(DEFAULT_SINK)


def main():
    # Set up the main loop.
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    # Listen for PropertiesChanged signals on devices (BlueZ uses org.bluez.Device1).
    bus.add_signal_receiver(
        properties_changed,
        dbus_interface="org.freedesktop.DBus.Properties",
        signal_name="PropertiesChanged",
        arg0="org.bluez.Device1",
        path_keyword="path"
    )

    print("Bluetooth sink switcher running. Waiting for device events...")
    loop = GLib.MainLoop()
    loop.run()


if __name__ == '__main__':
    main()

