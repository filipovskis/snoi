--[[

Author: tochnonement
Email: tochnonement@gmail.com

14/05/2022

--]]

util.AddNetworkString('snoi:UpdateHealth')

--[[------------------------------
Send health updates (the engine updates health on the clientside with large delay)
--------------------------------]]
do
    local Start = net.Start
    local WriteUInt = net.WriteUInt
    local Broadcast = net.Broadcast
    local max = math.max

    hook.Add('PostEntityTakeDamage', 'snoi.CheckHealth', function(ent, dmg, bReceived)
        if bReceived and ent:IsNPC() then
            Start('snoi:UpdateHealth')
                WriteUInt(ent:EntIndex(), 16)
                WriteUInt(max(0, ent:Health()), 15)
            Broadcast()
        end
    end)
end