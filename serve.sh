#!/bin/bash
# Levanta el prototipo en http://127.0.0.1:5173
cd "$(dirname "$0")"
open "http://127.0.0.1:5173/index.html"
python3 -m http.server 5173 --bind 127.0.0.1
