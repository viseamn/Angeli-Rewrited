local _cloneref = type(cloneref) == 'function' and cloneref or function(value)
	return value
end

local http_service = _cloneref(game:GetService('HttpService'))

local _fs_is_folder = isfolder
local _fs_make_folder = makefolder
local _fs_is_file = isfile
local _fs_read = readfile
local _fs_write = writefile
local _fs_list = listfiles

local _find = table.find
local _insert = table.insert
local _pairs = pairs
local _pcall = pcall
local _sort = table.sort
local _tostring = tostring
local _type = type

local ROOT_FOLDER = 'Angeli'
local CONFIG_FOLDER = `{ROOT_FOLDER}/configs`
local STATE_PATH = `{ROOT_FOLDER}/state.json`

local function has_folder(path)
	if _type(_fs_is_folder) ~= 'function' then
		return false
	end
	local ok, result = _pcall(_fs_is_folder, path)
	return ok and result == true
end

local function make_folder(path)
	if _type(_fs_make_folder) ~= 'function' then
		return false
	end
	return _pcall(_fs_make_folder, path)
end

local function has_file(path)
	if _type(_fs_is_file) ~= 'function' then
		return false
	end
	local ok, result = _pcall(_fs_is_file, path)
	return ok and result == true
end

local function read_file(path)
	if _type(_fs_read) ~= 'function' then
		return nil
	end
	local ok, result = _pcall(_fs_read, path)
	if ok and _type(result) == 'string' then
		return result
	end
	return nil
end

local function write_file(path, data)
	if _type(_fs_write) ~= 'function' then
		return false
	end
	return _pcall(_fs_write, path, data)
end

local function list_files(path)
	if _type(_fs_list) ~= 'function' then
		return {}
	end
	local ok, result = _pcall(_fs_list, path)
	if ok and _type(result) == 'table' then
		return result
	end
	return {}
end

local function ensure_folder(path)
	if not has_folder(path) then
		make_folder(path)
	end
end

local function encode(value)
	local ok, result = _pcall(function()
		return http_service:JSONEncode(value)
	end)
	return ok and result or nil
end

local function decode(value)
	if _type(value) ~= 'string' then
		return nil
	end
	local ok, result = _pcall(function()
		return http_service:JSONDecode(value)
	end)
	if ok and _type(result) == 'table' then
		return result
	end
	return nil
end

local function trim(value)
	local text = _tostring(value or '')
	text = string.gsub(text, '^%s+', '')
	return string.gsub(text, '%s+$', '')
end

local function safe_name(value)
	local text = trim(value)
	text = string.gsub(text, '[^%w_%- ]', '')
	text = string.gsub(text, '%s+', ' ')
	return string.sub(text, 1, 32)
end

ensure_folder(ROOT_FOLDER)
ensure_folder(CONFIG_FOLDER)
ensure_folder(`{ROOT_FOLDER}/assets`)

local save_manager = {
	_active = nil,
	_autosave = true,
	_dirty = false,
	_listeners = {},
	_library = nil,
}

function save_manager.attach(library)
	save_manager._library = library
end

local function config_folder()
	return `{CONFIG_FOLDER}/{game.GameId}`
end

local function profile_path(name)
	return `{config_folder()}/{name}.json`
end

function save_manager.state()
	local raw = has_file(STATE_PATH) and read_file(STATE_PATH) or nil
	return decode(raw) or {}
end

function save_manager.write_state(state)
	ensure_folder(ROOT_FOLDER)
	return write_file(STATE_PATH, encode(state) or '{}')
end

function save_manager.profiles()
	ensure_folder(config_folder())

	local names = {}

	for _, path in list_files(config_folder()) do
		local file = string.gsub(_tostring(path), '\\', '/'):match('([^/]+)%.json$')
		if file and not _find(names, file) then
			_insert(names, file)
		end
	end

	_sort(names)

	return names
end

function save_manager.exists(name)
	return has_file(profile_path(name))
end

function save_manager.save(name, silent)
	name = safe_name(name) ~= '' and safe_name(name) or save_manager._active or 'default'

	ensure_folder(config_folder())

	local library = save_manager._library
	local payload = {}

	for key, value in _pairs(library._flags) do
		if not string.find(key, '^__') then
			payload[key] = value
		end
	end

	local encoded = encode(payload)
	if not encoded then
		return false
	end

	if not write_file(profile_path(name), encoded) then
		return false
	end

	save_manager._active = name
	save_manager._dirty = false
	library:_persist_state()

	if not silent then
		for _, listener in _pairs(save_manager._listeners) do
			_pcall(listener, name)
		end
	end

	return true
end

function save_manager.load(name)
	if not save_manager.exists(name) then
		return false
	end

	local decoded = decode(read_file(profile_path(name)))
	if not decoded then
		return false
	end

	local library = save_manager._library

	save_manager._active = name
	library:_apply_flags(decoded)

	if _type(library._flags.keybind_list) == 'boolean' then
		library:set_keybind_visible(library._flags.keybind_list)
	end

	library:_persist_state()

	return true
end

function save_manager.delete(name)
	local path = profile_path(name)

	if not has_file(path) then
		return false
	end

	if _type(delfile) ~= 'function' then
		return false
	end

	if not _pcall(delfile, path) then
		return false
	end

	if save_manager._active == name then
		save_manager._active = nil
	end

	return true
end

function save_manager.listen(callback)
	_insert(save_manager._listeners, callback)
	return callback
end

return save_manager
