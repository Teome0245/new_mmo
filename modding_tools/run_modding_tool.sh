#!/bin/bash
# Script pour lancer les outils de modding SWG avec Wine

TOOL_PATH="$1"

if [ -z "$TOOL_PATH" ]; then
    echo "Usage: ./run_modding_tool.sh <chemin_vers_le_fichier.exe>"
    echo "Exemple: ./run_modding_tool.sh SIE/SIE.exe"
    exit 1
fi

if [ ! -f "$TOOL_PATH" ]; then
    echo "Erreur: Le fichier $TOOL_PATH n'existe pas."
    exit 1
fi

echo "Lancement de $TOOL_PATH avec Wine..."

# Utilise le prefix wine par défaut (ou un prefix spécifique si vous le souhaitez)
export WINEPREFIX="$HOME/.wine"

# Lancement
wine "$TOOL_PATH"
