local component = require('component')
local thread = require('thread')
local event = require('event')
local sides = require('sides')
local gpu = component.gpu

-----------------------------------------
-- Программа для автоматизации крафта на алтаре
-- Нужна База данный 1 уровня и трансопрзер подклюенный к педесталу алтаря и интерфейсу АЕ
-- Смотрит что крафт закончени и прекладывает предмет.
-----------------------------------------

local CheckInterval = 1

local interface_name = "tile.appliedenergistics2.BlockInterface"
local pedestal_name = "tile.blockStoneDevice"

local interface_side = nil
local pedestal_side = nil

local tr = nil
local db = nil
local d_limit = 5

function main()
    init()

    local resetBColor, resetFColor = gpu.getBackground(), gpu.getForeground()
    local background = {}

    table.insert(background, event.listen("key_up", function (key, address, char)
        if char == string.byte('q') then
            event.push('exit')
        end
    end))
    table.insert(background, event.timer(CheckInterval, failFast(check_pedestal), math.huge))

    local _, err = event.pull("exit")

    for _, b in ipairs(background) do
        if type(b) == 'table' and b.kill then
            b:kill()
        else
            event.cancel(b)
        end
    end

    gpu.setBackground(resetBColor)
    gpu.setForeground(resetFColor)

    if err then
        io.stderr:write(err)
        os.exit(1)
    else
        os.exit(0)
    end
end

function failFast(fn)
    return function(...)
        local res = table.pack(xpcall(fn, debug.traceback, ...))
        if not res[1] then
            event.push('exit', res[2])
        end
        return table.unpack(res, 2)
    end
end

function errorExit(...)
    out(...)
    event.push('exit')
end

----------------------- DEBUG ---------------------------
function object_to_string(level, object) local function get_tabs(num) local msg = "" for i = 0, num do  msg = msg .. "  " end return msg end  if level == nil then level = 0 end  local message = " "  if object == nil then message = message .. "nil" elseif type(object) == "boolean" or type(object) == "number" then message = message .. tostring(object) end if type(object) == "string" then message = message..object end if type(object) == "function" then message = message.."\"__function\"" end
if type(object) == "table" then if level <= d_limit then message = message .. "\n" .. get_tabs(level) .. "{\n" for key, next_object in pairs(object) do message = message .. get_tabs(level + 1) .. "\"" .. key .. "\"" .. ":" .. object_to_string(level + 1, next_object) .. ",\n"; end message = message .. get_tabs(level) .. "}" else message = message .. "\"" .. "__table" .. "\"" end end return message end  function rec_obj_to_string(object, ...) arg = {...} 
if #arg > 0 then return object_to_string(0, object) .. rec_obj_to_string(...) else return object_to_string(0, object) end end  function out(...) local message = rec_obj_to_string(...) print(message) end 

----------------------- LOOP ---------------------------
function check_pedestal()
	if db.get(1) == nil then
		tr.store(pedestal_side,1,db.address,1)
	end
	if db.get(1) ~= nil then
		if tr.getStackInSlot(pedestal_side,1) ~= nil then
			print("Database: ",db.get(1).label)
			print("Pedestal: ",tr.getStackInSlot(pedestal_side,1).label)
			if not tr.compareStackToDatabase(pedestal_side,1,db.address,1,true) then
				while tr.getStackInSlot(pedestal_side,1) ~= nil do
					tr.transferItem(pedestal_side,interface_side,1,1,1)
					print("Перемещение!!!")
					db.clear(1)
				end
			end
		end
	end
end

-------------------- SUPPORTED FUNCTION -----------------------
function init()
    tr = link_component("transposer")
	db = link_component("database")

    if tr == nil then
        errorExit("Transposer not found")
        return
    end

    if db == nil then
        errorExit("Database not found")
        return
    end
	
	for i = 1, 9 do
		db.clear(i)
	end
		
    if interface_side == nil then
        interface_side = detect_named_side(interface_name)
        if interface_side == nil then
            errorExit("Interface: ", interface_name, " not found or not located next to the Transposer")
            return
        end
    end

    if pedestal_side == nil then
        pedestal_side = detect_named_side(pedestal_name)
        if pedestal_side == nil then
            errorExit("Pedestal: ", pedestal_name, " not found or not located next to the Transposer")
            return
        end
    end
	
	print("Database", db.address)
    print("Pedestal", pedestal_side)
    print("Interface", interface_side)
end

function link_component(comp_name)
    components = component.list(comp_name)
    ret_comp = nil
    for addr, name in pairs(components) do
        if ret_comp == nil then
            ret_comp = component.proxy(addr)
            print("Link component " .. name .. " to address " .. ret_comp.address)
        else
            print("Warning: More then one component " .. name .. " found. Used: " .. ret_comp.address)
        end
    end
    return ret_comp
end

function detect_named_side(name)
    for i = 0,5 do
        local loc_name = tr.getInventoryName(i)
        if loc_name == name then
            return i
        end
    end
end

main()
