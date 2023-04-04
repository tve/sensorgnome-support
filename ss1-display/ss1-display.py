# SensorStation Software
# Copyright 2007-2019, Cellular Tracking Technologies, LLC, All Rights Reserved
# Copyright 2023 Thorsten von Eicken (porting to python 3 and adpting to SensorGnome)
# Version 1.0

# pip library requirements: inky
import sys

sys.path.append("./inky-phat/library")

# Python library imports
import datetime
import os
import RPi.GPIO as GPIO
import time
import math
import requests
from PIL import Image, ImageFont, ImageDraw
import inkyphat

inkyphat.set_colour("red")
img = Image.new("P", (212, 104))
draw = ImageDraw.Draw(img)

# remove GPIO warnings
GPIO.setwarnings(False)

# Configure ADC
_TLC_CS = 19
_TLC_ADDR = 21
_TLC_CLK = 18
_TLC_DOUT = 20
_TLC_EOC = 16

_ADC_BATTERY = 0
_ADC_SOLAR = 1
_ADC_RTC = 2
_ADC_TEMPERATURE = 3
_ADC_LIGHT = 4
_ADC_AUX_1 = 5
_ADC_AUX_2 = 6
_ADC_AUX_3 = 7
_ADC_AUX_4 = 8
_ADC_AUX_5 = 9
_ADC_AUX_6 = 10
_ADC_CAL_1 = 11
_ADC_CAL_2 = 12
_ADC_CAL_3 = 13
_ADC_VREF = 5.00


# Configure GPIOs

_BUTTON_UP = 4
_BUTTON_DN = 5
_BUTTON_BACK = 7
_BUTTON_SELECT = 6
_DIAG_A = 39
_DIAG_B = 40
_TLC_CS = 19
_TLC_ADDR = 21
_TLC_CLK = 18
_TLC_DOUT = 20
_TLC_EOC = 16


GPIO.setmode(GPIO.BCM)
GPIO.setup(_BUTTON_UP, GPIO.IN)
GPIO.setup(_BUTTON_DN, GPIO.IN)
GPIO.setup(_BUTTON_BACK, GPIO.IN)
GPIO.setup(_BUTTON_SELECT, GPIO.IN)
GPIO.setup(_DIAG_A, GPIO.OUT)
GPIO.setup(_DIAG_B, GPIO.OUT)
GPIO.setup(_TLC_CLK, GPIO.OUT)
GPIO.setup(_TLC_ADDR, GPIO.OUT)
GPIO.setup(_TLC_DOUT, GPIO.IN)
GPIO.setup(_TLC_CS, GPIO.OUT)
GPIO.setup(_TLC_EOC, GPIO.IN)

# ADC functions


def ADC_Read(channel):
    GPIO.output(_TLC_CS, 0)
    value = 0
    for i in range(0, 4):
        if (channel >> (3 - i)) & 0x01:
            GPIO.output(_TLC_ADDR, 1)
        else:
            GPIO.output(_TLC_ADDR, 0)
        GPIO.output(_TLC_CLK, 1)
        GPIO.output(_TLC_CLK, 0)
    for i in range(0, 6):
        GPIO.output(_TLC_CLK, 1)
        GPIO.output(_TLC_CLK, 0)
    GPIO.output(_TLC_CS, 1)
    time.sleep(0.001)
    GPIO.output(_TLC_CS, 0)
    for i in range(0, 10):
        GPIO.output(_TLC_CLK, 1)
        value <<= 1
        if GPIO.input(_TLC_DOUT):
            value |= 0x01
        GPIO.output(_TLC_CLK, 0)
    GPIO.output(_TLC_CS, 1)

    return value


def getVoltage():
    reading = ADC_Read(_ADC_BATTERY)
    voltage = (reading * _ADC_VREF) / 1024
    voltage = voltage / (100000 / (599000))
    return voltage


def getSolarVoltage():
    reading = ADC_Read(_ADC_SOLAR)
    voltage = (reading * _ADC_VREF) / 1024
    voltage = voltage / (100000 / (599000))
    return voltage


