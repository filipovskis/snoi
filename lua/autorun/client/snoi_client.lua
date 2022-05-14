--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

local _R = debug.getregistry()

local cvEnabled = CreateClientConVar('cl_snoi_enabled', '1')
local cv3D2D = CreateClientConVar('cl_snoi_3d2d', '0')
local cvDistance = CreateClientConVar('cl_snoi_distance', '512', nil, nil, nil, 256, 1024)

local colorRed = Color(214, 48, 49)
local colorHostile = Color(255, 149, 149)
local colorFriendly = Color(170, 255, 149)
local colorNeutral = Color(255, 255, 255)
local nearNPCs = {count = 0}
local distance = cvDistance:GetInt() ^ 2
local fadeStart = distance * .75
local slightOffset = Vector(0, 0, 2)
local font = 'Roboto'

cvars.AddChangeCallback('cl_snoi_distance', function()
    distance = cvDistance:GetInt() ^ 2
    fadeStart = distance * .75
end)

-- Relationship Enums
local D_ERR = 0
local D_HATE = 1
local D_FEAR = 2
local D_LIKE = 3
local D_NEUTRAL = 4

surface.CreateFont('snoi.3d2dfont', {
    font = font,
    size = 40,
    extended = true
})

surface.CreateFont('snoi.3d2dfont.blur', {
    font = font,
    size = 40,
    extended = true,
    blursize = 3
})

surface.CreateFont('snoi.font', {
    font = font,
    size = ScreenScale(6),
    extended = true
})

surface.CreateFont('snoi.font.blur', {
    font = font,
    size = ScreenScale(6),
    extended = true,
    blursize = 3
})

local drawText do
    local SimpleText = draw.SimpleText
    function drawText(text, x, y, color, alx, aly, b3D2D)
        local font = not b3D2D and 'snoi.font' or 'snoi.3d2dfont'
        SimpleText(text, font .. '.blur', x, y + 3, color_black, alx, aly)
        SimpleText(text, font, x, y, color, alx, aly)
    end
end

local drawMatGradient do
    local matGradient = Material('vgui/gradient-u.vtf', 'noclamp ignorez')

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

local drawHealthBar do
    local DrawRect = surface.DrawRect
    local SetDrawColor = surface.SetDrawColor
    local colorShade =Color(0, 0, 0, 100)

    function drawHealthBar(x, y, w, h, npc, hpFraction)
        if (CurTime() - npc:GetVar('snoiLastDamage', 0)) > .2 then
            npc.snoiOldHealth = Lerp(RealFrameTime() * 4, npc:GetVar('snoiOldHealth', 0), hpFraction)
        end

        SetDrawColor(0, 0, 0, 100)
        DrawRect(x, y, w, h)

        local hpLineWidth = math.ceil(w * hpFraction) - 4
        local whiteLineWidth = math.floor(w * npc.snoiOldHealth) - 4
        local whiteLineWidthActual = whiteLineWidth - hpLineWidth

        SetDrawColor(color_white)
        DrawRect(x + 2 + hpLineWidth, y + 2, whiteLineWidthActual, h - 4)

        SetDrawColor(colorRed)
        DrawRect(x + 2, y + 2, hpLineWidth, h - 4)

        drawMatGradient(x + 2, y + 2, hpLineWidth, h - 4, colorShade)
    end
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
    local GetNormalized = _R.Vector.GetNormalized
    local GetAimVector = _R.Player.GetAimVector
    local Dot = _R.Vector.Dot

    timer.Create('snoi.StoreNearestNPCs', rate, 0, function()
        local client = LocalPlayer()
        if IsValid(client) then
            local pos = GetPos(client)
            local vec = GetAimVector(client)

            nearNPCs = {count = 0}

            for _, ent in ipairs(GetAll()) do
                if ent:IsNPC() then
                    local entpos = GetPos(ent)
                    local dist = DistToSqr(pos, entpos)
                    if dist <= distance then
                        local index = nearNPCs.count + 1
                        local dot = Dot(vec, GetNormalized(entpos - pos))

                        ent.snoiName = ent.snoiName or findNPCName(ent)
                        ent.snoiDistance = dist
                        ent.snoiDotProduct = dot

                        nearNPCs[index] = ent
                        nearNPCs.count = index
                    end
                end
            end
        end
    end)
