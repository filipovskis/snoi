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
    local index = ent.snoiCacheIndex
    if index then
        table.remove(storage, index)
        storage.count = storage.count - 1

        for i = index, storage.count do
            local npc = storage[i]
            if npc then
                npc.snoiCacheIndex = npc.snoiCacheIndex - 1
            end
        end
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