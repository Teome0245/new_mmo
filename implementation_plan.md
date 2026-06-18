# Plan de Correction du Lancement du Jeu via le Launchpad Personnalisé

Ce plan décrit les modifications à apporter au launchpad personnalisé (`J:\swgemu\dist` / `launchpad`) pour lui permettre de lancer correctement le jeu `SWGEmu.exe` de manière découplée, et de reconstruire la version finale.

## Problème de fermeture immédiate

Lorsque l'option "Garder en arrière-plan" n'est pas cochée, le launchpad personnalisé appelle `app.quit()` immédiatement après avoir démarré le jeu. Sur Windows, cela ferme prématurément les handles du processus enfant (surtout s'il est exécuté dans un Job Object de package portable), provoquant l'arrêt ou le crash du jeu (`Config file not specified` ou `defaultappearance.apt not found` en cas de répertoire de travail perdu).

**Solution proposée** :
1. Utiliser un démarrage délégué via PowerShell (`Start-Process`) pour détacher totalement le processus du jeu de l'arbre de processus du launcher.
2. Ajouter un délai de 2 secondes avant de fermer le launcher pour s'assurer que le processus Windows est pleinement initialisé.
3. Recompiler le launcher pour mettre à jour l'exécutable dans `J:\swgemu\dist`.

## Proposed Changes

### [launchpad](file:///\\wsl.localhost\Ubuntu\home\sdesh\projects\new_mmo\launchpad)

#### [MODIFY] [main.js](file:///\\wsl.localhost\Ubuntu\home\sdesh\projects\new_mmo\launchpad\main.js)
Modifier la fonction associée à l'événement `launch-game` pour :
- Spécifier le lancement via `Start-Process` de PowerShell pour découpler le jeu du processus Electron parent.
- Ajouter un délai de 2 secondes avant de quitter l'application launcher (`app.quit()`) lorsque `keepOpen` est faux.

Exemple de modification dans [main.js](file:///\\wsl.localhost\Ubuntu\home\sdesh\projects\new_mmo\launchpad\main.js#L210-L227) :
```javascript
  try {
    patchLoginConfig(server);
    
    // Commande PowerShell pour lancer le jeu de manière totalement indépendante avec son dossier de travail
    const psCommand = `Start-Process -FilePath '${gamePath}' -ArgumentList '-s', '${cfgName}' -WorkingDirectory '${config.gameDir}'`;
    const gameProcess = spawn('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psCommand], {
      detached: true,
      stdio: 'ignore'
    });
    gameProcess.unref();

    event.reply('launch-status', {
      error: false,
      message: `Lancement vers ${server.label} (${server.ip}:${server.loginPort})`,
    });

    if (!keepOpen) {
      // Attendre 2 secondes pour laisser le temps au jeu de s'initialiser avant de fermer le launcher
      setTimeout(() => {
        app.quit();
      }, 2000);
    }
  } catch (error) {
    event.reply('launch-status', { error: true, message: error.message });
  }
```

## Verification Plan

### Automated Tests
- Modification de `main.js`.
- Compilation via `npm run build:win` sous WSL.
- Copie/génération du fichier dans `J:\swgemu\dist`.

### Manual Verification
- Démarrer le launchpad personnalisé depuis `J:\swgemu\dist\win-unpacked\LBG Launchpad.exe`.
- Cliquer sur "JOUER" et vérifier que :
  1. Le jeu démarre correctement.
  2. Le launcher se ferme au bout de 2 secondes (si "Garder en arrière-plan" est décoché).
  3. Le jeu reste actif.
  4. L'interface du jeu s'affiche bien en français.
