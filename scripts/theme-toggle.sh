#!/usr/bin/env bash
# Toggle between Nord dark and Nord Light (Polar) across Hyper, tmux, and vim
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
STATE_FILE="$DOTFILES/.theme"
HYPER_JS="$DOTFILES/.hyper.js"

# Determine new theme
current=$(cat "$STATE_FILE" 2>/dev/null || echo "dark")
if [ "$current" = "dark" ]; then
  new="light"
else
  new="dark"
fi

# === Update Hyper ===
python3 - "$HYPER_JS" "$new" <<'PYEOF'
import sys, re

hyper_js = sys.argv[1]
theme    = sys.argv[2]

DARK = """        // <<< THEME_START >>>
        cursorColor: '#88C0D0',
        cursorAccentColor: '#2E3440',
        foregroundColor: '#D8DEE9',
        backgroundColor: '#2E3440',
        selectionColor: 'rgba(136, 192, 208, 0.3)',
        borderColor: '#3B4252',
        colors: {
            black: '#3B4252',
            red: '#BF616A',
            green: '#A3BE8C',
            yellow: '#EBCB8B',
            blue: '#5E81AC',
            magenta: '#B48EAD',
            cyan: '#88C0D0',
            white: '#E5E9F0',
            lightBlack: '#4C566A',
            lightRed: '#BF616A',
            lightGreen: '#A3BE8C',
            lightYellow: '#EBCB8B',
            lightBlue: '#81A1C1',
            lightMagenta: '#B48EAD',
            lightCyan: '#8FBCBB',
            lightWhite: '#ECEFF4',
            limeGreen: '#A3BE8C',
            lightCoral: '#BF616A',
        },
        // <<< THEME_END >>>"""

LIGHT = """        // <<< THEME_START >>>
        cursorColor: '#5E81AC',
        cursorAccentColor: '#ECEFF4',
        foregroundColor: '#2E3440',
        backgroundColor: '#ECEFF4',
        selectionColor: 'rgba(94, 129, 172, 0.3)',
        borderColor: '#D8DEE9',
        colors: {
            black: '#2E3440',
            red: '#BF616A',
            green: '#5D7A46',
            yellow: '#9D6F00',
            blue: '#5E81AC',
            magenta: '#B48EAD',
            cyan: '#4D8A9A',
            white: '#D8DEE9',
            lightBlack: '#4C566A',
            lightRed: '#BF616A',
            lightGreen: '#A3BE8C',
            lightYellow: '#EBCB8B',
            lightBlue: '#81A1C1',
            lightMagenta: '#B48EAD',
            lightCyan: '#88C0D0',
            lightWhite: '#ECEFF4',
            limeGreen: '#A3BE8C',
            lightCoral: '#BF616A',
        },
        // <<< THEME_END >>>"""

with open(hyper_js, 'r') as f:
    content = f.read()

pattern = r'        // <<< THEME_START >>>.*?// <<< THEME_END >>>'
replacement = DARK if theme == 'dark' else LIGHT
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(hyper_js, 'w') as f:
    f.write(new_content)
PYEOF

# === Update tmux (if running) ===
if [ -n "${TMUX:-}" ]; then
  tmux source-file "$DOTFILES/tmux/nord-${new}.tmuxtheme"
fi

# === Update PhpStorm (takes effect on next launch) ===
PHPSTORM_PREFS=$(ls -dt ~/Library/Application\ Support/JetBrains/PhpStorm*/options 2>/dev/null | head -1)
if [ -n "$PHPSTORM_PREFS" ]; then
  if [ "$new" = "light" ]; then
    THEME_ID="6a77f0b6-74e1-4120-b907-2eac86977d6a"
    SCHEME="Polar"
  else
    THEME_ID="1324eea6-b737-4305-8a73-14af69073eae"
    SCHEME="Nord"
  fi
  cat > "$PHPSTORM_PREFS/laf.xml" <<EOF
<application>
  <component name="LafManager">
    <laf themeId="${THEME_ID}" />
    <lafs-to-previous-schemes>
      <laf-to-scheme laf="ExperimentalDark" scheme="_@user_Nord" />
    </lafs-to-previous-schemes>
  </component>
</application>
EOF
  cat > "$PHPSTORM_PREFS/colors.scheme.xml" <<EOF
<application>
  <component name="EditorColorsManagerImpl">
    <global_color_scheme name="${SCHEME}" />
  </component>
</application>
EOF
fi

# === Write new state ===
echo "$new" > "$STATE_FILE"

echo "Switched to Nord ${new}"
