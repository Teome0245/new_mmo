#!/bin/bash
# Script de création de l'espace de travail pour la traduction SWG (Fichiers TRE/STF)

WORKSPACE_DIR="$HOME/projects/new_mmo/modding_tools/patch_fr_workspace"
TOOLS_DIR="$HOME/projects/new_mmo/modding_tools"

echo "==========================================================="
echo "    Initialisation de l'espace de Traduction SWG"
echo "==========================================================="
echo ""

# 1. Création des dossiers
echo "[1/3] Création de la structure des dossiers..."
mkdir -p "$WORKSPACE_DIR/raw_stf/string/en"
mkdir -p "$WORKSPACE_DIR/translated_stf/string/en"
mkdir -p "$WORKSPACE_DIR/patch_build"
echo "  -> Dossiers créés dans : $WORKSPACE_DIR"

# 2. Vérification des outils (SIE)
echo "[2/3] Vérification des outils de modding..."
if [ ! -f "$TOOLS_DIR/SIE/SIE.exe" ]; then
    echo "  [ATTENTION] Sytner's IFF Editor (SIE.exe) n'a pas été trouvé dans $TOOLS_DIR/SIE/"
    echo "  Pour modifier les fichiers .STF et .TRE, vous devez télécharger SIE :"
    echo "  Lien : https://modthegalaxy.com/index.php?threads/sie-3-7.792/"
    echo "  Une fois téléchargé, extrayez-le dans : $TOOLS_DIR/SIE/"
else
    echo "  -> Sytner's IFF Editor (SIE) trouvé !"
fi

# 3. Création du script d'empaquetage
echo "[3/3] Génération du script d'aide..."

cat << 'EOF' > "$WORKSPACE_DIR/build_patch.sh"
#!/bin/bash
# Ce script prépare votre dossier patch_build pour être transformé en .TRE

WORKSPACE_DIR="$HOME/projects/new_mmo/modding_tools/patch_fr_workspace"
PATCH_NAME="patch_fr_00.tre"

echo "Préparation du patch..."
# Copie des fichiers traduits vers le dossier de build
cp -r "$WORKSPACE_DIR/translated_stf/"* "$WORKSPACE_DIR/patch_build/" 2>/dev/null

echo "Vos fichiers sont prêts dans : $WORKSPACE_DIR/patch_build"
echo "Pour créer le fichier $PATCH_NAME :"
echo "1. Lancez SIE via votre script : ./run_modding_tool.sh SIE/SIE.exe"
echo "2. Dans SIE, allez dans File -> New -> TRE Archive"
echo "3. Glissez-déposez le dossier 'string' depuis $WORKSPACE_DIR/patch_build"
echo "4. Faites File -> Save As -> $PATCH_NAME"
echo "5. Placez ce fichier dans le dossier de votre client SWG !"
EOF

chmod +x "$WORKSPACE_DIR/build_patch.sh"

echo "  -> Script d'aide généré : $WORKSPACE_DIR/build_patch.sh"
echo ""
echo "==========================================================="
echo "  Espace de travail prêt ! Voici votre Workflow :"
echo "==========================================================="
echo "1. Utilisez SIE (via run_modding_tool.sh) pour ouvrir le bottom.tre (ou patch_*.tre) de votre client."
echo "2. Extrayez les fichiers .stf (ex: string/en/ui.stf) dans : $WORKSPACE_DIR/raw_stf/"
echo "3. Ouvrez ces fichiers STF toujours avec SIE pour modifier les textes en français."
echo "4. Sauvegardez les fichiers traduits dans : $WORKSPACE_DIR/translated_stf/"
echo "5. Lancez le script ./patch_fr_workspace/build_patch.sh pour préparer l'archive finale."
echo "==========================================================="
