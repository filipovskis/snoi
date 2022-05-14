--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

local _R = debug.getregistry()

local colorRed = Color(214, 48, 49)
local nearNPCs = {count = 0}
local distance = 1024 ^ 2

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

local function findNPCName(npc)
    local model = npc:GetModel()

    for _, data in pairs(list.Get('NPC')) do
        if data.Model == model then
            local name = data.Name
            name = name:gsub('%(Friendly%)', '', 1)
            name = name:gsub('%(Enemy%)', '', 1)
            name = name:gsub('%(Hostile%)', '', 1)
            name = name:Trim()

            return name
        end
    end

    return 'Unknown'
end

--[[------------------------------
Receive health updates (the engine updates health on the clientside with large delay)
--------------------------------]]
local getNPCHealth do
    local healthEnts = {}
    local ReadUInt = net.ReadUInt
    local EntIndex = _R.Entity.EntIndex

    net.Receive('snoi:UpdateHealth', function()
        local entIndex = ReadUInt(16)
        local hp = ReadUInt(15)

        healthEnts[entIndex] = hp
    end)

    hook.Add('EntityRemoved', 'ClearHealthCache', function(ent)
        local index = ent:EntIndex()
        if healthEnts[index] then
            healthEnts[index] = nil
        end
    end)

    function getNPCHealth(npc)
        return healthEnts[EntIndex(npc)] or npc:Health()
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

        Start3D2D(pos, ang, scale)
            SetDrawColor(0, 0, 0, 200)
            DrawRect(-infoWidth * .5, 0, infoWidth, infoHeight)

            SetDrawColor(colorRed)
            DrawRect(-infoWidth * .5 + 2, 2, infoWidth * hpFraction - 4, infoHeight - 4)

            drawText(npc.snoiName, 0, -40, color_white, 1, 1)
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