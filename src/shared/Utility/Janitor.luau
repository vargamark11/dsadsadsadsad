--!strict
--[[
    Janitor.luau
    Resource cleanup and connection management utility.
    Prevents memory leaks from orphaned event connections, tweens, and instances.
]]

export type Janitor = {
    Add: (self: Janitor, object: any, methodName: string?) -> any,
    Remove: (self: Janitor, object: any) -> (),
    Clean: (self: Janitor) -> (),
    Destroy: (self: Janitor) -> (),
}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(): Janitor
    local self = setmetatable({
        _objects = {} :: { [any]: string? },
    }, Janitor)
    return (self :: any) :: Janitor
end

function Janitor:Add(object: any, methodName: string?): any
    if object == nil then return nil end
    self._objects[object] = methodName or true
    return object
end

function Janitor:Remove(object: any)
    self._objects[object] = nil
end

function Janitor:Clean()
    for object, method in pairs(self._objects) do
        if typeof(object) == "RBXScriptConnection" then
            object:Disconnect()
        elseif type(object) == "table" and type(object.Disconnect) == "function" then
            object:Disconnect()
        elseif type(object) == "table" and type(object.Destroy) == "function" then
            object:Destroy()
        elseif typeof(object) == "Instance" then
            object:Destroy()
        elseif type(object) == "function" then
            task.spawn(object)
        elseif type(object) == "thread" then
            task.cancel(object)
        elseif method and type(object) == "table" and type(object[method]) == "function" then
            object[method](object)
        end
    end
    table.clear(self._objects)
end

function Janitor:Destroy()
    self:Clean()
    table.clear(self :: any)
end

return Janitor