def getRTCBatteryVoltage():
    reading = ADC_Read(_ADC_RTC)
    voltage = _ADC_VREF / 1024 * reading
    return voltage


# Thermistor temperature using Steihart-Hart equation
# https://www.allaboutcircuits.com/industry-articles/how-to-obtain-the-temperature-value-from-a-thermistor-measurement/
# Datasheet: https://www.mouser.com/datasheet/2/427/ntclg100-1762699.pdf
def calcCoeff():
    global cfA, cfB, cfC
    k0 = 273.15
    t1 = -40 + k0
    r1 = 3320936  # Ohm at -40C
    t2 = 25 + k0
    r2 = 100000  # Ohm at 25C
    t3 = 125 + k0
    r3 = 3387  # Ohm at 125C
    l1 = math.log(r1)
    l2 = math.log(r2)
    l3 = math.log(r3)
    y2 = (1 / t2 - 1 / t1) / (l2 - l1)
    y3 = (1 / t3 - 1 / t1) / (l3 - l1)
    cfC = ((y3 - y2) / (l3 - l2)) / (l1 + l2 + l3)
    cfB = y2 - cfC * (l1 * l1 + l1 * l2 + l2 * l2)
    cfA = (1 / t1) - (cfB + cfC * l1 * l1) * l1
    # print("cfA: "+str(cfA)+" cfB: "+str(cfB)+" cfC: "+str(cfC))
    # for r in [3320936, 100000, 3387]:
    #     lr = math.log(r)
    #     print("r: "+str(r)+" -> "+str(1/(cfA + cfB*lr + cfC*lr*lr*lr)-273.15))


calcCoeff()


def getTemperature():
    reading = ADC_Read(_ADC_TEMPERATURE)
    # print("reading: "+str(reading))
    voltage = (reading * _ADC_VREF) / 1024
    resistance = (voltage * 100000) / (3.3 - voltage)
    logR2 = math.log(resistance)
    temperature = 1.0 / (cfA + cfB * logR2 + cfC * logR2 * logR2 * logR2)
    temperature = temperature - 273.15
    # print(str(round(voltage,2))+"V -> "+str(round(resistance))+"Ohm -> "+str(round(temperature))+"C")
    return temperature


def getWifiStatus():
    result = os.popen("wpa_cli -i wlan0 status | grep wpa_state").read()
    state = result.split("=")[1].strip()
    print("Wifi state: " + state)
    if state == "COMPLETED":
        return "ON"
    if state == "INACTIVE":
        return "OFF"
    return "oOo"


def getHotSpotStatus():
    state = os.popen("ip link show ap0 | grep -Po 'state \K\S+'").read()
    print("Hotspot state: " + state.strip())
    if state == "UP":
        return "ON"
    if state == "DOWN":
        return "OFF"
    return "N/A"


# make an http request to sg-control to get upload/files info
def getFiles():
    try:
        response = requests.get("http://localhost:8080/monitoring", timeout=5)
        info = response.json()
        # print("sg-control info: "+str(info))
        up = info["uploads"]["result"]["status"]
        if up != "OK":
            up = "ERR"
        dl = info["files"]["summary"]["files_to_download"]
        return (up, dl)
    except:
        print("Error getting sg-control info: " + str(sys.exc_info()[0]))
        return ("??", "??")


# read the software version file
def getVersion():
    try:
        with open("/etc/sensorgnome/version", "r") as f:
            return f.read().strip()
    except:
        print("Error reading version file: " + str(sys.exc_info()[0]))
        return "???"

sg_version = getVersion()

# file = 0
# if file == 1:
#   if GPIO.input(_BUTTON_UP) == 0:
#      print("Up")
#      GPIO.output(_DIAG_A,1)
#   if GPIO.input(_BUTTON_DN) == 0:
#      print("Down")
#      GPIO.output(_DIAG_B,1)
#   if GPIO.input(_BUTTON_BACK) == 0:
#      print("Back")
#      GPIO.output(_DIAG_A,1)
#   if GPIO.input(_BUTTON_SELECT) == 0:
#      print("Select")
#      GPIO.output(_DIAG_B_1)


