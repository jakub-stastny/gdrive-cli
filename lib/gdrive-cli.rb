begin
  require 'google_drive'
rescue LoadError
  raise LoadError, "You need to install the google_drive gem first."
end

require_relative './gdrive-cli/api'
require_relative './gdrive-cli/commands'
