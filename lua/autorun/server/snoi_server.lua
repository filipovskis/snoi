--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

util.AddNetworkString('snoi:SetDead')
util.AddNetworkString('snoi:UpdateHealth')
util.AddNetworkString('snoi:UpdateRelations')

local _R = debug.getregistry()

local SendPVSWhereEnt do
    local GetPos = _R.Entity.GetPos
    local SendPVS = net.SendPVS

    function SendPVSWhereEnt(ent)
        SendPVS(GetPos(ent))
    end
end

--[[------------------------------
Send health updates (the engine updates health on the clientside with large delay)
--------------------------------]]
do
    local Start = net.Start
    local WriteUInt = net.WriteUInt
    local WriteBool = net.WriteBool
    local max = math.max
    local CurTime = CurTime
    local IsValid = IsValid

    local convarHealth = CreateConVar('sv_snoi_custom_health_listener', '1', {FCVAR_ARCHIVE, FCVAR_NOTIFY})

    local function updateHealth(ent, fromDamage)
        Start('snoi:UpdateHealth')
            WriteUInt(ent:EntIndex(), 16)
            WriteUInt(max(0, ent:Health()), 15)
            WriteBool(fromDamage)
        SendPVSWhereEnt(ent)
    end

    local function loadCustomHealthListener()
        hook.Add('PostEntityTakeDamage', 'snoi.UpdateHealth', function(ent, dmg, bReceived)
            if bReceived and (ent:IsNPC() or ent:IsNextBot()) then
                updateHealth(ent, true)
                ent.snoiLastHealthUpdate = CurTime()
            end
        end)

        hook.Add('Tick', 'snoi.UpdateHealth', function()
            local now = CurTime()
            for i = 1, snoiNPCs.count do
                local ent = snoiNPCs[i]
                if IsValid(ent) and (now - ent:GetVar('snoiLastHealthUpdate', 0)) > .1 then
                    updateHealth(ent)
                    ent.snoiLastHealthUpdate = now
                end
            end
        end)
    end

    local function unloadCustomHealthListener()
        hook.Remove('PostEntityTakeDamage', 'snoi.UpdateHealth')
        hook.Remove('Tick', 'snoi.UpdateHealth')
    end

    if convarHealth:GetBool() then
        loadCustomHealthListener()
    end

    cvars.AddChangeCallback('sv_snoi_custom_health_listener', function(_, old, new)
        if new then
            loadCustomHealthListener()
        else
            unloadCustomHealthListener()
        end
    end)
end

--[[------------------------------
Mark NCPS as dead asap
--------------------------------]]
do
    local Start = net.Start
    local WriteUInt = net.WriteUInt

    hook.Add('OnNPCKilled', 'snoi.MarkAsDead', function(ent)
        if IsValid(ent) then
            Start('snoi:SetDead')
                WriteUInt(ent:EntIndex(), 16)
            SendPVSWhereEnt(ent)
        end
    end)
end

--[[------------------------------
Send relationships
--------------------------------]]
do
    local Start = net.Start
    local WriteUInt = net.WriteUInt
    local Send = net.Send
    local IsValid = IsValid
    local player_GetAll = player.GetAll
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
        for i = 1, snoiNPCs.count do
            local ent = snoiNPCs[i]
            if IsValid(ent) then
                updateRelationsForNPC(ent)
            end
        end
    end)

    hook.Add('snoi.OnNPCSpawned', 'snoi.UpdateState', function(ent)
        if IsValid(ent) then
            delayedUpdateRelations(ent)
        end
    end)
end