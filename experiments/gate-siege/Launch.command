#!/bin/zsh
cd "$(dirname "$0")"
if [[ -x .build/Godot.app/Contents/MacOS/Godot ]]; then
  exec .build/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif [[ -x "$HOME/bin/godot" ]]; then
  exec "$HOME/bin/godot" --path "$PWD"
else
  echo 'Open project.godot in Godot 4.7.2 or newer, then press F5.'
  read
fi
