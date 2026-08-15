-- axl_creator — BRIDGES
-- Ponte com os outros resources: notify, HUD, chat, barbearia, tattoo e anticheat.


Bridges = {}


Bridges.notify = function(source, nType, message, duration)
    duration = duration or 5
    if Config.notify.type == 'internal' then
        TriggerClientEvent('axl_creator:internalNotify', source, nType, message, duration)
    else
        TriggerClientEvent(Config.notify.event or 'Notify', source, nType, message, duration)
    end
end

Bridges.toggleHud = function(state)
    TriggerEvent('hudOff', state ~= true)  -- hudOff usa o valor invertido de state
    TriggerEvent('hud:toggle', state)
end

Bridges.toggleNotify = function(state)
    TriggerEvent('notify:toggle', state)
end

Bridges.toggleChat = function(state)
    if exports and exports.chat then
        local ok = pcall(function() exports.chat:setVisible(state == true) end)
        if ok then return end
    end
    TriggerEvent('chat:toggle', state)
end

Bridges.toggleShortcuts = function(state)
    TriggerEvent('shortcuts:toggle', state)
end

-- Aplica no ped o array de roupa com 30 valores.
Bridges.updateClothes = function(clothesArray)
    TriggerEvent('Character:UpdateClothes', clothesArray)
end

-- INTEGRAÇÕES OPCIONAIS (server side)

local function anyResourceStarted(names)
    if type(names) ~= 'table' then names = { names } end
    for _, name in ipairs(names) do
        if name and name ~= '' and GetResourceState(name) == 'started' then
            return true
        end
    end
    return false
end

-- Reaplica cabelo/barba do banco no ped depois que o personagem é criado.
Bridges.barbershopInit = function(user_id, source)
    if not Config.integrations.barbershop then return end
    if not anyResourceStarted({ 'vrp_barbershop', 'disney-barbershop', 'barbershop', 'm_barbershop' }) then
        if Config.debugMode then
            print('^5[axl_creator:bridges]^7 barbershopInit: nenhum resource de barbearia ativo')
        end
        return
    end
    SetTimeout(500, function()
        if source then
            pcall(TriggerEvent, 'vrp_barber:setPedServer', source)
        end
        pcall(TriggerEvent, 'disney-barbershop:init', user_id)
        pcall(TriggerEvent, 'barbershop:init',        user_id)
    end)
end

-- Reaplica as tatuagens do banco no ped depois que o personagem é criado.
Bridges.tattoosInit = function(user_id, source)
    if not Config.integrations.tattoos then return end
    if not anyResourceStarted({ 'vrp_tattoo', 'tattoo', 'tattos', 'm_tattoo' }) then
        if Config.debugMode then
            print('^5[axl_creator:bridges]^7 tattoosInit: nenhum resource de tatuagem ativo')
        end
        return
    end
    SetTimeout(500, function()
        if source then
            pcall(TriggerEvent, 'vrp_tattoo:setPedServer', source)
        end
        pcall(TriggerEvent, 'tattos:init', user_id)
    end)
end

Bridges.acForceBan = function(source, reason, additionalData)
    pcall(TriggerEvent, 'AC:ForceBan', source, {
        reason         = reason,
        additionalData = additionalData,
        forceBan       = true,
    })
end

Bridges.discordAuthEnabled = function()
    local name = Config.integrations.discordAuthResource
    if not name or name == '' then return false end
    return GetResourceState(name) == 'started'
end