end

--[[------------------------------
Disply info (2D)
--------------------------------]]
do
    local GetPos = _R.Entity.GetPos
    local GetRenderBounds = _R.Entity.GetRenderBounds
    local SetAlphaMultiplier = surface.SetAlphaMultiplier
    local min = math.min
    local ScrW, ScreenScale = ScrW, ScreenScale
    local r, pi = .85, math.pi

    local function drawInfo(npc)
        local _, max = GetRenderBounds(npc)
        local zOffsetVector = Vector(0, 0, max.z)
        local realPos = GetPos(npc) + zOffsetVector + slightOffset
        local pos = realPos:ToScreen()
        local x0, y0 = pos.x, pos.y

        local w, h = ScrW() * .075, ScreenScale(5)
        local x, y = x0 - w * .5, y0

        local hpFraction = min(1, getNPCHealth(npc) / npc:GetMaxHealth())

        if hpFraction <= 0 then
            return
        end

        local distAlpha = npc.snoiDistance > fadeStart and 1 - (npc.snoiDistance - fadeStart) / (distance - fadeStart) or 1
        local mouseAlpha = min(255, (npc.snoiDotProduct - r) * pi * 555) / 255
        local alpha = min(distAlpha, mouseAlpha)
        local color = colorNeutral
        local relations = npc:GetVar('snoiRelations', 0)

        if relations == D_LIKE then
            color = colorFriendly
        elseif relations == D_HATE then
            color = colorHostile
        end

        SetAlphaMultiplier(alpha)
            drawHealthBar(x, y, w, h, npc, hpFraction)
            drawText(npc.snoiName, x0, y0 - 15, color, 1, 1)
        SetAlphaMultiplier(1)
    end

    hook.Add('HUDPaint', 'snoi.DrawInfo', function()
        if not cvEnabled:GetBool() then return end
        if not cv3D2D:GetBool() then
            for i = 1, nearNPCs.count do
                local npc = nearNPCs[i]
                if IsValid(npc) then
                    drawInfo(npc)
                end
            end
        end
    end)
end

--[[------------------------------
Display info (3D2D)
--------------------------------]]
do
    local GetPos = _R.Entity.GetPos
    local GetRenderBounds = _R.Entity.GetRenderBounds
    local EyeAngles = EyeAngles
    local Start3D2D = cam.Start3D2D
    local End3D2D = cam.End3D2D
    local min = math.min

    local scale = .05
    local angle = Angle(0, 0, 90)
    local infoWidth = 400
    local infoHeight = 25

    local function renderInfo(npc)
        local _, max = GetRenderBounds(npc)
        local zOffsetVector = Vector(0, 0, max.z)
        local pos = GetPos(npc) + zOffsetVector + slightOffset
        local ang = angle

        local hpFraction = min(1, getNPCHealth(npc) / npc:GetMaxHealth())

        if hpFraction <= 0 then
            return
        end

        if (CurTime() - npc:GetVar('snoiLastDamage', 0)) > .2 then
            npc.snoiOldHealth = Lerp(RealFrameTime() * 4, npc:GetVar('snoiOldHealth', 0), hpFraction)
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

            drawHealthBar(x, y, infoWidth, infoHeight, npc, hpFraction)
            drawText(npc.snoiName, 0, -40, color, 1, 1, true)
        End3D2D()
    end

    hook.Add('PostDrawTranslucentRenderables', 'snoi.RenderInfo', function()
        if not cvEnabled:GetBool() then return end
        if cv3D2D:GetBool() then
            angle.y = EyeAngles().y - 90
            for i = 1, nearNPCs.count do
                local npc = nearNPCs[i]
                if IsValid(npc) then
                    renderInfo(npc)
                end
            end
        end
    end)
end