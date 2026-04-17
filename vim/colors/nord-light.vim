" Nord Light (Polar) - vim color scheme
" Light variant of Nord: Snow Storm backgrounds, Polar Night text
set background=light
highlight clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'nord-light'

" Palette
" Snow Storm (backgrounds):  nord4=#D8DEE9  nord5=#E5E9F0  nord6=#ECEFF4
" Polar Night (text):        nord0=#2E3440  nord1=#3B4252  nord2=#434C5E  nord3=#4C566A
" Frost:    nord7=#8FBCBB  nord8=#88C0D0  nord9=#81A1C1  nord10=#5E81AC
" Aurora:   nord11=#BF616A  nord12=#D08770  nord13=#EBCB8B  nord14=#A3BE8C  nord15=#B48EAD

" === Core UI ===
hi Normal          guifg=#2E3440  guibg=#ECEFF4  gui=NONE     ctermfg=NONE  ctermbg=NONE  cterm=NONE
hi Visual          guifg=NONE     guibg=#D8DEE9  gui=NONE
hi Search          guifg=#2E3440  guibg=#EBCB8B  gui=NONE
hi IncSearch       guifg=#2E3440  guibg=#88C0D0  gui=NONE
hi CursorLine      guibg=#E5E9F0  gui=NONE       ctermbg=NONE
hi CursorLineNr    guifg=#5E81AC  guibg=#E5E9F0  gui=bold
hi LineNr          guifg=#D8DEE9  guibg=#ECEFF4  gui=NONE
hi SignColumn      guifg=#D8DEE9  guibg=#ECEFF4  gui=NONE
hi ColorColumn     guibg=#E5E9F0  gui=NONE
hi VertSplit       guifg=#D8DEE9  guibg=#ECEFF4  gui=NONE
hi StatusLine      guifg=#ECEFF4  guibg=#5E81AC  gui=bold
hi StatusLineNC    guifg=#4C566A  guibg=#D8DEE9  gui=NONE
hi WildMenu        guifg=#ECEFF4  guibg=#5E81AC  gui=bold
hi Pmenu           guifg=#2E3440  guibg=#D8DEE9  gui=NONE
hi PmenuSel        guifg=#ECEFF4  guibg=#5E81AC  gui=NONE
hi PmenuSbar       guibg=#D8DEE9  gui=NONE
hi PmenuThumb      guibg=#5E81AC  gui=NONE
hi TabLine         guifg=#4C566A  guibg=#D8DEE9  gui=NONE
hi TabLineSel      guifg=#ECEFF4  guibg=#5E81AC  gui=bold
hi TabLineFill     guibg=#D8DEE9  gui=NONE
hi Folded          guifg=#4C566A  guibg=#E5E9F0  gui=italic
hi FoldColumn      guifg=#4C566A  guibg=#ECEFF4  gui=NONE
hi MatchParen      guifg=#5E81AC  guibg=#D8DEE9  gui=bold
hi NonText         guifg=#D8DEE9  gui=NONE
hi SpecialKey      guifg=#D8DEE9  gui=NONE

" === Messages ===
hi ErrorMsg        guifg=#BF616A  guibg=NONE     gui=bold
hi WarningMsg      guifg=#D08770  guibg=NONE     gui=NONE
hi MoreMsg         guifg=#A3BE8C  guibg=NONE     gui=bold
hi Question        guifg=#A3BE8C  guibg=NONE     gui=bold
hi Title           guifg=#5E81AC  guibg=NONE     gui=bold
hi Directory       guifg=#5E81AC  guibg=NONE     gui=NONE

" === Diffs ===
hi DiffAdd         guifg=#5D7A46  guibg=#E5E9F0  gui=NONE
hi DiffChange      guifg=#8B6914  guibg=#E5E9F0  gui=NONE
hi DiffDelete      guifg=#BF616A  guibg=#E5E9F0  gui=NONE
hi DiffText        guifg=#2E3440  guibg=#EBCB8B  gui=NONE

" === Syntax ===
hi Comment         guifg=#4C566A  gui=italic
hi Constant        guifg=#8A5E8A  gui=NONE
hi String          guifg=#5D7A46  gui=NONE
hi Character       guifg=#5D7A46  gui=NONE
hi Number          guifg=#8A5E8A  gui=NONE
hi Boolean         guifg=#5E81AC  gui=bold
hi Float           guifg=#8A5E8A  gui=NONE
hi Identifier      guifg=#2E3440  gui=NONE
hi Function        guifg=#5E81AC  gui=bold
hi Statement       guifg=#5E81AC  gui=bold
hi Keyword         guifg=#5E81AC  gui=bold
hi Conditional     guifg=#5E81AC  gui=bold
hi Repeat          guifg=#5E81AC  gui=bold
hi Label           guifg=#5E81AC  gui=bold
hi Operator        guifg=#4C566A  gui=NONE
hi Exception       guifg=#BF616A  gui=bold
hi PreProc         guifg=#5E81AC  gui=NONE
hi Include         guifg=#5E81AC  gui=bold
hi Define          guifg=#5E81AC  gui=bold
hi Macro           guifg=#5E81AC  gui=NONE
hi Type            guifg=#4B7A7A  gui=bold
hi StorageClass    guifg=#5E81AC  gui=NONE
hi Structure       guifg=#4B7A7A  gui=NONE
hi Typedef         guifg=#4B7A7A  gui=bold
hi Special         guifg=#D08770  gui=NONE
hi SpecialChar     guifg=#D08770  gui=NONE
hi Tag             guifg=#5E81AC  gui=NONE
hi Delimiter       guifg=#4C566A  gui=NONE
hi SpecialComment  guifg=#4C566A  gui=italic
hi Debug           guifg=#BF616A  gui=NONE
hi Underlined      guifg=#5E81AC  gui=underline
hi Todo            guifg=#ECEFF4  guibg=#5E81AC  gui=bold
hi Error           guifg=#BF616A  guibg=NONE     gui=bold

" === NERDTree ===
hi NERDTreeDir         guifg=#5E81AC  gui=NONE
hi NERDTreeDirSlash    guifg=#5E81AC  gui=NONE
hi NERDTreeFile        guifg=#2E3440  gui=NONE
hi NERDTreeExecFile    guifg=#5D7A46  gui=NONE
hi NERDTreeOpenable    guifg=#81A1C1  gui=NONE
hi NERDTreeClosable    guifg=#81A1C1  gui=NONE
hi NERDTreeCWD         guifg=#D08770  gui=bold
hi NERDTreeHelp        guifg=#4C566A  gui=italic
