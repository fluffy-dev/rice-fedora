" Language servers for Python and TypeScript through Neovim's own vim.lsp.
"
" nvim-lspconfig only contributes the server definitions under lsp/; its Lua
" module is never loaded. A server is enabled only when its binary is on PATH, so
" a missing one stays quiet instead of failing on every file it would serve.
"
" On save, ruff and biome organise imports and then format, and nothing else
" formats: the TypeScript servers advertise formatting too and would otherwise
" format the buffer a second time. TypeScript 7's native tsc serves TypeScript
" unless the project pins an older TypeScript in node_modules, which only ts_ls
" can load; tsc needs a fraction of ts_ls's memory. biome attaches only where a
" biome.json or biome.jsonc exists, not merely because package.json lists it, so
" it never reformats a project that has not opted in. Diagnostics colour the line
" number and leave the sign column to git hunks.

lua << EOF
local severity = vim.diagnostic.severity

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { current_line = true },
  float = { source = 'if_many' },
  signs = {
    text = { [severity.ERROR] = '', [severity.WARN] = '', [severity.INFO] = '', [severity.HINT] = '' },
    numhl = {
      [severity.ERROR] = 'DiagnosticSignError',
      [severity.WARN] = 'DiagnosticSignWarn',
      [severity.INFO] = 'DiagnosticSignInfo',
      [severity.HINT] = 'DiagnosticSignHint',
    },
  },
})

vim.lsp.config('basedpyright', {
  settings = {
    basedpyright = {
      disableOrganizeImports = true,
      analysis = { typeCheckingMode = 'standard' },
    },
  },
})
-- One tsserver and no typings installer: ts_ls otherwise runs three Node processes.
vim.lsp.config('ts_ls', {
  init_options = {
    disableAutomaticTypingAcquisition = true,
    tsserver = { useSyntaxServer = 'never' },
  },
})

--- Major version of the TypeScript installed in a project's node_modules, if any.
local function typescript_major(root)
  local ok, manifest = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(root .. '/node_modules/typescript/package.json'), '\n'))
  end)
  local version = ok and type(manifest) == 'table' and manifest.version
  return type(version) == 'string' and tonumber(version:match('^(%d+)%.')) or nil
end

--- Narrows a server's upstream root detection to the roots that accepts(bufnr, root) approves.
local function restrict_root(name, accepts)
  local root_dir = vim.lsp.config[name] and vim.lsp.config[name].root_dir
  if type(root_dir) ~= 'function' then
    return
  end
  vim.lsp.config(name, {
    root_dir = function(bufnr, on_dir)
      root_dir(bufnr, function(root)
        if accepts(bufnr, root) then
          on_dir(root)
        end
      end)
    end,
  })
end

--- True when a biome.json or biome.jsonc sits between the buffer's file and its project root.
local function has_biome_config(bufnr, root)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == '' then
    return false
  end
  return vim.fs.find({ 'biome.json', 'biome.jsonc' }, {
    path = vim.fs.dirname(filename),
    upward = true,
    type = 'file',
    limit = 1,
    stop = vim.fs.dirname(root),
  })[1] ~= nil
end

restrict_root('tsc', function(_, root)
  local major = typescript_major(root)
  return major == nil or major >= 7
end)
restrict_root('ts_ls', function(_, root)
  local major = typescript_major(root)
  return major ~= nil and major < 7
end)
restrict_root('biome', has_biome_config)

local servers = {
  basedpyright = 'basedpyright-langserver',
  ruff = 'ruff',
  tsc = 'tsc',
  ts_ls = 'typescript-language-server',
  biome = 'biome',
}
for name, binary in pairs(servers) do
  if vim.fn.executable(binary) == 1 and vim.lsp.config[name] then
    vim.lsp.enable(name)
  end
end

local formatters = { ruff = true, biome = true }

--- Applies the named server's source.organizeImports action to the whole buffer.
---
--- The action is requested for the full range and resolved when it arrives
--- without an edit: biome answers a cursor range with nothing and defers its edit.
local function organize_imports(bufnr, server)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
  if not client then
    return
  end
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = vim.api.nvim_buf_line_count(bufnr), character = 0 },
    },
    context = { only = { 'source.organizeImports.' .. server }, diagnostics = {} },
  }
  local response = client:request_sync('textDocument/codeAction', params, 1000, bufnr)
  local actions = response and type(response.result) == 'table' and response.result or {}
  for _, action in ipairs(actions) do
    if not action.edit and client:supports_method('codeAction/resolve') then
      local resolved = client:request_sync('codeAction/resolve', action, 1000, bufnr)
      action = resolved and type(resolved.result) == 'table' and resolved.result or action
    end
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
  end
end

--- True when a client should format: ruff and biome always, others only when neither is attached.
local function may_format(client, bufnr)
  if formatters[client.name] then
    return true
  end
  for _, other in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if formatters[other.name] then
      return false
    end
  end
  return true
end

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('rice.lsp', {}),
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client.name == 'ruff' then
      client.server_capabilities.hoverProvider = false
    end
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
    end
    if client:supports_method('textDocument/definition') then
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = ev.buf, desc = 'Go to definition' })
    end
    if formatters[client.name] then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('rice.lsp.format.' .. ev.buf, {}),
        buffer = ev.buf,
        callback = function()
          if vim.b[ev.buf].format_on_save == false then
            return
          end
          organize_imports(ev.buf, client.name)
          vim.lsp.buf.format({
            bufnr = ev.buf,
            timeout_ms = 2000,
            filter = function(c) return formatters[c.name] == true end,
          })
        end,
      })
    end
  end,
})

local function map(lhs, rhs, desc)
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

map('<leader>lf', function()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.buf.format({ async = true, filter = function(c) return may_format(c, bufnr) end })
end, 'Format buffer')
map('<leader>lF', function()
  vim.b.format_on_save = vim.b.format_on_save == false
  vim.notify('format on save ' .. (vim.b.format_on_save and 'on' or 'off') .. ' for this buffer')
end, 'Toggle format on save')
map('<leader>lh', function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, 'Toggle inlay hints')
map('<leader>lv', function()
  local lines = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = lines, virtual_text = not lines and { current_line = true } })
end, 'Toggle diagnostics as virtual lines')
map('<leader>ld', vim.diagnostic.setloclist, 'Diagnostics to location list')
map('<leader>lr', '<Cmd>lsp restart<CR>', 'Restart language servers')
EOF
