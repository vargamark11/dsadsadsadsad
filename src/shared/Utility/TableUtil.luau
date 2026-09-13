--!strict
--[[
    TableUtil.luau
    Immutable data utilities, deep copy, merge, and dictionary operations.
]]

local TableUtil = {}

function TableUtil.DeepCopy<T>(target: T): T
    if type(target) ~= "table" then
        return target
    end

    local copy: any = {}
    for k, v in pairs(target :: any) do
        if type(v) == "table" then
            copy[k] = TableUtil.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function TableUtil.Reconcile(target: { [string]: any }, template: { [string]: any }): { [string]: any }
    local result = TableUtil.DeepCopy(target)
    for k, v in pairs(template) do
        if result[k] == nil then
            if type(v) == "table" then
                result[k] = TableUtil.DeepCopy(v)
            else
                result[k] = v
            end
        elseif type(result[k]) == "table" and type(v) == "table" then
            result[k] = TableUtil.Reconcile(result[k], v)
        end
    end
    return result
end

function TableUtil.Freeze<T>(tbl: T): T
    if type(tbl) == "table" then
        for _, v in pairs(tbl :: any) do
            if type(v) == "table" and not table.isfrozen(v) then
                TableUtil.Freeze(v)
            end
        end
        table.freeze(tbl :: any)
    end
    return tbl
end

return TableUtil
