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
        if bReceived and ent:IsNPC() then
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
        for _, ply in ipairs(player_GetAll()) do
            if IsValid(ply) then
                Start('snoi:UpdateRelations')
                    WriteUInt(ent:EntIndex(), 16)
                    WriteUInt(ent:Disposition(ply), 3)
                Send(ply)
            end
        end
    end

    timer.Create('snoi.UpdateState', 1, 0, function()
        for _, ent in ipairs(ents_GetAll()) do
            if IsValid(ent) and ent:IsNPC() then
                updateRelationsForNPC(ent)
            end
        end
    end)

    hook.Add('OnEntityCreated', 'snoi.UpdateState', function(ent)
        if ent:IsNPC() then
            updateRelationsForNPC(ent)
        end
    end)
end