{pkgs}: {
  config = ''
    if &shell =~# 'fish$'
        set shell=${pkgs.bash}/bin/bash
    endif

    let mapleader = ','

    if has('nvim')
      set guicursor=n-v-c:block-Cursor/lCursor-blinkon0,i-ci:ver25-Cursor/lCursor,r-cr:hor20-Cursor/lCursor
      set inccommand=nosplit
      noremap <C-q> :confirm qall<CR>
    endif

    " Section General {{{

    " Abbreviations
    abbr funciton function
    abbr teh the
    abbr tempalte template
    abbr fitler filter
    abbr fialed failed
    abbr fial fail

    set nocompatible            " not compatible with vi
    set autoread                " detect when a file is changed

    set history=1000            " change history to 1000
    set textwidth=120

    " }}}

    " Section User Interface {{{

    if !has('gui_running')
        set t_ut=256
    endif
    " if (match($TERM, "-256color") != -1) && (match($TERM, "screen-256color") == -1)
    "   " screen does not, yet, support truecolor
    "   set termguicolors
    " endif

    syntax on
    colorscheme onedark " Set the colorscheme
    set background=dark

    " function! CocCurrentFunction()
    "   return get(b:, 'coc_current_fuction', "")
    " endfunction

    let g:lightline = {
          \ 'active': {
          \   'left': [ [ 'mode', 'paste' ],
          \             [ 'cocstatus', 'currentfunction', 'gitbranch', 'readonly', 'filename', 'modified' ] ]
          \ },
          \ 'component_function': {
          \   'cocstatus': 'coc#status',
          \   'cocfunction': 'CocCurrentFunction',
          \   'filename': 'LightlineFilename',
          \   'gitbranch': 'FugitiveHead',
          \ },
    \ }

    function! LightlineFilename()
      return expand('%:t') !=# "" ? @% : '[No Name]'
    endfunction

    if executable('ag')
        set grepprg=ag\ --nogroup\ --nocolor
    endif
    if executable('rg')
        set grepprg=rg\ --no-heading\ --vimgrep\ --smart-case\ --glob="\!vendor" 
        set grepformat=%f:%l:%c:%m
    endif

    nnoremap <silent> K :call <SID>show_documentation()<cr>
    " nmap <silent> gy <Plug>(coc-type-definition)
    " nmap <silent> gi <Plug>(coc-implementation)
    " nmap <silent> gr <Plug>(coc-references)
    " nmap <leader>ar <Plug>(coc-rename)
    inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<cr>"
    " nmap <silent> [g <Plug>(coc-diagnostic-prev)
    " nmap <silent> ]g <Plug>(coc-diagnostic-next)

    " Highlight symbol under cursor on CursorHold
    " autocmd CursorHold * silent call CocActionAsync('highlight')

    function! s:show_documentation()
      if (index(['vim','help'], &filetype) >= 0)
        exectue 'h '.expand('<cword>')
      else
        " call CocAction('doHover')
      endif
    endfunction

    "" Completion
    " let g:deoplete#enable_at_startup = 1
    " autocmd BufEnter * call ncm2#enable_for_buffer()
    set completeopt=menu,menuone,preview,noselect,noinsert " completion window

    " tab to select
    " and don't hijack my enter key
    " inoremap <expr><Tab> (pumvisible()?(empty(v:completed_item)?"\<C-n>":"\<C-y>"):"\<Tab>")
    " inoremap <expr><CR> (pumvisible()?(empty(v:completed_item)?"\<CR>\<CR>":"\<C-y>"):"\<CR>")

    " rust
    let g:rustfmt_command = "rustfmt"
    let g:rustfmt_autosave = 1
    let g:rustfmt_emit_files = 1
    let g:rustfmt_fail_silently = 0
    let g:rust_clip_command = '${pkgs.xclip}/bin/xclip -selection clipboard'

    " golang
    autocmd BufWritePre *.go lua vim.lsp.buf.format()

    " terraform
    let g:terraform_fmt_on_save=1
    autocmd BufWritePre *.tf lua vim.lsp.buf.format()
    autocmd BufWritePre *.tfvars lua vim.lsp.buf.format()

    filetype plugin indent on
    set autoindent
    set timeoutlen=300 " http://stackoverflow.com/questions/2158516/delay-before-o-opens-a-new-line
    set encoding=utf8
    set scrolloff=3
    set noshowmode
    set hidden
    set nowrap
    set nojoinspaces
    " Always draw sign column. Prevent buffer moving when adding/deleting sign.
    set signcolumn=yes
    let g:sneak#s_next = 1

    " Sane splits
    set splitright
    set splitbelow

    " Tab control
    set shiftwidth=2
    set softtabstop=4
    set tabstop=4
    set noexpandtab

    " Wrapping options
    set formatoptions=tc " wrap text and comments using textwidth
    set formatoptions+=r " continue comments when pressing ENTER in I mode
    set formatoptions+=q " enable formatting of comments with gq
    set formatoptions+=n " detect lists for formatting
    set formatoptions+=b " auto-wrap in insert mode, and do not wrap old long lines

    " Proper search
    set incsearch
    set ignorecase
    set smartcase
    set gdefault

    " Search results centered please
    nnoremap <silent> n nzz
    nnoremap <silent> N Nzz
    nnoremap <silent> * *zz
    nnoremap <silent> # #zz
    nnoremap <silent> g* g*zz

    " Very magic by default
    nnoremap ? ?\v
    nnoremap / /\v
    cnoremap %s/ %sm/

    " GUI settings
    set guioptions-=T " Remove toolbar
    set vb t_vb= " No more beeps
    set backspace=2 " Backspace over newlines
    set nofoldenable
    set ruler " Where am I?
    set ttyfast
    " https://github.com/vim/vim/issues/1735#issuecomment-383353563
    set lazyredraw
    set synmaxcol=500
    set laststatus=2
    set wildmode=list:longest,full   " complete files like a shell
    set relativenumber " Relative line numbers
    set number " Also show current absolute line
    set diffopt+=iwhite " No whitespace in vimdiff
    " Make diffing better: https://vimways.org/2018/the-power-of-diff/
    set diffopt+=algorithm:patience
    set diffopt+=indent-heuristic
    set colorcolumn=80 " and give me a colored column
    set showcmd " Show (partial) command in status line.
    set mouse=a " Enable mouse usage (all modes) in terminals
    set shortmess+=c " don't give |ins-completion-menu| messages.

    " Show those damn hidden characters
    set list
    " Verbose: set listchars=nbsp:¬,eol:¶,extends:»,precedes:«,trail:•
    set listchars=tab:→\ ,nbsp:¬,extends:»,precedes:«,trail:•,eol:¬
    set showbreak=↪

    " Highlight conflicts
    match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'

    " directory settings
    call system('mkdir -vp ~/.backup/undo/ > /dev/null 2>&1')
    set backupdir=~/.backup,.       " list of directories for the backup file
    set directory=~/.backup,~/tmp,. " list of directory names for the swap file
    set nobackup            " do not write backup files
    set backupskip+=~/tmp/*,/private/tmp/* " skip backups on OSX temp dir, for crontab -e to properly work
    set noswapfile          " do not write .swp files
    set undofile
    set undodir=~/.backup/undo/,~/tmp,.

    " =============================================================================
    " # Keyboard shortcuts
    " =============================================================================

    map H ^
    map L $

    " <leader>s for Rg search
    noremap <leader>s :Rg 
    let g:fzf_layout = { 'down': '~20%' }
    command! -bang -nargs=* Rg
      \ call fzf#vim#grep(
      \   'rg --smart-case --column --line-number --no-heading --color=always '.shellescape(<q-args>), 1,
      \   <bang>0 ? fzf#vim#with_preview('up:60%')
      \           : fzf#vim#with_preview('right:50%:hidden', '?'),
      \   <bang>0)

    function! s:list_cmd()
      let base = fnamemodify(expand('%'), ':h:.:S')
      return base == '.' ? 'fd --type file --follow' : printf('fd --type file --follow | proximity-sort %s', shellescape(expand('%')))
    endfunction

    command! -bang -nargs=? -complete=dir Files
      \ call fzf#vim#files(<q-args>, {'source': s:list_cmd(),
      \                               'options': '--tiebreak=index'}, <bang>0)


    if isdirectory(".git")
        " if in a git project, use :GFiles
        nmap <silent> <leader>t :GFiles<cr>
    else
        " otherwise, use :FZF
        nmap <silent> <leader>t :FZF<cr>
    endif

    " No arrow keys --- force yourself to use the home row
    nnoremap <up> <nop>
    nnoremap <down> <nop>
    inoremap <up> <nop>
    inoremap <down> <nop>
    inoremap <left> <nop>
    inoremap <right> <nop>

    " Left and right can switch buffers
    nnoremap <left> :bg<cr>
    nnoremap <right> :bn<cr>

    " Move by line
    nnoremap <silent> j gj
    nnoremap <silent> k gk
    nnoremap <silent> ^ g^
    nnoremap <silent> $ g$

    " Jump to next/previous error
    nmap <silent> <C-k> <Plug>(ale_previous_wrap)
    nmap <silent> <C-j> <Plug>(ale_next_wrap)
    nmap <silent> L <Plug>(ale_lint)
    nmap <silent> <C-l> <Plug>(ale_detail)
    nmap <silent> <C-g> :close<cr>

    " <leader>. toggles between buffers
    nnoremap <leader>. <c-^>

    " clear highlight search
    noremap <space> :set hlsearch! hlsearch?<cr>

    " Remove extra whitespace
    nmap <leader><space> :%s/\s\+$<cr>

    " toggle cursor line
    nnoremap <leader>i :set cursorline!<cr>

    " search for word under cursor
    nnoremap <leader>/ "fyiw :/<c-r>f<cr>

    " Fugitive
    nmap <silent> <leader>gs :Gstatus<cr>
    nmap <silent> <leader>gb :Gblame<cr>

    imap <C-k> <Plug>(neosnippet_expand_or_jump)
    smap <C-k> <Plug>(neosnippet_expand_or_jump)
    xmap <C-k> <Plug>(neosnippet_expand_target)

    " =============================================================================
    " # Autocommands
    " =============================================================================

    " Prevent accidental writes to buffers that shouldn't be edited
    autocmd BufRead *.orig set readonly
    autocmd BufRead *.pacnew set readonly

    " Leave paste mode when leaving insert mode
    autocmd InsertLeave * set nopaste

    " Jump to last edit position on opening file
    if has("autocmd")
      " https://stackoverflow.com/questions/31449496/vim-ignore-specifc-file-in-autocommand
      au BufReadPost * if expand('%:p') !~# '\m/\.git/' && line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
    endif

    " Auto-make less files on save
    autocmd BufWritePost *.less if filereadable("Makefile") | make | endif

    " Follow Rust code style rules
    " au Filetype rust source ~/.config/nvim/scripts/rust-spacetab.vim
    au Filetype rust set colorcolumn=100

    " Go
    au FileType go setl tabstop=4
    au FileType go setl shiftwidth=4
    au FileType go setl noexpandtab
    au FileType go set colorcolumn=

    " Typescript
    au BufNewFile,BufRead *.tsx,*.jsx set filetype=typescript.tsx
    au FileType typescript.tsx,typescript set tabstop=2
    au FileType typescript.tsx,typescript set shiftwidth=2
    au FileType typescript.tsx,typescript set expandtab
    " au FileType typescript.tsx,typescript,json setl formatexpr=CocAction('formatSelected')
    " au User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')

    " Vue
    au FileType vue set tabstop=2
    au FileType vue set shiftwidth=2
    au FileType vue set expandtab

    " protobuf
    au FileType proto set tabstop=2
    au FileType proto set shiftwidth=2
    au FileType proto set expandtab

    " Help filetype detection
    autocmd BufRead *.md set filetype=markdown

    " Treesitter
    lua <<EOF
    require'nvim-treesitter.configs'.setup {
      highlight = {
        enable = true,
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "gnn",
          node_incremental = "grn",
          scope_incremental = "grc",
          node_decremental = "grm",
        },
      },
      indent = {
        enable = true,
      },
      vim.treesitter.language.register('markdown', 'neoai-output'),
    }
    EOF

    lua <<EOF
    local lspconfig = require('lspconfig')

    local sign = function(opts)
      vim.fn.sign_define(opts.name, {
        texthl = opts.name,
        text = opts.text,
        numhl = ''\''
      })
    end

    sign({name = 'DiagnosticSignError', text = ''})
    sign({name = 'DiagnosticSignWarn', text = ''})
    sign({name = 'DiagnosticSignHint', text = ''})
    sign({name = 'DiagnosticSignInfo', text = ''})

    vim.diagnostic.config({
      virtual_text = false,
      signs = true,
        update_in_insert = true,
        underline = true,
        severity_sort = false,
        float = {
            border = 'rounded',
            source = 'always',
            header = ''\'',
            prefix = ''\'',
        },
    })

    vim.cmd([[
    set signcolumn=yes
    autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
    ]])

    vim.opt.completeopt = {'menuone', 'noselect', 'noinsert'}
    vim.opt.shortmess = vim.opt.shortmess + { c = true}
    vim.api.nvim_set_option('updatetime', 300)

    vim.cmd([[
    set signcolumn=yes
    autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
    ]])

    local cmp = require'cmp'
    cmp.setup({
      -- Enable LSP snippets
      snippet = {
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
        end,
      },
      mapping = {
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-n>'] = cmp.mapping.select_next_item(),
        -- Add tab support
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
      },
      -- Installed sources:
      sources = {
        { name = 'path' },                              -- file paths
        { name = 'nvim_lsp', keyword_length = 3 },      -- from language server
        { name = 'nvim_lsp_signature_help'},            -- display function signatures with current parameter emphasized
        { name = 'nvim_lua', keyword_length = 2},       -- complete neovim's Lua runtime API such vim.lsp.*
        { name = 'buffer', keyword_length = 2 },        -- source current buffer
        { name = 'vsnip', keyword_length = 2 },         -- nvim-cmp source for vim-vsnip 
        { name = 'calc'},                               -- source for math calculation
      },
      window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
      },
      formatting = {
          fields = {'menu', 'abbr', 'kind'},
          format = function(entry, item)
              local menu_icon ={
                  nvim_lsp = 'λ',
                  vsnip = '⋗',
                  buffer = 'Ω',
                  path = '🖫',
              }
              item.menu = menu_icon[entry.source.name]
              return item
          end,
      },
    })

    cmp.setup.cmdline(':', {
      sources = cmp.config.sources({
        { name = 'path' }
      })
    })

    local on_attach = function(client, bufnr)
      local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
      local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

      buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

      local opts = { noremap=true, silent=true }

      buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
      buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
      buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
      buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
      buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
      buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
      buf_set_keymap('n', '<space>r', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
      buf_set_keymap('n', '<space>a', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
      buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
      buf_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
      buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
      buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
      buf_set_keymap('n', '<space>q', '<cmd>lua vim.diagnostic.set_loclist()<CR>', opts)
      buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.format()<CR>", opts)

      require "lsp_signature".on_attach({
        doc_lines = 0,
        handler_opts = {
          border = "none"
        },
      })
    end

    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    lspconfig.rust_analyzer.setup {
      on_attach = on_attach,
      flags = {
        debounce_text_changes = 150,
      },
      settings = {
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
          },
          completion = {
            postfix = {
              enable = false,
            },
          },
        },
      },
      capabilities = capabilities,
    }

    lspconfig.gopls.setup {
      cmd = {'${pkgs.gopls}/bin/gopls'},
      on_attach = on_attach,
      flags = {
        debounce_text_changes = 150,
      },
      settings = {
        gopls = {
          experimentalPostfixCompletions = true,
          analyses = {
            unusedparams = true,
            shadow = true,
          },
          staticcheck = true,
        },
      },
      capabilities = capabilities,
    }
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = '*.go',
      callback = function()
        vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } }, apply = true })
      end
    })

    lspconfig.helm_ls.setup {
      cmd = {'${pkgs.helm-ls}/bin/helm_ls', 'serve'},
      on_attach = on_attach,
      capabilities = capabilities,
    }

    lspconfig.nixd.setup {
      cmd = {'${pkgs.nixd}/bin/nixd'},
      on_attach = on_attach,
      capabilities = capabilities,
    }

    lspconfig.terraformls.setup {
      cmd = {'${pkgs.terraform-lsp}/bin/terraform-lsp', 'serve'},
      on_attach = on_attach,
      capabilities = capabilities,
    }
    EOF

    lua <<EOF
    require('neoai').setup{
        -- Below are the default options, feel free to override what you would like changed
        ui = {
            output_popup_text = "NeoAI",
            input_popup_text = "Prompt",
            width = 30,      -- As percentage eg. 30%
            output_popup_height = 80, -- As percentage eg. 80%
            submit = "<Enter>", -- Key binding to submit the prompt
        },
        models = {
            {
                name = "openai",
                model = "gpt-3.5-turbo",
                params = nil,
            },
        },
        register_output = {
            ["g"] = function(output)
                return output
            end,
            ["c"] = require("neoai.utils").extract_code_snippets,
        },
        inject = {
            cutoff_width = 75,
        },
        prompts = {
            context_prompt = function(context)
                return "Hey, I'd like to provide some context for future "
                    .. "messages. Here is the code/text that I want to refer "
                    .. "to in our upcoming conversations:\n\n"
                    .. context
            end,
        },
        mappings = {
            ["select_up"] = "<C-k>",
            ["select_down"] = "<C-j>",
        },
        open_api_key_env = "OPENAI_API_KEY",
        shortcuts = {
            {
                name = "textify",
                key = "<leader>as",
                desc = "fix text with AI",
                use_context = true,
                prompt = [[
                    Please rewrite the text to make it more readable, clear,
                    concise, and fix any grammatical, punctuation, or spelling
                    errors
                ]],
                modes = { "v" },
                strip_function = nil,
            },
            {
                name = "gitcommit",
                key = "<leader>ag",
                desc = "generate git commit message",
                use_context = false,
                prompt = function ()
                    return [[
                        Using the following git diff generate a consise and
                        clear git commit message, with a short title summary
                        that is 75 characters or less:
                    ]] .. vim.fn.system("git diff --cached")
                end,
                modes = { "n" },
                strip_function = nil,
            },
        },
    }
    EOF
  '';
}
