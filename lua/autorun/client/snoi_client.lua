--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

local _R = debug.getregistry()

local colorRed = Color(214, 48, 49)
local colorHostile = Color(255, 149, 149)
local colorFriendly = Color(170, 255, 149)
local colorNeutral = Color(255, 255, 255)
local nearNPCs = {count = 0}
local distance = 1024 ^ 2

local D_ERR = 0
local D_HATE = 1
local D_FEAR = 2
local D_LIKE = 3
local D_NEUTRAL = 4

surface.CreateFont('snoi.font', {
    font = 'Roboto',
    size = 48,
    extended = true
})

surface.CreateFont('snoi.font.blur', {
    font = 'Roboto',
    size = 48,
    extended = true,
    blursize = 3
})

local function drawText(text, x, y, color, alx, aly)
    draw.SimpleText(text, 'snoi.font.blur', x, y + 3, color_black, alx, aly)
    draw.SimpleText(text, 'snoi.font', x, y, color, alx, aly)
end

local drawMatGradient do
    local matGradient = Material('vgui/gradient-u.vtf')

    local SetMaterial = surface.SetMaterial
    local SetDrawColor = surface.SetDrawColor
    local DrawTexturedRect = surface.DrawTexturedRect

    function drawMatGradient(x, y, w, h, color)
        SetMaterial(matGradient)
        SetDrawColor(color)
        DrawTexturedRect(x, y, w ,h)
    end
end

local function findNPCName(npc)
    local model = npc:GetModel()
    local npcList = list.Get('NPC')

    --[[------------------------------
    Search by a model
    --------------------------------]]
    for _, data in pairs(npcList) do
        if data.Model == model then
            local name = data.Name
            name = name:gsub('%(Friendly%)', '', 1)
            name = name:gsub('%(Enemy%)', '', 1)
            name = name:gsub('%(Hostile%)', '', 1)
            name = name:Trim()

            return name
        end
    end

    --[[------------------------------
    Search by a class
    --------------------------------]]
    local npcData = npcList[npc:GetClass()]
    if npcData then
        return npcData.Name
    end

    return 'Unknown'
end

--[[------------------------------
Receive health/relationships updates (the engine updates health on the clientside with large delay)
--------------------------------]]
local getNPCHealth do
    local ReadUInt = net.ReadUInt
    local IsValid = IsValid
    local Entity = Entity

    net.Receive('snoi:UpdateHealth', function()
        local entIndex = ReadUInt(16)
        local hp = ReadUInt(15)
        local npc = Entity(entIndex)

        if IsValid(npc) then
            npc.snoiHealth = hp
            npc.snoiLastDamage = CurTime()
        end
    end)

    net.Receive('snoi:UpdateRelations', function()
        local entIndex = ReadUInt(16)
        local relations = ReadUInt(3)
        local npc = Entity(entIndex)

        if IsValid(npc) then
            npc.snoiRelations = relations
        end
    end)

    function getNPCHealth(npc)
        return npc.snoiHealth or npc:Health()
    end
end

--[[------------------------------
A timer to collect the nearest NPCs
--------------------------------]]
do
    local rate = 1 / 10

    local LocalPlayer = LocalPlayer
    local IsValid = IsValid
    local GetAll = ents.GetAll
    local GetPos = _R.Entity.GetPos
    local DistToSqr = _R.Vector.DistToSqr

    timer.Create('snoi.StoreNearestNPCs', rate, 0, function()
        local client = LocalPlayer()
        if IsValid(client) then
            local pos = GetPos(client)

            nearNPCs = {count = 0}

            for _, ent in ipairs(GetAll()) do
                if ent:IsNPC() and DistToSqr(pos, GetPos(ent)) <= distance then
                    local index = nearNPCs.count + 1

                    ent.snoiName = ent.snoiName or findNPCName(ent)

                    nearNPCs[index] = ent
                    nearNPCs.count = index
                end
            end
        end
    end)
end

--[[------------------------------
Display info
--------------------------------]]
do
    local GetPos = _R.Entity.GetPos
    local GetRenderBounds = _R.Entity.GetRenderBounds
    local EyeAngles = EyeAngles
    local Start3D2D = cam.Start3D2D
    local End3D2D = cam.End3D2D
    local DrawRect = surface.DrawRect
    local SetDrawColor = surface.SetDrawColor

    local scale = .05
    local angle = Angle(0, 0, 90)
    local infoWidth = 400
    local infoHeight = 20

    local function renderInfo(npc)
        local _, max = GetRenderBounds(npc)
        local zOffsetVector = Vector(0, 0, max.z)
        local pos = GetPos(npc) + zOffsetVector
        local ang = angle

        local hpFraction = math.min(1, getNPCHealth(npc) / npc:GetMaxHealth())

        if hpFraction <= 0 then
            return
        end

        if (CurTime() - npc:GetVar('snoiLastDamage', 0)) > .2 then
            npc.snoiOldHealth = Lerp(RealFrameTime() * 2, npc:GetVar('snoiOldHealth', 0), hpFraction)
        end

        local color = colorNeutral
        local relations = npc:GetVar('snoiRelations', 0)

        if relations == D_LIKE then
            color = colorFriendly
        elseif relations == D_HATE then
            color = colorHostile
        end

        Start3D2D(pos, ang, scale)
            local x, y = -infoWidth * .5, 0

            SetDrawColor(0, 0, 0, 200)
            DrawRect(x, y, infoWidth, infoHeight)

            SetDrawColor(color_white)
            DrawRect(x + 2, y + 2, infoWidth * npc.snoiOldHealth - 4, infoHeight - 4)

            SetDrawColor(colorRed)
            DrawRect(x + 2, y + 2, infoWidth * hpFraction - 4, infoHeight - 4)

            drawMatGradient(x + 2, y + 2, infoWidth * hpFraction - 4, infoHeight - 4, Color(0, 0, 0, 100))

            drawText(npc.snoiName, 0, -40, color, 1, 1)
        End3D2D()
    end

    hook.Add('PostDrawTranslucentRenderables', 'snoi.RenderInfo', function()
        angle.y = EyeAngles().y - 90
        for i = 1, nearNPCs.count do
            local npc = nearNPCs[i]
            if IsValid(npc) then
                renderInfo(npc)
            end
        end
    end)
end