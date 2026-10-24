-- Native startup reads this literal before executing Lua or opening settings.
APP_NAME = "astra_rml_compat_test"
-- Separate profile: never read saved accounts or connect to a server.
local source = g_resources.readFileContents('/production-init.lua')
source = source:gsub('APP_NAME = "AstraRmlClient"', 'APP_NAME = "astra_rml_compat_test"', 1)
assert(loadstring(source, '@production-init.lua'))()
