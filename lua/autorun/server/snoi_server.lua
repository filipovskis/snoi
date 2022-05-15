--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

util.AddNetworkString('snoi:UpdateHealth')
util.AddNetworkString('snoi:UpdateRelations')

--[[------------------------------
Send health updates (the engine updates health on the clientside with large delay)
--------------------------------]]
do
    local Start = net.Start
    local WriteUInt = net.WriteUInt
    local Broadcast = net.Broadcast
    local max = math.max

    hook.Add('PostEntityTakeDamage', 'snoi.UpdateHealth', function(ent, dmg, bReceived)
        if bReceived and (ent:IsNPC() or ent:IsNextBot()) then
            Start('snoi:UpdateHealth')
                WriteUInt(ent:EntIndex(), 16)
                WriteUInt(max(0, ent:Health()), 15)
            Broadcast()
        end
    end)
end

do
    local Start = net.Start
    local WriteUInt = net.WriteUInt
    local Send = net.Send
    local IsValid = IsValid
    local player_GetAll = player.GetAll
    local ents_GetAll = ents.GetAll
    local ipairs = ipairs

    local function updateRelationsForNPC(ent)
        if ent.Disposition then
            for _, ply in ipairs(player_GetAll()) do
                if IsValid(ply) then
                    local relations = ent:Disposition(ply)
                    Start('snoi:UpdateRelations')
                        WriteUInt(ent:EntIndex(), 16)
                        WriteUInt(relations, 3)
                    Send(ply)
                end
            end
        end
    end

    -- Required for DrgBase
    local function delayedUpdateRelations(npc)
        timer.Create('UpdateRelations_' .. npc:EntIndex(), .2, 1, function()
            if IsValid(npc) then
                updateRelationsForNPC(npc)
            end
        end)
    end

    timer.Create('snoi.UpdateState', 2, 0, function()
        for _, ent in ipairs(ents_GetAll()) do
            if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                updateRelationsForNPC(ent)
            end
        end
    end)

    hook.Add('OnEntityCreated', 'snoi.UpdateState', function(ent)
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
            delayedUpdateRelations(ent)
        end
    end)
end