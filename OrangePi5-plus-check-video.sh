#!/bin/bash

echo "=== Checking system for video devices ==="
echo "Standard video devices:"
ls -la /dev/video* 2>/dev/null || echo "No standard video devices found"

echo -e "\nMedia devices:"
ls -la /dev/media* 2>/dev/null || echo "No media devices found"

echo -e "\nDRM devices:"
ls -la /dev/dri/* 2>/dev/null || echo "No DRM devices found"

echo -e "\nRockchip specific devices:"
ls -la /dev/rk* 2>/dev/null || echo "No Rockchip specific devices found"

echo -e "\nLoaded kernel modules related to video:"
lsmod | grep -E 'camera|video|media|v4l|rockchip'

echo -e "\nDetecting hardware information:"
echo "Connected video devices:"
v4l2-ctl --list-devices 2>/dev/null || echo "v4l2-ctl not available or no devices found"

echo -e "\n=== If HDMI In module is not loaded, try the following: ==="
echo "sudo modprobe rockchip_hdmirx"
echo "This should load the HDMI input module for Rockchip devices"

inxi -GA