font_small = ImageFont.truetype(inkyphat.fonts.FredokaOne, 14)
font_large = ImageFont.truetype(inkyphat.fonts.AmaticSCBold, 24)
font_mega = ImageFont.truetype(inkyphat.fonts.AmaticSCBold, 36)
font_fixed = ImageFont.truetype(inkyphat.fonts.PressStart2P, 9)


def displayWelcome():
    draw.rectangle(((0, 38), (212, 72)), fill=2)
    draw.text((80, -4), "Motus", 2, font=font_mega)
    draw.text((40, 32), "Sensorgnome", 0, font=font_mega)
    draw.text((25, 72), "On CTT SensorStation V1", 1, font=font_large)
    inkyphat.set_image(img)
    inkyphat.show()


def displayHandler():
    while 1:
        draw.rectangle(((0, 0), (212, 20)), fill=1)
        draw.rectangle(((0, 20), (212, 84)), fill=0)
        draw.rectangle(((0, 84), (212, 104)), fill=1)
        draw.line(((106, 20), (106, 84)), fill=1)
        draw.text((4, 2), "SG-FC32RPI3EE0F ("+sg_version+")", 0, font_small)
        # battery
        batt = getVoltage()
        if batt < 11.3:
            color = 2
        else:
            color = 1
        draw.text((4, 25), "Bat   " + str(round(batt, 1)) + "V", color, font_fixed)
        # solar
        solar = getSolarVoltage()
        if solar < 12:
            color = 2
        else:
            color = 1
        draw.text((4, 40), "Solar " + str(round(solar, 1)) + "V", color, font_fixed)
        # rtc battery
        rtc = 3.0
        if rtc < 2.6:
            color = 2
        else:
            color = 1
        draw.text((4, 55), "RTC   " + str(round(rtc, 1)) + "V", color, font_fixed)
        # temperature
        temp = getTemperature()
        if temp > 60:
            color = 2
        else:
            color = 1
        # draw.text((4,70),"Temp  "+str(round(temp))+"C", color, font_fixed)
        # disk usage
        result = os.popen("df -h | grep /data").read()
        disk = result.split("%")[0].split("  ")[-1]
        if int(disk) >= 80:
            color = 2
        else:
            color = 1
        draw.text((4, 70), "Disk  " + disk + "%", color, font_fixed)
        # wifi
        wifi = getWifiStatus()
        if wifi == "ON":
            color = 2
        else:
            color = 1
        draw.text((112, 25), "WiFi", 1, font_fixed)
        draw.text((184, 25), wifi, color, font_fixed)
        # hotspot
        hotspot = getHotSpotStatus()
        if hotspot == "ON":
            color = 2
        else:
            color = 1
        draw.text((112, 40), "HotSpot", 1, font_fixed)
        draw.text((184, 40), hotspot, color, font_fixed)
        # last upload
        (up, dl) = getFiles()
        if up == "OK":
            color = 1
        else:
            color = 2
        draw.text((112, 55), "Upload", 1, font_fixed)
        draw.text((184, 55), up, color, font_fixed)
        # files to download
        draw.text((112, 70), "Files", 1, font_fixed)
        dl = str(dl)
        draw.text((210 - len(dl) * 9, 70), str(dl), 1, font_fixed)
        # current time
        draw.rectangle(((0, 84), (212, 104)), fill=1)
        now = datetime.datetime.now().isoformat(" ", "seconds")
        draw.text((20, 86), now + " UTC", 0, font_small)
        #
        inkyphat.set_image(img)
        inkyphat.show()
        time.sleep(120)


# displayWelcome()
print("Panel version: " + str(inkyphat.get_version()))
print("Battery Voltage: " + str(getVoltage()))
print("Solar Voltage: " + str(getSolarVoltage()))
print("RTC Voltage: " + str(getRTCBatteryVoltage()))
print("Temperature: " + str(getTemperature()))
# time.sleep(10)
displayHandler()
