#!/bin/bash
# Publica y apunta los DOS dominios al deploy nuevo.
# El segundo paso hace falta porque los alias se asignaron a mano:
# `vercel --prod` publica pero no los mueve.
#   semillero-de-escrituras.vercel.app  el nombre actual
#   narradores-invisibles.vercel.app    el enlace viejo, que sigue circulando en Discord
set -e
cd "$(dirname "$0")"
URL=$(vercel --prod --yes 2>&1 | grep -o '[a-z0-9-]*\.vercel\.app' | head -1)
echo "deploy: $URL"
vercel alias set "$URL" semillero-de-escrituras.vercel.app >/dev/null
vercel alias set "$URL" narradores-invisibles.vercel.app  >/dev/null
echo "vivo en https://semillero-de-escrituras.vercel.app"
echo "y en   https://narradores-invisibles.vercel.app"
