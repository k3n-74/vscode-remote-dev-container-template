
# npm run [tab] で補完
# https://blog.leko.jp/post/more-easy-to-use-npm-scripts/

_npm_run_peco() {
    local cur prev cword
    _get_comp_words_by_ref -n : cur prev cword
    if [ "$prev" = "run" ] || [ "$prev" = "yarn" ]; then
        COMPREPLY=$(cat package.json | jq -r '.scripts | keys[]' | peco --initial-filter=Fuzzy --query=$cur)
    fi
}
complete -F _npm_run_peco npm yarn
