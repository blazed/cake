$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_SESSION_KEY = (random chars -l 16)
$env.PROMPT_MULTILINE_INDICATOR = (^starship prompt --continuation)

$env.PROMPT_INDICATOR = ""

$env.PROMPT_COMMAND = { ||
    # jobs are not supported
    let width = (term size | get columns | into string)
    ^starship prompt $"--cmd-duration=($env.CMD_DURATION_MS)" $"--status=($env.LAST_EXIT_CODE)" $"--terminal-width=($width)"
}

$env.PROMPT_COMMAND_RIGHT = { || ''}
