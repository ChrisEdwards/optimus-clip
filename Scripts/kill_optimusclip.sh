#!/usr/bin/env bash
# Kill all OptimusClip processes

pkill -x "OptimusClip" 2>/dev/null || true
sleep 0.2

# Verify killed
if pgrep -x "OptimusClip" > /dev/null; then
    echo "⚠ OptimusClip still running, using SIGKILL"
    pkill -9 -x "OptimusClip" 2>/dev/null || true
fi

echo "✓ OptimusClip stopped"
