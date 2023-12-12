local M = {}

function M.setup(config)
  config.yamlls.setup {
    settings = {
      redhat = {
        telemetry = {
          enabled = false,
        },
      },
      yaml = {
        keyOrdering = false,
        schemas = {
          ['https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json'] = 'docker-compose.{yml,yaml}',
          ['http://json.schemastore.org/github-workflow'] = '.github/workflows/*.{yml,yaml}',
        },
      },
    },
  }
end

return M
