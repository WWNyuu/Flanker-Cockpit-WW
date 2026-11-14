local DbOption = require('Options.DbOption')

return {
	su27_radio_enabled = DbOption.new():setValue(true):checkbox(),
	su27_radio_logs    = DbOption.new():setValue(false):checkbox(),
}
