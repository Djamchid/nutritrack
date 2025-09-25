#!/bin/bash

# Script de déploiement Android pour NutriTrack
# Usage: ./deploy-android.sh

set -e

echo "🚀 Déploiement NutriTrack sur Android"
echo "====================================="

# Configuration
APP_NAME="NutriTrack"
PACKAGE_ID="com.nutritrack.app"
DOMAIN=""
KEYSTORE_PATH="./nutritrack-release.keystore"
KEYSTORE_ALIAS="nutritrack"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les erreurs
error() {
    echo -e "${RED}❌ Erreur: $1${NC}" >&2
    exit 1
}

# Fonction pour afficher les succès
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Fonction pour afficher les infos
info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Vérifier les prérequis
check_requirements() {
    echo "📋 Vérification des prérequis..."
    
    # Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js n'est pas installé. Installez-le depuis https://nodejs.org/"
    fi
    success "Node.js installé: $(node --version)"
    
    # NPM
    if ! command -v npm &> /dev/null; then
        error "NPM n'est pas installé"
    fi
    success "NPM installé: $(npm --version)"
    
    # Java (pour keytool)
    if ! command -v java &> /dev/null; then
        error "Java n'est pas installé. Installez JDK 11 ou supérieur"
    fi
    success "Java installé: $(java --version 2>&1 | head -n 1)"
}

# Créer la structure des dossiers
setup_directories() {
    echo -e "\n📁 Création de la structure..."
    
    mkdir -p icons
    mkdir -p screenshots
    mkdir -p .well-known
    
    success "Dossiers créés"
}

# Générer les icônes
generate_icons() {
    echo -e "\n🎨 Génération des icônes..."
    
    if [ ! -f "logo.png" ]; then
        info "logo.png non trouvé. Création d'un logo par défaut..."
        
        # Créer un logo SVG simple
        cat > logo.svg << 'EOF'
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <rect width="512" height="512" rx="100" fill="#6366f1"/>
  <text x="256" y="320" font-family="Arial" font-size="200" text-anchor="middle" fill="white">🥗</text>
</svg>
EOF
        
        # Convertir en PNG si ImageMagick est installé
        if command -v convert &> /dev/null; then
            convert -background none logo.svg logo.png
            success "Logo créé"
        else
            info "ImageMagick non installé. Utilisez un convertisseur SVG vers PNG en ligne"
        fi
    fi
    
    # Installer et utiliser pwa-asset-generator si logo.png existe
    if [ -f "logo.png" ]; then
        info "Installation de pwa-asset-generator..."
        npm install -g pwa-asset-generator
        
        info "Génération des icônes PWA..."
        npx pwa-asset-generator logo.png ./icons \
            --icon-only \
            --padding "10%" \
            --background "#6366f1" \
            --type png
        
        success "Icônes générées"
    fi
}

# Créer le keystore
create_keystore() {
    echo -e "\n🔐 Création du keystore..."
    
    if [ -f "$KEYSTORE_PATH" ]; then
        info "Keystore existe déjà: $KEYSTORE_PATH"
        return
    fi
    
    echo "Création d'un nouveau keystore..."
    echo "IMPORTANT: Notez bien le mot de passe, il sera nécessaire pour toutes les mises à jour!"
    
    keytool -genkey -v -keystore "$KEYSTORE_PATH" \
        -alias "$KEYSTORE_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=$APP_NAME, OU=Mobile, O=$APP_NAME, L=Paris, C=FR"
    
    success "Keystore créé: $KEYSTORE_PATH"
    
    # Obtenir le SHA256
    echo -e "\n📝 SHA256 Fingerprint:"
    keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEYSTORE_ALIAS" | grep SHA256
    
    info "⚠️  IMPORTANT: Sauvegardez ce keystore en lieu sûr!"
    info "Sans lui, vous ne pourrez plus mettre à jour votre app"
}

# Déployer la PWA
deploy_pwa() {
    echo -e "\n🌐 Déploiement de la PWA..."
    
    # Demander le domaine si non défini
    if [ -z "$DOMAIN" ]; then
        read -p "Entrez votre domaine (ex: nutritrack.netlify.app): " DOMAIN
    fi
    
    # Mettre à jour le manifest.json avec le domaine
    if [ -f "manifest.json" ]; then
        sed -i.bak "s|/index.html|https://$DOMAIN/index.html|g" manifest.json
        success "manifest.json mis à jour"
    fi
    
    # Options de déploiement
    echo -e "\nChoisissez votre méthode de déploiement:"
    echo "1) Netlify"
    echo "2) Vercel"
    echo "3) Firebase"
    echo "4) Manuel (vous déployez vous-même)"
    
    read -p "Votre choix (1-4): " deploy_choice
    
    case $deploy_choice in
        1)
            info "Déploiement sur Netlify..."
            npm install -g netlify-cli
            netlify deploy --prod --dir=. --site-name="nutritrack"
            success "Déployé sur Netlify!"
            ;;
        2)
            info "Déploiement sur Vercel..."
            npm install -g vercel
            vercel --prod
            success "Déployé sur Vercel!"
            ;;
        3)
            info "Déploiement sur Firebase..."
            npm install -g firebase-tools
            firebase init hosting
            firebase deploy
            success "Déployé sur Firebase!"
            ;;
        4)
            info "Déployez manuellement votre PWA sur https://$DOMAIN"
            ;;
        *)
            error "Choix invalide"
            ;;
    esac
}

