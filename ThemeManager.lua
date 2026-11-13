local _pairs = pairs
local _pcall = pcall
local _insert = table.insert

local theme = {
	_name = nil,
	_current = nil,
	_order = {},
	_palettes = {},
	_bindings = {},
	_refreshers = {},
	_persist = nil,
}

local function shallow_copy(source)
	local copy = {}
	for index, value in source or {} do
		copy[index] = value
	end
	return copy
end

function theme.color(role)
	local palette = theme._current
	return (palette and palette[role]) or Color3.fromRGB(255, 255, 255)
end

function theme.register(name, palette)
	if type(name) ~= 'string' or type(palette) ~= 'table' then
		return false
	end
	if not theme._palettes[name] then
		_insert(theme._order, name)
	end
	theme._palettes[name] = palette
	return true
end

function theme.paint(instance, property, role)
	local entry = theme._bindings[instance]
	if not entry then
		entry = {}
		theme._bindings[instance] = entry
	end
	entry[property] = role
	_pcall(function()
		instance[property] = theme.color(role)
	end)
	return instance
end

function theme.on_apply(callback)
	_insert(theme._refreshers, callback)
	callback()
	return callback
end

function theme.on_persist(callback)
	theme._persist = callback
end

function theme.apply(name, persist)
	local palette = theme._palettes[name]
	if not palette then
		return false
	end
	theme._name = name
	theme._current = palette
	for instance, properties in _pairs(theme._bindings) do
		for property, role in _pairs(properties) do
			_pcall(function()
				instance[property] = palette[role] or palette.text
			end)
		end
	end
	for _, callback in _pairs(theme._refreshers) do
		_pcall(callback)
	end
	if persist and theme._persist then
		theme._persist()
	end
	return true
end

function theme.set_accent(color)
	if not color then
		return false
	end

	theme._current.accent = color
	theme.apply(theme._name, false)

	return true
end

function theme.list()
	return shallow_copy(theme._order)
end

function theme.current()
	return theme._name
end

theme.register('Dark', {
	bg = Color3.fromRGB(18, 18, 18),
	surface = Color3.fromRGB(24, 24, 24),
	surface_alt = Color3.fromRGB(38, 38, 38),
	stroke = Color3.fromRGB(40, 40, 40),
	text = Color3.fromRGB(255, 255, 255),
	text_dim = Color3.fromRGB(160, 160, 160),
	accent = Color3.fromRGB(255, 255, 255),
	accent_text = Color3.fromRGB(18, 18, 18),
})

theme.register('Midnight', {
	bg = Color3.fromRGB(11, 16, 32),
	surface = Color3.fromRGB(17, 26, 46),
	surface_alt = Color3.fromRGB(27, 39, 64),
	stroke = Color3.fromRGB(32, 46, 74),
	text = Color3.fromRGB(234, 242, 255),
	text_dim = Color3.fromRGB(140, 160, 195),
	accent = Color3.fromRGB(76, 141, 255),
	accent_text = Color3.fromRGB(6, 16, 31),
})

theme.register('Ash', {
	bg = Color3.fromRGB(23, 23, 23),
	surface = Color3.fromRGB(31, 31, 31),
	surface_alt = Color3.fromRGB(43, 43, 43),
	stroke = Color3.fromRGB(48, 48, 48),
	text = Color3.fromRGB(242, 242, 242),
	text_dim = Color3.fromRGB(158, 158, 158),
	accent = Color3.fromRGB(214, 214, 214),
	accent_text = Color3.fromRGB(20, 20, 20),
})

theme.register('Rose', {
	bg = Color3.fromRGB(26, 16, 20),
	surface = Color3.fromRGB(36, 21, 25),
	surface_alt = Color3.fromRGB(51, 29, 35),
	stroke = Color3.fromRGB(60, 34, 41),
	text = Color3.fromRGB(255, 233, 239),
	text_dim = Color3.fromRGB(199, 154, 167),
	accent = Color3.fromRGB(255, 107, 139),
	accent_text = Color3.fromRGB(26, 10, 14),
})

theme.register('Mint', {
	bg = Color3.fromRGB(15, 26, 22),
	surface = Color3.fromRGB(21, 36, 32),
	surface_alt = Color3.fromRGB(29, 51, 45),
	stroke = Color3.fromRGB(34, 64, 58),
	text = Color3.fromRGB(231, 255, 245),
	text_dim = Color3.fromRGB(147, 191, 174),
	accent = Color3.fromRGB(76, 224, 165),
	accent_text = Color3.fromRGB(6, 35, 26),
})

theme._current = theme._palettes.Dark
theme._name = 'Dark'

return theme
