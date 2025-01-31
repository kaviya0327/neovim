local helpers = require('test.functional.helpers')(after_each)
local lsp_helpers = require('test.functional.plugin.lsp.helpers')
local Screen = require('test.functional.ui.screen')

local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local insert = helpers.insert

local clear_notrace = lsp_helpers.clear_notrace
local create_server_definition = lsp_helpers.create_server_definition

before_each(function()
  clear_notrace()
end)

after_each(function()
  exec_lua("vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })")
end)

describe('inlay hints', function()
  local screen
  before_each(function()
    screen = Screen.new(50, 9)
    screen:attach()
  end)

  describe('general', function()
    local text = dedent([[
    auto add(int a, int b) { return a + b; }

    int main() {
        int x = 1;
        int y = 2;
        return add(x,y);
    }
    }]])


    local response = [==[
    [
    {"kind":1,"paddingLeft":false,"label":"-> int","position":{"character":22,"line":0},"paddingRight":false},
    {"kind":2,"paddingLeft":false,"label":"a:","position":{"character":15,"line":5},"paddingRight":true},
    {"kind":2,"paddingLeft":false,"label":"b:","position":{"character":17,"line":5},"paddingRight":true}
    ]
    ]==]


    before_each(function()
      exec_lua(create_server_definition)
      exec_lua([[
        local response = ...
        server = _create_server({
          capabilities = {
            inlayHintProvider = true,
          },
          handlers = {
            ['textDocument/inlayHint'] = function()
              return vim.json.decode(response)
            end,
          }
        })
      ]], response)
    end)

    it(
      'inlay hints are applied when vim.lsp._inlay_hint.refresh() is called',
      function()
        exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

        insert(text)
        exec_lua([[vim.lsp._inlay_hint.refresh({bufnr = bufnr})]])
        screen:expect({
          grid = [[
  auto add(int a, int b)-> int { return a + b; }    |
                                                    |
  int main() {                                      |
      int x = 1;                                    |
      int y = 2;                                    |
      return add(a: x,b: y);                        |
  }                                                 |
  ^}                                                 |
                                                    |
]]
        })
      end)

    it(
      'inlay hints are cleared when vim.lsp._inlay_hint.clear() is called',
      function()
        exec_lua([[
        bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_buf(0, bufnr)
        client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
      ]])

        insert(text)
        exec_lua([[vim.lsp._inlay_hint.refresh({bufnr = bufnr})]])
        screen:expect({
          grid = [[
  auto add(int a, int b)-> int { return a + b; }    |
                                                    |
  int main() {                                      |
      int x = 1;                                    |
      int y = 2;                                    |
      return add(a: x,b: y);                        |
  }                                                 |
  ^}                                                 |
                                                    |
]]
        })
        exec_lua([[vim.lsp._inlay_hint.clear()]])
        screen:expect({
          grid = [[
  auto add(int a, int b) { return a + b; }          |
                                                    |
  int main() {                                      |
      int x = 1;                                    |
      int y = 2;                                    |
      return add(x,y);                              |
  }                                                 |
  ^}                                                 |
                                                    |
]],
          unchanged = true
        })
      end)
  end)
end)