# Générer l'APK avec Bubblewrap
generate_apk() {
    echo -e "\n📦 Génération de l'APK Android..."
    
    # Installer Bubblewrap
    info "Installation de Bubblewrap..."
    npm install -g @bubblewrap/cli
    
    # Initialiser le projet TWA
    info "Configuration du projet TWA..."
    
    # Créer le fichier de configuration
    cat > twa-manifest.json << EOF
{
  "packageId": "$PACKAGE_ID",
  "host": "$DOMAIN",
  "name": "$APP_NAME",
  "launcherName": "$APP_NAME",
  "display": "standalone",
  "themeColor": "#6366f1",
  "navigationColor": "#6366f1",
  "backgroundColor": "#667eea",
  "startUrl": "https://$DOMAIN",
  "iconUrl": "https://$DOMAIN/icons/icon-512x512.png",
  "maskableIconUrl": "https://$DOMAIN/icons/icon-512x512.png",
  "appVersion": "1.0.0",
  "signingKey": {
    "path": "$KEYSTORE_PATH",
    "alias": "$KEYSTORE_ALIAS"
  },
  "webManifestUrl": "https://$DOMAIN/manifest.json",
  "fallbackType": "customtabs",
  "enableSiteSettingsShortcut": true,
  "isChromeOSOnly": false
}
EOF
    
    # Initialiser avec Bubblewrap
    bubblewrap init --manifest="https://$DOMAIN/manifest.json"
    
    # Construire l'APK
    info "Construction de l'APK..."
    bubblewrap build
    
    success "APK généré avec succès!"
    
    # Localiser l'APK
    APK_PATH=$(find . -name "*.apk" -type f | head -n 1)
    if [ -f "$APK_PATH" ]; then
        success "APK disponible: $APK_PATH"
        
        # Renommer pour plus de clarté
        mv "$APK_PATH" "./nutritrack-v1.0.0.apk"
        success "APK renommé: nutritrack-v1.0.0.apk"
    fi
}

# Créer le package pour PWABuilder (alternative)
create_pwabuilder_package() {
    echo -e "\n📦 Alternative: Package PWABuilder..."
    
    info "Vous pouvez aussi utiliser PWABuilder.com:"
    echo "1. Allez sur https://www.pwabuilder.com/"
    echo "2. Entrez: https://$DOMAIN"
    echo "3. Cliquez sur 'Package for stores'"
    echo "4. Choisissez 'Android'"
    echo "5. Configurez et téléchargez"
}

# Préparer pour Google Play
prepare_play_store() {
    echo -e "\n🎯 Préparation pour Google Play Store..."
    
    # Créer les dossiers de ressources
    mkdir -p play-store/screenshots
    mkdir -p play-store/graphics
    
    # Créer un README pour les assets
    cat > play-store/README.md << 'EOF'
# Assets Google Play Store

## Screenshots requis (minimum 2)
- Format: PNG ou JPEG
- Dimensions: 1080x1920 px minimum
- Placez vos screenshots dans le dossier `screenshots/`

## Graphiques requis
- **Icône**: 512x512 px (PNG)
- **Image de présentation**: 1024x500 px
- **Bannière TV** (optionnel): 1280x720 px

## Textes Store

### Titre (30 caractères max)
NutriTrack - Suivi Nutrition

### Description courte (80 caractères)
Suivez vos macro et micronutriments facilement - Offline & rapide

### Mots-clés
nutrition, macronutriments, calories, régime, santé, fitness, tracker, offline

## Checklist Publication
- [ ] APK/AAB signé
- [ ] Screenshots (min 2, max 8)
- [ ] Icône haute résolution
- [ ] Image de présentation
- [ ] Description complète
- [ ] Politique de confidentialité
- [ ] Classification du contenu
- [ ] Compte développeur actif (25$)
EOF
    
    success "Dossier Play Store préparé"
    info "Consultez play-store/README.md pour les instructions"
}

# Fonction principale
main() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║   NutriTrack - Déploiement Android   ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_requirements
    setup_directories
    
    # Menu principal
    echo -e "\n🎯 Que voulez-vous faire?"
    echo "1) Configuration complète (recommandé pour première fois)"
    echo "2) Générer uniquement les icônes"
    echo "3) Créer uniquement le keystore"
    echo "4) Déployer uniquement la PWA"
    echo "5) Générer uniquement l'APK"
    echo "6) Préparer les assets Play Store"
    
    read -p "Votre choix (1-6): " main_choice
    
    case $main_choice in
        1)
            generate_icons
            create_keystore
            deploy_pwa
            generate_apk
            prepare_play_store
            ;;
        2)
            generate_icons
            ;;
        3)
            create_keystore
            ;;
        4)
            deploy_pwa
            ;;
        5)
            if [ -z "$DOMAIN" ]; then
                read -p "Entrez votre domaine PWA: " DOMAIN
            fi
            generate_apk
            ;;
        6)
            prepare_play_store
            ;;
        *)
            error "Choix invalide"
            ;;
    esac
    
    echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
    success "Processus terminé!"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    
    # Résumé final
    echo -e "\n📋 Prochaines étapes:"
    echo "1. Testez votre PWA sur https://$DOMAIN"
    echo "2. Testez l'APK sur un appareil Android"
    echo "3. Créez votre compte Google Play Console (25$)"
    echo "4. Uploadez l'APK et les assets"
    echo "5. Publiez votre app!"
    
    info "\n💡 Conseil: Gardez une copie de sauvegarde de:"
    echo "   - $KEYSTORE_PATH (TRÈS IMPORTANT!)"
    echo "   - Mot de passe du keystore"
    echo "   - Code source complet"
}

# Lancer le script
main