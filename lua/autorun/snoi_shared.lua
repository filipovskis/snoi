--[[

Author: tochnonement
Email: tochnonement@gmail.com

15/05/2022

--]]

snoiNPCs = snoiNPCs or {count = 0}
local storage = snoiNPCs

hook.Add('OnEntityCreated', 'snoi.CacheNPC', function(ent)
    if ent:IsNPC() or ent:IsNextBot() then
        local index = storage.count + 1
        storage[index] = ent
        storage.count = index
        ent.snoiCacheIndex = index
    end
end)

hook.Add('EntityRemoved', 'snoi.RemoveNPCFromCache', function(ent)
    if ent.snoiCacheIndex then
        table.remove(storage, ent.snoiCacheIndex)
        storage.count = storage.count - 1
    end
end)

timer.Create('snoi.CleanNullNPCs', 0.5, 0, function()
    local bChanges = false
    for i, ent in ipairs(storage) do
        if not IsValid(ent) then
            table.remove(storage, i)
            bChanges = true
        end
    end
    if bChanges then
        storage.count = #storage
    end
end)