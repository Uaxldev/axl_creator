-- axl_creator / client.lua
-- Criador de personagem: monta o ped, controla a câmera e a interface.
-- =====================================================================

AXL_CREATE_MODE = 'new'

AXL_SKIP_WL = false

AXL_BOOT_LOCKED = true
CreateThread(function()
    DoScreenFadeOut(0)
    while AXL_BOOT_LOCKED do
        local ped = PlayerPedId()
        if ped ~= 0 and ped ~= -1 then
            if IsEntityVisible(ped) then SetEntityVisible(ped, false) end
            if not IsEntityPositionFrozen(ped) then FreezeEntityPosition(ped, true) end
        end
        if not IsScreenFadedOut() and not IsScreenFadingOut() then
            DoScreenFadeOut(0)
        end
        Wait(50)
    end
end)

-- INPUT LOCK GLOBAL (durante cinematic spawn)
-- =====================================================================

AXL_RETURNING_LOCKED = false


-- /axlunlock — destrava de emergência. Só admin (quem valida é o server).
RegisterCommand('axlunlock', function()
    TriggerServerEvent('axl_creator:requestUnlock')
end, false)

RegisterNetEvent('axl_creator:doUnlock')
AddEventHandler('axl_creator:doUnlock', function()
    if Config.debugMode then
        print('^3[axl_creator]^7 axlunlock: destravando (autorizado pelo server)')
    end
    AXL_RETURNING_LOCKED = false
    AXL_BOOT_LOCKED = false
    DoScreenFadeIn(500)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    DisplayHud(true)
    DisplayRadar(true)
end)


-- Esconde a HUD durante a cinematic de retorno.
-- Use sempre lockReturningHud(), nunca setar AXL_RETURNING_LOCKED na mão.
local returningHudThread = false

function lockReturningHud()
    AXL_RETURNING_LOCKED = true
    if returningHudThread then return end
    returningHudThread = true

    CreateThread(function()
        while AXL_RETURNING_LOCKED do
            DisplayHud(false)
            DisplayRadar(false)
            pcall(function() TriggerEvent('hudOff', true) end)
            pcall(function() TriggerEvent('hud:toggle', false) end)
            pcall(function() TriggerEvent('notify:toggle', false) end)
            Wait(200)
        end
        returningHudThread = false
    end)
end

-- ANTI-FLASH AEROPORTO — autospawn callback custom
-- =====================================================================

local function axlSilentAutoSpawn()
    -- Ponto temporário — o ped fica invisível aqui.
    local sx, sy, sz, sh = -1037.71, -2737.92, 20.17, 0.0
    DoScreenFadeOut(0)

    SetPlayerControl(PlayerId(), false, 0)
    RequestCollisionAtCoord(sx, sy, sz)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, sx, sy, sz, false, false, false, true)
    NetworkResurrectLocalPlayer(sx, sy, sz, sh, true, true, false)
    ClearPedTasksImmediately(ped)
    RemoveAllPedWeapons(ped, true)
    ClearPlayerWantedLevel(PlayerId())

    -- Espera a colisão carregar, no máximo 5s.
    local t = GetGameTimer()
    while (not HasCollisionLoadedAroundEntity(ped)) and (GetGameTimer() - t) < 5000 do
        Wait(0)
    end

    ShutdownLoadingScreen()
    -- Sem fade in aqui: a tela fica preta até o creator assumir.

    SetEntityVisible(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)

    TriggerEvent('playerSpawned', { x = sx, y = sy, z = sz, heading = sh })
end

CreateThread(function()
    Wait(0)
    if exports.spawnmanager and exports.spawnmanager.setAutoSpawnCallback then
        exports.spawnmanager:setAutoSpawnCallback(axlSilentAutoSpawn)
    end
end)

-- Reinstala o callback no start do mapa.
AddEventHandler('onClientMapStart', function()
    if exports.spawnmanager and exports.spawnmanager.setAutoSpawnCallback then
        exports.spawnmanager:setAutoSpawnCallback(axlSilentAutoSpawn)
    end
end)


function releaseBootLock()
    AXL_BOOT_LOCKED = false
    local ped = PlayerPedId()
    if ped ~= 0 and ped ~= -1 then
        SetEntityVisible(ped, true)
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityCollision(ped, true, true)
    end
    SetPlayerControl(PlayerId(), true, 0)
    -- Desliga o autospawn: morte e coma são do vRP.
    if exports.spawnmanager and exports.spawnmanager.setAutoSpawn then
        pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    end
end


exports('releaseBootLock', releaseBootLock)

-- Mesma coisa por evento, caso o export não esteja disponível.
RegisterNetEvent('axl_creator:externalReleaseBootLock')
AddEventHandler('axl_creator:externalReleaseBootLock', function()
    if releaseBootLock then releaseBootLock() end
end)
CreateThread(function()

    Wait(60000)
    if AXL_BOOT_LOCKED then
        print('^1[axl_creator]^7 BOOT_LOCK: timeout 60s — kickando pra forçar reconexão')
        TriggerServerEvent('axl_creator:flowFailed', 'BOOT_LOCK_TIMEOUT_60S')
    end
end)

local Tunnel = module('vrp', 'lib/Tunnel')
local Proxy  = module('vrp', 'lib/Proxy')

vRP     = Proxy.getInterface('vRP')
vSERVER = Tunnel.getInterface(GetCurrentResourceName())

-- Estado do creator
-- =====================================================================
local cam                      = nil
local doStatus                 = -1
-- Sempre o nome do modelo, nunca índice: o resto do código compara por nome.
local actual_gender            = 'mp_m_freemode_01'
local isInCharacterMode        = false

-- Conversor: customization (vroupas2 format) → array linear de 30 valores
-- =====================================================================

local function getEntry(tbl, key)  return tbl[key] or tbl[tostring(key)] end
local function getProp(tbl, idx)   return tbl["p"..idx] end

local function customizationToArray(custom)
    if type(custom) ~= 'table' then return nil end
    local out = {}
    local compMap = {
        { 1,  1  }, { 3,  5  }, { 5,  7  }, { 7,  3  }, { 9,  4  },
        { 11, 8  }, { 13, 6  }, { 15, 11 }, { 17, 9  }, { 19, 10 },
    }
    for _, m in ipairs(compMap) do
        local arrIdx, compIdx = m[1], m[2]
        local entry = getEntry(custom, compIdx)
        if entry then
            out[arrIdx]     = tonumber(entry[1]) or 0
            out[arrIdx + 1] = tonumber(entry[2]) or 0
        else
            out[arrIdx]     = -1
            out[arrIdx + 1] = -1
        end
    end
    local propMap = { { 21, 0 }, { 23, 1 }, { 25, 2 }, { 27, 6 }, { 29, 7 } }
    for _, m in ipairs(propMap) do
        local arrIdx, propIdx = m[1], m[2]
        local entry = getProp(custom, propIdx)
        if entry then
            out[arrIdx]     = tonumber(entry[1]) or -1
            out[arrIdx + 1] = tonumber(entry[2]) or 0
        else
            out[arrIdx]     = -1
            out[arrIdx + 1] = 0
        end
    end
    return out
end

local function resolveStartClothes(custom)
    if type(custom) ~= 'table' then return nil end
    -- Formato customization: cada entrada é uma table.
    if type(custom[1]) == 'table' or type(custom[3]) == 'table' or type(custom['p0']) == 'table' then
        return customizationToArray(custom)
    end
    -- Formato antigo: array linear de 30 números.
    return custom
end

-- Aplica no ped os 30 valores do array linear de roupa.
-- =====================================================================
local function applyLinearClothes(ped, linear)
    if not ped or ped == 0 or ped == -1 then return end
    if type(linear) ~= 'table' then return end

    local compMap = {
        { 1,  1  }, { 3,  5  }, { 5,  7  }, { 7,  3  }, { 9,  4  },
        { 11, 8  }, { 13, 6  }, { 15, 11 }, { 17, 9  }, { 19, 10 },
    }
    for _, m in ipairs(compMap) do
        local arrIdx, compIdx = m[1], m[2]
        local d = tonumber(linear[arrIdx]) or -1
        local t = tonumber(linear[arrIdx + 1]) or 0
        if d >= 0 then
            SetPedComponentVariation(ped, compIdx, d, t, 2)
        end
    end

    local propMap = { { 21, 0 }, { 23, 1 }, { 25, 2 }, { 27, 6 }, { 29, 7 } }
    for _, m in ipairs(propMap) do
        local arrIdx, propIdx = m[1], m[2]
        local d = tonumber(linear[arrIdx]) or -1
        local t = tonumber(linear[arrIdx + 1]) or 0
        if d == -1 then
            ClearPedProp(ped, propIdx)
        else
            SetPedPropIndex(ped, propIdx, d, t, true)
        end
    end
end

-- Defaults (linear) usados se Config.startClothes não existir
local DEFAULT_MALE_LINEAR   = { 0,0,0,0,0,0,0,0,298,0,15,0,114,0,761,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 }
local DEFAULT_FEMALE_LINEAR = { 0,0,0,0,0,0,15,0,321,0,15,0,118,0,861,0,0,0,0,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1 }

local startClothes = {
    [`mp_m_freemode_01`] = resolveStartClothes(Config and Config.startClothes and Config.startClothes.male)   or DEFAULT_MALE_LINEAR,
    [`mp_f_freemode_01`] = resolveStartClothes(Config and Config.startClothes and Config.startClothes.female) or DEFAULT_FEMALE_LINEAR,
}

-- Helper: detecta tipo do veículo (carro/moto) pra mostrar ícone certo
-- =====================================================================

local AXL_VRP_VEHICLES_CACHE = nil
local function getVrpVehicles()
    if AXL_VRP_VEHICLES_CACHE ~= nil then return AXL_VRP_VEHICLES_CACHE end
    local ok, mod = pcall(module, 'vrp', 'cfg/vehicles')
    if ok and mod and mod.vehicles then
        AXL_VRP_VEHICLES_CACHE = mod.vehicles
    else
        AXL_VRP_VEHICLES_CACHE = false  -- evita re-tentar
    end
    return AXL_VRP_VEHICLES_CACHE
end

local function detectVehicleType(modelId)
    if not modelId then return 'car' end
    -- Primeiro tenta pela native do GTA.
    local hash = GetHashKey(tostring(modelId))
    if IsModelInCdimage(hash) then
        if IsThisModelABike(hash) or IsThisModelABicycle(hash) then
            return 'bike'
        end
        return 'car'
    end
    -- Fallback: lê do cfg do vRP
    local vehicles = getVrpVehicles()
    if vehicles and vehicles[modelId] then
        local v = vehicles[modelId]
        local m = string.lower(tostring(v.modelo or v.tipo or ''))
        if m:find('moto') or m:find('bike') then return 'bike' end
    end
    return 'car'
end


local AXL_STARTER_VALIDATED = false
local function getEnrichedStarterCars()
    local vehicles = getVrpVehicles()
    local out = {}
    for _, car in ipairs(Config.starterCars or {}) do
        if type(car) == 'table' and car.id then
            out[#out+1] = {
                id      = car.id,
                name    = car.name,
                tagline = car.tagline,
                type    = car.type or detectVehicleType(car.id),
                image   = car.image, -- nome do PNG ou URL da imagem
            }
            if not AXL_STARTER_VALIDATED and vehicles and not vehicles[car.id] then
                print(('^1[axl_creator]^7 Atenção: starterCar id=%s não existe em vrp/cfg/vehicles.lua'):format(tostring(car.id)))
            end
        end
    end
    AXL_STARTER_VALIDATED = true
    return out
end

local function defaultCharacterMode()
    return {
        fathersID = 0, mothersID = 0, skinColor = 0, shapeMix = 0.0,
        eyesColor = 0, eyesOpening = 0.0,
        eyebrowsHeight = 0, eyebrowsWidth = 0,
        noseWidth = 0, noseHeight = 0, noseLength = 0, noseBridge = 0, noseTip = 0, noseShift = 0,
        cheekboneHeight = 0, cheekboneWidth = 0, cheeksWidth = 0,
        lips = 0, jawWidth = 0, jawHeight = 0,
        chinLength = 0, chinPosition = 0, chinWidth = 0, chinShape = 0,
        neckWidth = 0,
        hairModel = 4, firstHairColor = 0, secondHairColor = 0, hairHighlight = 1,
        eyebrowsModel = 0, eyebrowsColor = 0,
        beardModel = -1, beardColor = 0,
        chestModel = -1, chestColor = 0,
        blushModel = -1, blushColor = 0,
        lipstickModel = -1, lipstickColor = 0,
        blemishesModel = -1, ageingModel = -1, complexionModel = -1, sundamageModel = -1,
        frecklesModel = -1, makeupModel = -1,
        bodyBlemishes = -1, bodyBlemishesAdd = -1,
    }
end

local currentCharacterMode = defaultCharacterMode()

-- Util
-- =====================================================================
local function f(n) n = n + 0.00000; return n end

local function StartFade()
    DoScreenFadeOut(500)
    while IsScreenFadingOut() do Wait(1) end
end

local function EndFade()
    ShutdownLoadingScreen()
    DoScreenFadeIn(500)
    while IsScreenFadingIn() do Wait(1) end
end

-- Câmera do creator
-- =====================================================================
function TriggerCamController(statusSent)
    if not DoesCamExist(cam) then cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false) end

    if statusSent == -1 then
        local pos = GetEntityCoords(PlayerPedId())
        SetCamCoord(cam, vector3(pos.x, pos.y, f(1000)))
        SetCamRot(cam, -f(90), f(0), f(0), 2)
        SetCamActive(cam, true)
        StopCamPointing(cam)
        RenderScriptCams(true, true, 0, 0, 0, 0)
    elseif statusSent == -2 then
        SetCamActive(cam, false)
        StopCamPointing(cam)
        RenderScriptCams(0, 0, 0, 0, 0, 0)
        SetFocusEntity(PlayerPedId())
    elseif statusSent == 1 then
        local ped      = PlayerPedId()
        local headBone = GetPedBoneIndex(ped, 0x796E)
        local x, y, z  = table.unpack(GetWorldPositionOfEntityBone(ped, headBone))
        local heading  = GetEntityHeading(ped)
        local rad      = math.rad(heading)
        local dist     = (Config and Config.camera and Config.camera.initialDistance) or 1.4

        SetCamCoord(cam,
            x + math.sin(-rad) * dist,
            y + math.cos(-rad) * dist,
            z)
        PointCamAtCoord(cam, x, y, z)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, 0, 0, 0)
    end
end

-- Eventos de entrada
-- =====================================================================
RegisterNetEvent('axl_creator:characterCreate')
AddEventHandler('axl_creator:characterCreate', function()
    currentCharacterMode = defaultCharacterMode()
    doStatus = 1
    SetTimeout(100, function() TriggerCreateCharacter() end)
end)

AXL_SHOWROOM_RETURN = nil

RegisterNetEvent('axl_creator:resetAndCreate')
AddEventHandler('axl_creator:resetAndCreate', function(opts)
    AXL_CREATE_MODE = (opts and opts.mode) or 'reset'
    AXL_SKIP_WL = (opts and opts.skipWL) == true

    -- No showroom, salvamos a coord/heading atual pra restaurar depois.
    if AXL_CREATE_MODE == 'showroom' then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        AXL_SHOWROOM_RETURN = {
            x = pos.x, y = pos.y, z = pos.z,
            h = GetEntityHeading(ped),
        }
    end

    currentCharacterMode = defaultCharacterMode()
    doStatus = 1
    SetTimeout(500, function() TriggerCreateCharacter() end)
end)

-- axl_creator:resumeWhitelist — volta pra tela de WL no reconnect
-- =====================================================================

RegisterNetEvent('axl_creator:resumeWhitelist')
AddEventHandler('axl_creator:resumeWhitelist', function(prefillData)
    AXL_CREATE_MODE = 'resumeWl'
    isInCharacterMode = true

    -- Trava input + esconde HUD
    Bridges.toggleHud(false)
    Bridges.toggleNotify(false)
    Bridges.toggleChat(false)
    Bridges.toggleShortcuts(false)

    if releaseSwapLock then releaseSwapLock() end
    releaseBootLock()

    local ped = PlayerPedId()
    SetEntityVisible(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)

    local s = Config.coords.studio
    if s then
        RequestCollisionAtCoord(s.x, s.y, s.z)
        SetEntityCoordsNoOffset(ped, s.x, s.y, s.z, true, true, true)
        SetEntityHeading(ped, f(s.h or 0.0))
    end

    -- Manda NUI pra tela de WL com dados pré-preenchidos
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'unlock' })
    SendNUIMessage({
        screen        = 'whitelist',
        userId        = prefillData.userId or 0,
        characterData = {
            name    = prefillData.name or '',
            surname = prefillData.surname or '',
            age     = prefillData.age or 18,
        },
        branding      = Config.branding,
        starterCars   = getEnrichedStarterCars(),
        idade         = Config.idade,
        texts         = Config.texts,
        theme         = Config.theme,
        creatorCamera = Config.creatorCamera,
        whitelistFundo= Config.whitelistFundo,
        mode          = 'resumeWl',
    })

    DoScreenFadeIn(800)
end)

RegisterNetEvent('axl_creator:normalSpawn')
AddEventHandler('axl_creator:normalSpawn', function(firstspawn)
    if firstspawn then
        loadCutSine()
    else
        cinematicReturningSpawn()
    end
end)

-- cinematicReturningSpawn — wrapper fino que delega pro axl_spawn
-- =====================================================================

function cinematicReturningSpawn()
    -- Trava input + esconde HUD desde o início
    lockReturningHud()
    Bridges.toggleHud(false)
    Bridges.toggleNotify(false)
    Bridges.toggleChat(false)
    Bridges.toggleShortcuts(false)
    DisplayHud(false)
    DisplayRadar(false)

    if releaseBootLock then releaseBootLock() end

    -- Usa a posição onde o vRP já colocou o player.
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped) or 0.0

    local ok, err = pcall(function()
        if exports['axl_spawn'] and exports['axl_spawn'].cinematicSpawn then
            exports['axl_spawn']:cinematicSpawn(pos.x, pos.y, pos.z, {
                heading    = heading,
                tag        = 'returning',
                clothesBuf = 1500,
            })
        else
            error('axl_spawn:cinematicSpawn export indisponível')
        end
    end)
    if not ok then
        print(('^1[axl_creator]^7 cinematicReturningSpawn: erro no export — %s'):format(tostring(err)))
        -- Fallback mínimo: garantir que player não fica travado
        DoScreenFadeIn(500)
        SetPlayerControl(PlayerId(), true, 0)
        local pfix = PlayerPedId()
        SetEntityVisible(pfix, true, false)
        SetEntityInvincible(pfix, false)
        FreezeEntityPosition(pfix, false)
        SetEntityCollision(pfix, true, true)
    end

    AXL_RETURNING_LOCKED = false

    DisplayHud(true)
    DisplayRadar(true)

    Bridges.toggleHud(true)
    Bridges.toggleNotify(true)
    Bridges.toggleChat(true)
    Bridges.toggleShortcuts(true)

    -- Avisa os outros recursos que a HUD voltou.
    pcall(function() TriggerEvent('hudOff', false) end)
    pcall(function() TriggerEvent('hud:toggle', true) end)
    pcall(function() TriggerEvent('notify:toggle', true) end)
    pcall(function() TriggerEvent('shortcuts:toggle', true) end)
    pcall(function() TriggerEvent('chat:toggle', true) end)

    TriggerEvent('vrp:ToogleLoginMenu')
end

-- Auto-detecção dos limites
-- =====================================================================
local AXL_LIMITS_CACHE = nil

local function detectLimitsOfCurrentPed()
    local p = PlayerPedId()
    return {
        hair         = GetNumberOfPedDrawableVariations(p, 2),
        blemishes    = GetPedHeadOverlayNum(0),
        beard        = GetPedHeadOverlayNum(1),
        eyebrows     = GetPedHeadOverlayNum(2),
        ageing       = GetPedHeadOverlayNum(3),
        makeup       = GetPedHeadOverlayNum(4),
        blush        = GetPedHeadOverlayNum(5),
        complexion   = GetPedHeadOverlayNum(6),
        sundamage    = GetPedHeadOverlayNum(7),
        lipstick     = GetPedHeadOverlayNum(8),
        freckles     = GetPedHeadOverlayNum(9),
        chestHair    = GetPedHeadOverlayNum(10),
        bodyBlem     = GetPedHeadOverlayNum(11),
        bodyBlemAdd  = GetPedHeadOverlayNum(12),
        hairColors   = GetNumHairColors(),
        makeupColors = GetNumMakeupColors(),
    }
end

local function loadModelSync(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 300 do Wait(10); t = t + 1 end
    return hash
end

local function applyOverride(auto, override)
    local merged = {}
    for k, v in pairs(auto) do merged[k] = v end
    if override then
        for k, v in pairs(override) do
            if type(v) == 'table' and v.min ~= nil and v.max ~= nil then
                merged[k] = v
            end
        end
    end
    return merged
end

function getLimits()
    if AXL_LIMITS_CACHE then return AXL_LIMITS_CACHE end

    local originalModel = GetEntityModel(PlayerPedId())
    local originalIsM   = originalModel == GetHashKey('mp_m_freemode_01')

    if not originalIsM then
        loadModelSync('mp_m_freemode_01')
        SetPlayerModel(PlayerId(), GetHashKey('mp_m_freemode_01'))
        Wait(300)
    end
    local m = detectLimitsOfCurrentPed()

    loadModelSync('mp_f_freemode_01')
    SetPlayerModel(PlayerId(), GetHashKey('mp_f_freemode_01'))
    Wait(300)
    local fem = detectLimitsOfCurrentPed()

    if originalIsM then
        loadModelSync('mp_m_freemode_01')
        SetPlayerModel(PlayerId(), GetHashKey('mp_m_freemode_01'))
    end
    Wait(200)

    local maxOf = function(a, b) return (a > b) and a or b end

    local auto = {
        fathersID       = { min = 0,  max = 45 },
        mothersID       = { min = 0,  max = 45 },
        skinColor       = { min = 0,  max = 10 },
        hairModel       = { min = 0,  max = maxOf(m.hair, fem.hair) - 1 },
        firstHairColor  = { min = 0,  max = maxOf(m.hairColors, fem.hairColors) - 1 },
        secondHairColor = { min = 0,  max = maxOf(m.hairColors, fem.hairColors) - 1 },
        eyebrowsModel   = { min = -1, max = maxOf(m.eyebrows, fem.eyebrows) - 1 },
        eyebrowsColor   = { min = 0,  max = maxOf(m.hairColors, fem.hairColors) - 1 },
        beardModel      = { min = -1, max = maxOf(m.beard, fem.beard) - 1 },
        beardColor      = { min = 0,  max = maxOf(m.hairColors, fem.hairColors) - 1 },
        chestModel      = { min = -1, max = maxOf(m.chestHair, fem.chestHair) - 1 },
        chestColor      = { min = 0,  max = maxOf(m.hairColors, fem.hairColors) - 1 },
        makeupModel     = { min = -1, max = maxOf(m.makeup, fem.makeup) - 1 },
        blushModel      = { min = -1, max = maxOf(m.blush, fem.blush) - 1 },
        blushColor      = { min = 0,  max = maxOf(m.makeupColors, fem.makeupColors) - 1 },
        lipstickModel   = { min = -1, max = maxOf(m.lipstick, fem.lipstick) - 1 },
        lipstickColor   = { min = 0,  max = maxOf(m.makeupColors, fem.makeupColors) - 1 },
        blemishesModel  = { min = -1, max = maxOf(m.blemishes, fem.blemishes) - 1 },
        ageingModel     = { min = -1, max = maxOf(m.ageing, fem.ageing) - 1 },
        complexionModel = { min = -1, max = maxOf(m.complexion, fem.complexion) - 1 },
        sundamageModel  = { min = -1, max = maxOf(m.sundamage, fem.sundamage) - 1 },
        frecklesModel   = { min = -1, max = maxOf(m.freckles, fem.freckles) - 1 },
        bodyBlemishes    = { min = -1, max = maxOf(m.bodyBlem, fem.bodyBlem) - 1 },
        bodyBlemishesAdd = { min = -1, max = maxOf(m.bodyBlemAdd, fem.bodyBlemAdd) - 1 },
        eyesColor       = { min = 0,  max = 30 },
        hairHighlight   = { min = 0,  max = 1 },  -- 0=sem mecha, 1=com mecha
    }

    AXL_LIMITS_CACHE = applyOverride(auto, (Config and Config.limitsOverride) or {})

    if Config and Config.debugMode then
        print(('^5[axl_creator]^7 auto-detectados limites: cabelos=%d, barbas=%d, makeups=%d'):format(
            AXL_LIMITS_CACHE.hairModel.max + 1,
            AXL_LIMITS_CACHE.beardModel.max + 1,
            AXL_LIMITS_CACHE.makeupModel.max + 1
        ))
    end

    return AXL_LIMITS_CACHE
end

-- Reset profundo do ped
-- =====================================================================
function resetPedCompletely()
    local ped = PlayerPedId()
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    SetPedHairColor(ped, 0, 0)
    for i = 0, 12 do
        SetPedHeadOverlay(ped, i, -1, 0.0)
        SetPedHeadOverlayColor(ped, i, 0, 0, 0)
    end
    SetPedEyeColor(ped, 0)
    for i = 0, 19 do SetPedFaceFeature(ped, i, 0.0) end
    ClearAllPedProps(ped)
end

function refreshDefaultCharacter()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    ClearAllPedProps(ped)
    if startClothes[model] then
        -- Aplica direto no ped antes de mandar pelo evento.
        applyLinearClothes(ped, startClothes[model])
        Bridges.updateClothes(startClothes[model])
    else
        -- Fallback — model nao tem config (ped custom, etc)
        SetPedDefaultComponentVariation(ped)
    end
end

-- Pose do creator — ped em pé, parado, sem olhar pros lados
-- =====================================================================

local function playMugshotAnimation(ped)
    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)

    TaskStandStill(ped, -1)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

local function stopMugshotAnimation(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    ClearPedTasks(ped)
end

function changeGender(model)
    local mhash = GetHashKey(model)
    RequestModel(mhash)
    local tries = 0
    while not HasModelLoaded(mhash) and tries < 500 do Wait(10); tries = tries + 1 end
    if not HasModelLoaded(mhash) then return end

    SetPlayerModel(PlayerId(), mhash)
    -- Esconde o ped enquanto skin, rosto e roupa são aplicados.
    SetEntityVisible(PlayerPedId(), false)
    SetPedMaxHealth(PlayerPedId(), 300)
    SetEntityHealth(PlayerPedId(), 300)
    Wait(300)

    resetPedCompletely()
    refreshDefaultCharacter()

    TaskUpdateSkinOptions()
    TaskUpdateFaceOptions()
    TaskUpdateHeadOptions()

    -- Espera a roupa aplicar antes de revelar o ped.
    Wait(100)
    SetEntityVisible(PlayerPedId(), true)
    SetModelAsNoLongerNeeded(mhash)

    -- Reaplica a pose no ped novo.
    if isInCharacterMode then
        Wait(100)
        playMugshotAnimation(PlayerPedId())
    end
end

function TaskUpdateSkinOptions()
    local d = currentCharacterMode
    SetPedHeadBlendData(PlayerPedId(), d.fathersID, d.mothersID, 0, d.skinColor, 0, 0, f(d.shapeMix), 0.0, 0.0, false)
end

function TaskUpdateFaceOptions()
    local ped = PlayerPedId()
    local d   = currentCharacterMode

    SetPedEyeColor(ped, d.eyesColor)
    SetPedFaceFeature(ped, 6,  f(d.eyebrowsHeight or 0))
    SetPedFaceFeature(ped, 7,  f(d.eyebrowsWidth or 0))
    SetPedFaceFeature(ped, 0,  f(d.noseWidth or 0))
    SetPedFaceFeature(ped, 1,  f(d.noseHeight or 0))
    SetPedFaceFeature(ped, 2,  f(d.noseLength or 0))
    SetPedFaceFeature(ped, 3,  f(d.noseBridge or 0))
    SetPedFaceFeature(ped, 4,  f(d.noseTip or 0))
    SetPedFaceFeature(ped, 5,  f(d.noseShift or 0))
    SetPedFaceFeature(ped, 8,  f(d.cheekboneHeight or 0))
    SetPedFaceFeature(ped, 9,  f(d.cheekboneWidth or 0))
    SetPedFaceFeature(ped, 10, f(d.cheeksWidth or 0))
    SetPedFaceFeature(ped, 11, f(d.eyesOpening or 0))
    SetPedFaceFeature(ped, 12, f(d.lips or 0))
    SetPedFaceFeature(ped, 13, f(d.jawWidth or 0))
    SetPedFaceFeature(ped, 14, f(d.jawHeight or 0))
    SetPedFaceFeature(ped, 15, f(d.chinLength or 0))
    SetPedFaceFeature(ped, 16, f(d.chinPosition or 0))
    SetPedFaceFeature(ped, 17, f(d.chinWidth or 0))
    SetPedFaceFeature(ped, 18, f(d.chinShape or 0))
    SetPedFaceFeature(ped, 19, f(d.neckWidth or 0))
end

function TaskUpdateHeadOptions()
    local ped = PlayerPedId()
    local d   = currentCharacterMode

    SetPedComponentVariation(ped, 2, d.hairModel, 0, 0)

    -- Mecha: 0 usa uma cor só, 1 usa a segunda cor.
    local hl = d.hairHighlight or 1
    if hl == 0 then
        SetPedHairColor(ped, d.firstHairColor, d.firstHairColor)
    else
        SetPedHairColor(ped, d.firstHairColor, d.secondHairColor)
    end

    SetPedHeadOverlay(ped, 2, d.eyebrowsModel, 0.99)
    SetPedHeadOverlayColor(ped, 2, 1, d.eyebrowsColor, d.eyebrowsColor)
    SetPedHeadOverlay(ped, 1, d.beardModel, 0.99)
    SetPedHeadOverlayColor(ped, 1, 1, d.beardColor, d.beardColor)
    SetPedHeadOverlay(ped, 10, d.chestModel, 0.99)
    SetPedHeadOverlayColor(ped, 10, 1, d.chestColor, d.chestColor)
    SetPedHeadOverlay(ped, 5, d.blushModel, 0.99)
    SetPedHeadOverlayColor(ped, 5, 2, d.blushColor, d.blushColor)
    SetPedHeadOverlay(ped, 8, d.lipstickModel, 0.99)
    SetPedHeadOverlayColor(ped, 8, 2, d.lipstickColor, d.lipstickColor)
    SetPedHeadOverlay(ped, 0, d.blemishesModel, 0.99)
    SetPedHeadOverlayColor(ped, 0, 0, 0, 0)
    SetPedHeadOverlay(ped, 3, d.ageingModel, 0.99)
    SetPedHeadOverlayColor(ped, 3, 0, 0, 0)
    SetPedHeadOverlay(ped, 6, d.complexionModel, 0.99)
    SetPedHeadOverlayColor(ped, 6, 0, 0, 0)
    SetPedHeadOverlay(ped, 7, d.sundamageModel, 0.99)
    SetPedHeadOverlayColor(ped, 7, 0, 0, 0)
    SetPedHeadOverlay(ped, 9, d.frecklesModel, 0.99)
    SetPedHeadOverlayColor(ped, 9, 0, 0, 0)
    SetPedHeadOverlay(ped, 4, d.makeupModel, 0.99)
    SetPedHeadOverlayColor(ped, 4, 0, 0, 0)
    -- Manchas e cicatrizes no corpo.
    SetPedHeadOverlay(ped, 11, d.bodyBlemishes or -1, 0.99)
    SetPedHeadOverlayColor(ped, 11, 0, 0, 0)
    SetPedHeadOverlay(ped, 12, d.bodyBlemishesAdd or -1, 0.99)
    SetPedHeadOverlayColor(ped, 12, 0, 0, 0)
end

-- Geração do ancoramento no estúdio. Subir o número mata a thread anterior.
local studioAnchorGen = 0

local function stopStudioAnchor()
    studioAnchorGen = studioAnchorGen + 1
end

-- loadCutSine — spawn depois de criar o personagem
-- =====================================================================
function loadCutSine()

    -- A âncora do estúdio ainda pode estar viva e puxaria o player de volta.
    stopStudioAnchor()

    -- Trava input enquanto cinematic roda
    lockReturningHud()

    releaseBootLock()

    local fin = Config.coords.finalSpawn
    local ped = PlayerPedId()

    -- Fecha a NUI e aplica a roupa inicial.
    if isInCharacterMode then
        isInCharacterMode = false
        SetNuiFocus(false, false)
        SendNUIMessage({ screen = 'hidden' })
        if startClothes[GetEntityModel(ped)] then
            Bridges.updateClothes(startClothes[GetEntityModel(ped)])
        end
        AXL_CREATE_MODE = 'new'
    end

    stopMugshotAnimation(ped)

    if DoesCamExist(cam) then
        SetCamActive(cam, false)
        RenderScriptCams(false, false, 0, 1, 0)
        DestroyCam(cam, false)
        cam = nil
    end

    -- Fade out e um tempo pra roupa aplicar antes da cinematic.
    DoScreenFadeOut(400)
    Wait(500)

    local ok, err = pcall(function()
        if exports['axl_spawn'] and exports['axl_spawn'].cinematicSpawn then
            exports['axl_spawn']:cinematicSpawn(fin.x, fin.y, fin.z, {
                heading    = f(fin.h),
                tag        = 'firstspawn',
                clothesBuf = 2500,
            })
        else
            error('axl_spawn:cinematicSpawn export indisponível')
        end
    end)
    if not ok then
        print(('^1[axl_creator]^7 loadCutSine: erro no export — %s'):format(tostring(err)))
        -- Fallback mínimo: garantir que player não fica travado
        SetEntityCoordsNoOffset(ped, fin.x, fin.y, fin.z, false, false, false)
        SetEntityHeading(ped, f(fin.h))
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        SetEntityInvincible(ped, false)
        SetEntityCollision(ped, true, true)
        SetPlayerControl(PlayerId(), true, 0)
        DoScreenFadeIn(800)
    end

    AXL_RETURNING_LOCKED = false

    Bridges.toggleHud(true)
    Bridges.toggleNotify(true)
    Bridges.toggleChat(true)
    Bridges.toggleShortcuts(true)
    DisplayRadar(true)
    DisplayHud(true)

    pcall(function() TriggerEvent('hudOff', false) end)
    pcall(function() TriggerEvent('hud:toggle', true) end)
    pcall(function() TriggerEvent('notify:toggle', true) end)
    pcall(function() TriggerEvent('shortcuts:toggle', true) end)
    pcall(function() TriggerEvent('chat:toggle', true) end)
end

-- Abre o creator — leva o player pro estúdio e monta a interface
-- =====================================================================
function TriggerCreateCharacter()

    Bridges.toggleHud(false)
    Bridges.toggleNotify(false)
    Bridges.toggleChat(false)
    Bridges.toggleShortcuts(false)

    isInCharacterMode = true

    local cachedLimits = getLimits()


    SetEntityVisible(PlayerPedId(), false)
    changeGender('mp_m_freemode_01')
    actual_gender = 'mp_m_freemode_01'
    -- changeGender chama SetEntityVisible(true) no fim — re-esconde
    SetEntityVisible(PlayerPedId(), false)
    Wait(200)
    resetPedCompletely()
    refreshDefaultCharacter()
    TaskUpdateSkinOptions()
    TaskUpdateFaceOptions()
    TaskUpdateHeadOptions()
    SetEntityVisible(PlayerPedId(), false)

    local s = Config.coords.studio
    SetEntityCoordsNoOffset(PlayerPedId(), s.x, s.y, s.z, true, true, true)
    SetEntityHeading(PlayerPedId(), f(s.h))
    TriggerCamController(doStatus)
    -- Solta os locks, mas o ped continua invisível.
    if releaseSwapLock then releaseSwapLock() end
    releaseBootLock()
    -- releaseBootLock faz SetEntityVisible(true) — re-esconde IMEDIATAMENTE
    SetEntityVisible(PlayerPedId(), false)
    SetEntityCollision(PlayerPedId(), true, true)
    FreezeEntityPosition(PlayerPedId(), false)

    -- Abre a NUI antes do fade in: ela cobre a tela inteira.
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'unlock' })
    SendNUIMessage({ action = 'resetCharacter' })
    SendNUIMessage({
        branding      = Config.branding,
        starterCars   = getEnrichedStarterCars(),
        limits        = cachedLimits,
        idade         = Config.idade,
        texts         = Config.texts,
        theme         = Config.theme,
        creatorCamera = Config.creatorCamera,
        whitelistFundo= Config.whitelistFundo,
        mode          = AXL_CREATE_MODE or 'new',
        skipWL        = AXL_SKIP_WL == true,
    })

    local startScreen = (AXL_CREATE_MODE == 'reset') and 'face' or 'transition'
    SendNUIMessage({ screen = startScreen, userId = (vSERVER.getUserId() or 0) })

    -- Espera a NUI montar antes do fade in.
    Wait(150)
    DoScreenFadeIn(400)

    -- No modo 'reset' a NUI pula a transition, então chama na mão.
    if AXL_CREATE_MODE == 'reset' then
        Citizen.CreateThread(function()
            Wait(200)
            runBeginCreator()
        end)
    end

    playMugshotAnimation(PlayerPedId())

    -- Segura o ped no estúdio por 7s: a troca de modelo faz ele derivar.
    studioAnchorGen = studioAnchorGen + 1
    local minhaGen = studioAnchorGen
    CreateThread(function()
        local executionCount = 0
        while executionCount < 7 do
            -- Terminou o creator antes dos 7s? A geração mudou, some daqui.
            if studioAnchorGen ~= minhaGen then return end
            if #(GetEntityCoords(PlayerPedId()) - vector3(s.x, s.y, s.z)) > 9.0 then
                SetEntityCoordsNoOffset(PlayerPedId(), s.x, s.y, s.z, true, true, true)
                SetEntityHeading(PlayerPedId(), f(s.h))
            end
            executionCount = executionCount + 1
            Wait(1000)
        end
    end)
end

-- NUI Callbacks
-- =====================================================================
-- runBeginCreator — monta o ped do creator.
-- revelar = false monta escondido; sem parâmetro, revela no fim.
function runBeginCreator(revelar)
    resetPedCompletely()
    refreshDefaultCharacter()
    TaskUpdateSkinOptions()
    TaskUpdateFaceOptions()
    TaskUpdateHeadOptions()
    SetEntityVisible(PlayerPedId(), revelar ~= false)
    SetNuiFocus(isInCharacterMode, isInCharacterMode)

    -- Reaplica a roupa algumas vezes: o vRP pode sobrescrever depois.
    Citizen.CreateThread(function()
        local passada = 0
        while isInCharacterMode do
            Wait(250)
            if not isInCharacterMode then break end

            local ped   = PlayerPedId()
            local model = GetEntityModel(ped)
            local cfg   = (Config and Config.startClothes) or nil
            local entry11 = nil
            if model == `mp_m_freemode_01` and cfg and cfg.male then
                entry11 = cfg.male[11]
            elseif model == `mp_f_freemode_01` and cfg and cfg.female then
                entry11 = cfg.female[11]
            end

            local d, t
            if entry11 and type(entry11) == 'table' then
                d = tonumber(entry11[1]) or 0
                t = tonumber(entry11[2]) or 0
            end

            -- O setCustomization do vRP chega quando quiser, então o torso fica
            -- vigiado enquanto o creator está aberto, não só nos 2s iniciais.
            local trocou = d and (GetPedDrawableVariation(ped, 11) ~= d
                                  or GetPedTextureVariation(ped, 11) ~= t)

            passada = passada + 1
            if passada <= 8 or trocou then
                refreshDefaultCharacter()
                if d then SetPedComponentVariation(ped, 11, d, t, 2) end
            end
        end
    end)
end

RegisterNUICallback('beginCreator', function(data, cb)
    cb({})
    runBeginCreator(not (data and data.revelar == false))
end)

-- Mostra o personagem quando a etapa de aparência abre.
RegisterNUICallback('revelarPed', function(data, cb)
    cb({})
    SetEntityVisible(PlayerPedId(), true)
end)

-- Cenário da whitelist — câmera girando num ponto do mapa
-- ---------------------------------------------------------------------
local camWhitelist = nil
local girandoWhitelist = false

local function pararCenarioWhitelist()
    girandoWhitelist = false
    if camWhitelist then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(camWhitelist, false)
        camWhitelist = nil
    end
end

RegisterNUICallback('cenarioWhitelist', function(data, cb)
    cb({})

    local cfg = (Config and Config.whitelistFundo) or {}
    if cfg.fundo ~= 'cenario' then return end

    local c = cfg.cam  or { x = 0.0, y = 0.0, z = 100.0 }
    local a = cfg.alvo or { x = 0.0, y = 0.0, z = 0.0 }

    pararCenarioWhitelist()
    camWhitelist = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camWhitelist, c.x + 0.0, c.y + 0.0, c.z + 0.0)
    PointCamAtCoord(camWhitelist, a.x + 0.0, a.y + 0.0, a.z + 0.0)
    SetCamActive(camWhitelist, true)
    RenderScriptCams(true, true, 800, true, true)

    SetEntityVisible(PlayerPedId(), false)

    if cfg.girar == false then return end

    girandoWhitelist = true
    Citizen.CreateThread(function()
        local ang = 0.0
        local raio = 0.0
        local dx, dy = c.x - a.x, c.y - a.y
        raio = math.sqrt(dx*dx + dy*dy)
        ang = math.deg(math.atan(dy, dx))

        local passo = tonumber(cfg.velocidadeGiro) or 1.2
        while girandoWhitelist and camWhitelist do
            Citizen.Wait(30)
            ang = ang + passo * 0.03
            local r = math.rad(ang)
            SetCamCoord(camWhitelist,
                a.x + math.cos(r) * raio,
                a.y + math.sin(r) * raio,
                c.z)
            PointCamAtCoord(camWhitelist, a.x + 0.0, a.y + 0.0, a.z + 0.0)
        end
    end)
end)

RegisterNUICallback('fecharCenarioWhitelist', function(data, cb)
    cb({})
    pararCenarioWhitelist()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then pararCenarioWhitelist() end
end)

RegisterNUICallback('wlApprovedSpawn', function(data, cb)
    cb({})

    if AXL_CREATE_MODE == 'resumeWl' then
        AXL_CREATE_MODE = 'new'
        isInCharacterMode = false
        SetNuiFocus(false, false)
        SendNUIMessage({ screen = 'hidden' })
        TriggerServerEvent('axl_creator:resumeWlApproved')
        return
    end

    -- Showroom: volta o player pro lugar onde ele estava.
    if AXL_CREATE_MODE == 'showroom' then
        stopStudioAnchor()
        StartFade()
        isInCharacterMode = false
        SetNuiFocus(false, false)
        SendNUIMessage({ screen = 'hidden' })

        stopMugshotAnimation(PlayerPedId())

        if startClothes[GetEntityModel(PlayerPedId())] then
            Bridges.updateClothes(startClothes[GetEntityModel(PlayerPedId())])
        end

        local r = AXL_SHOWROOM_RETURN or Config.coords.finalSpawn
        local ped = PlayerPedId()
        -- A nativa recebe (x, y, z) — passe as coords, não o ped.
        RequestCollisionAtCoord(r.x, r.y, r.z)
        SetEntityCoordsNoOffset(ped, r.x, r.y, r.z, false, false, false)
        SetEntityHeading(ped, f(r.h or 0.0))
        SetEntityVisible(ped, true)

        -- Espera colisão carregar
        local tries = 0
        while not HasCollisionLoadedAroundEntity(ped) and tries < 60 do
            Wait(50); tries = tries + 1
        end

        if DoesCamExist(cam) then
            RenderScriptCams(false, false, 0, 1, 0)
            DestroyCam(cam, false); cam = nil
        end
        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(0.0, 1.0)
        SetFocusEntity(ped)

        -- Re-habilita HUD
        Bridges.toggleHud(true)
        Bridges.toggleNotify(true)
        Bridges.toggleChat(true)
        Bridges.toggleShortcuts(true)
        DisplayRadar(true)

        EndFade()
        AXL_CREATE_MODE = 'new'
        AXL_SHOWROOM_RETURN = nil
        return
    end

    -- Personagem novo: quem libera a entrada é o servidor.
    TriggerServerEvent('axl_creator:requestSpawn')
end)

-- axl_creator:approvedSpawn — servidor confirmou a WL, pode entrar
-- =====================================================================
RegisterNetEvent('axl_creator:approvedSpawn')
AddEventHandler('axl_creator:approvedSpawn', function()
    loadCutSine()
end)

-- axl_creator:spawnDenied — servidor recusou a entrada
-- =====================================================================
RegisterNetEvent('axl_creator:spawnDenied')
AddEventHandler('axl_creator:spawnDenied', function()
    isInCharacterMode = true
    SetNuiFocus(true, true)
    -- Passa por 'hidden' pra tela de whitelist remontar do zero.
    SendNUIMessage({ screen = 'hidden' })
    Citizen.SetTimeout(50, function()
        SendNUIMessage({ screen = 'whitelist' })
    end)
    TriggerEvent('Notify', 'negado', 'Sua whitelist ainda nao foi aprovada.', 8)
end)

RegisterNUICallback('finishWhitelist', function(data, cb) cb({}) end)

RegisterNUICallback('resetChar', function(data, cb)
    cb({})
    ClearAllPedProps(PlayerPedId())
    changeGender('mp_m_freemode_01')
end)

RegisterNUICallback('changeGender', function(data, cb)
    cb({})
    if tonumber(data.sex) == 1 then
        changeGender('mp_m_freemode_01'); actual_gender = 'mp_m_freemode_01'
    else
        changeGender('mp_f_freemode_01'); actual_gender = 'mp_f_freemode_01'
    end
end)

RegisterNUICallback('verify', function(data, cb)
    -- No showroom a verificação é só visual.
    if AXL_CREATE_MODE == 'showroom' then return cb({ whitelisted = true }) end
    if vSERVER.checkWhitelist() then return cb({ whitelisted = true }) end
    return cb({ whitelisted = false })
end)

RegisterNUICallback('notify', function(data, cb)
    cb({})
    TriggerEvent('Notify', data.type, data.message, 5)
end)

RegisterNUICallback('goToFace',    function(data, cb) cb({}); SendNUIMessage({ screen = 'face' })    end)
RegisterNUICallback('goToHead',    function(data, cb) cb({}); SendNUIMessage({ screen = 'head' })    end)
RegisterNUICallback('goToConfirm', function(data, cb) cb({}); SendNUIMessage({ screen = 'confirm' }) end)
RegisterNUICallback('backToWhitelist', function(data, cb) cb({}); SendNUIMessage({ screen = 'whitelist' }) end)
RegisterNUICallback('backToFace',  function(data, cb) cb({}); SendNUIMessage({ screen = 'face' }) end)
RegisterNUICallback('backToHead',  function(data, cb) cb({}); SendNUIMessage({ screen = 'head' }) end)

-- ALEATORIZAR — sorteia features dentro dos limites detectados
-- =====================================================================
RegisterNUICallback('randomizeChar', function(data, cb)
    cb({})

    local L = AXL_LIMITS_CACHE or {}
    local function randInt(key, fallbackMin, fallbackMax)
        local lim = L[key]
        local mn = lim and lim.min or fallbackMin
        local mx = lim and lim.max or fallbackMax
        return math.random(mn, mx)
    end
    local function randFloat(min, max)
        return min + math.random() * (max - min)
    end

    -- Pele + DNA
    currentCharacterMode.fathersID = randInt('fathersID', 0, 45)
    currentCharacterMode.mothersID = randInt('mothersID', 0, 45)
    currentCharacterMode.skinColor = randInt('skinColor', 0, 10)
    currentCharacterMode.shapeMix  = randFloat(0, 1)

    -- Olhos
    currentCharacterMode.eyesColor      = randInt('eyesColor', 0, 30)
    currentCharacterMode.eyesOpening    = randFloat(-0.3, 0.3)

    -- Sobrancelhas
    currentCharacterMode.eyebrowsModel  = randInt('eyebrowsModel', -1, 33)
    currentCharacterMode.eyebrowsColor  = randInt('eyebrowsColor', 0, 30)
    currentCharacterMode.eyebrowsHeight = randFloat(-0.5, 0.5)
    currentCharacterMode.eyebrowsWidth  = randFloat(-0.5, 0.5)

    -- Cabelo
    currentCharacterMode.hairModel       = randInt('hairModel', 0, 40)
    currentCharacterMode.firstHairColor  = randInt('firstHairColor', 0, 30)
    currentCharacterMode.secondHairColor = randInt('secondHairColor', 0, 30)
    currentCharacterMode.hairHighlight   = math.random(0, 1) -- 0=sem mecha, 1=com mecha

    -- Barba (só se masculino)
    if actual_gender == 'mp_m_freemode_01' then
        currentCharacterMode.beardModel = randInt('beardModel', -1, 28)
        currentCharacterMode.beardColor = randInt('beardColor', 0, 30)
    else
        currentCharacterMode.beardModel = -1
    end

    -- Traços do rosto, em range moderado.
    for _, k in ipairs({
        'noseWidth','noseHeight','noseLength','noseBridge','noseTip','noseShift',
        'cheekboneHeight','cheekboneWidth','cheeksWidth',
        'lips','jawWidth','jawHeight',
        'chinLength','chinPosition','chinWidth','chinShape',
        'neckWidth',
    }) do
        currentCharacterMode[k] = randFloat(-0.4, 0.4)
    end

    -- Aplica tudo
    TaskUpdateSkinOptions()
    TaskUpdateFaceOptions()
    TaskUpdateHeadOptions()

    -- Manda pra NUI atualizar os sliders
    SendNUIMessage({ action = 'syncCharacter', character = currentCharacterMode })
end)

-- Salvar personagem
-- =====================================================================
RegisterNUICallback('cDoneSave', function(data, cb)
    cb({})

    if startClothes[GetEntityModel(PlayerPedId())] then
        Bridges.updateClothes(startClothes[GetEntityModel(PlayerPedId())])
    end

    data.mode = AXL_CREATE_MODE or 'new'
    data.model = (actual_gender == 'mp_f_freemode_01') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    TriggerServerEvent('axl_creator:finishedCharacter', currentCharacterMode, vRP.getCustomization(), data)

    if AXL_CREATE_MODE == 'reset' then
        StartFade()
        isInCharacterMode = false
        SetNuiFocus(false, false)
        SendNUIMessage({ screen = 'hidden' })

        local p = Config.coords.finalSpawn
        SetEntityCoordsNoOffset(PlayerPedId(), p.x, p.y, p.z, true, true, true)
        SetEntityHeading(PlayerPedId(), f(p.h))

        loadCutSine()
        AXL_CREATE_MODE = 'new'
    end
end)

RegisterNUICallback('cChangeHeading', function(data, cb)
    cb('ok')
    SetEntityHeading(PlayerPedId(), f(data.camRotation))
end)

local CAM_DISTANCE = (Config and Config.camera and Config.camera.initialDistance) or 1.4
local CAM_ALTURA   = 0.0

-- Botão direito: orbita a câmera em volta do personagem e sobe/desce, sem
-- girar o ped.
RegisterNUICallback('camLivre', function(data, cb)
    cb('ok')
    if not DoesCamExist(cam) then return end

    local ped      = PlayerPedId()
    local headBone = GetPedBoneIndex(ped, 0x796E)
    local headPos  = GetWorldPositionOfEntityBone(ped, headBone)
    local hx, hy, hz = headPos.x, headPos.y, headPos.z

    local camPos = GetCamCoord(cam)
    local vx, vy = camPos.x - hx, camPos.y - hy
    local raio   = math.sqrt(vx * vx + vy * vy)
    if raio < 0.001 then raio = CAM_DISTANCE end

    local c   = (Config and Config.camera) or {}
    local giro = (tonumber(data and data.dx) or 0) * (c.orbitSpeed or 0.4)
    local sobe = (tonumber(data and data.dy) or 0) * (c.heightSpeed or 0.004)

    local ang = math.atan(vy, vx) + math.rad(giro)
    CAM_ALTURA = math.max(c.heightMin or -1.1, math.min(c.heightMax or 0.6, CAM_ALTURA + sobe))

    local alvoZ = hz + CAM_ALTURA
    SetCamCoord(cam, hx + math.cos(ang) * raio, hy + math.sin(ang) * raio, alvoZ)
    PointCamAtCoord(cam, hx, hy, alvoZ)
end)

RegisterNUICallback('camZoom', function(data, cb)
    cb('ok')
    if not DoesCamExist(cam) then return end

    local ped      = PlayerPedId()
    local headBone = GetPedBoneIndex(ped, 0x796E)
    local headPos  = GetWorldPositionOfEntityBone(ped, headBone)
    local hx, hy, hz = headPos.x, headPos.y, headPos.z

    local camPos = GetCamCoord(cam)
    local dx, dy, dz = camPos.x - hx, camPos.y - hy, camPos.z - hz
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len < 0.001 then return end
    local nx, ny, nz = dx/len, dy/len, dz/len

    local step = (Config and Config.camera and Config.camera.zoomStep) or 0.3
    CAM_DISTANCE = math.max(0.6, math.min(3.5, len + (data.delta or step)))

    SetCamCoord(cam,
        hx + nx * CAM_DISTANCE,
        hy + ny * CAM_DISTANCE,
        hz + nz * CAM_DISTANCE)
    PointCamAtCoord(cam, hx, hy, hz)
end)

RegisterNUICallback('openDiscord', function(data, cb)
    cb('ok')
    local url = data.url or ''
    if url == '' or url:find('SEU_LINK') then
        TriggerEvent('Notify', 'negado', 'URL do Discord nao configurada.', 7)
        return
    end
    SendNUIMessage({ copyToClipboard = url })
    TriggerEvent('Notify', 'sucesso', 'Link copiado: ' .. url, 7)
end)

-- Lock helpers — usados pelos flows internos de swap/spawn
-- =====================================================================

AXL_SWAP_LOCK_UNTIL = 0
function prepareClientForSwap()
    DoScreenFadeOut(0)
    SetNuiFocus(false, false)
    SendNUIMessage({ screen = 'hidden' })
    local ped = PlayerPedId()
    SetEntityVisible(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)


    AXL_SWAP_LOCK_UNTIL = GetGameTimer() + 4000
    CreateThread(function()
        while GetGameTimer() < AXL_SWAP_LOCK_UNTIL do
            local p = PlayerPedId()
            if not IsScreenFadedOut() and not IsScreenFadingOut() then
                DoScreenFadeOut(0)
            end
            if IsEntityVisible(p) then SetEntityVisible(p, false) end
            Wait(50)
        end

        local p = PlayerPedId()
        SetEntityVisible(p, true)
        FreezeEntityPosition(p, false)
        SetEntityCollision(p, true, true)
        SetEntityInvincible(p, false)
        if IsScreenFadedOut() then DoScreenFadeIn(500) end
    end)
end

function releaseSwapLock()
    AXL_SWAP_LOCK_UNTIL = 0
end

-- Atualização de features via NUI
-- =====================================================================
RegisterNUICallback('UpdateSkinOptions', function(data, cb)
    cb('ok')
    currentCharacterMode.fathersID = data.fathersID
    currentCharacterMode.mothersID = data.mothersID
    currentCharacterMode.skinColor = data.skinColor
    currentCharacterMode.shapeMix  = data.shapeMix
    TaskUpdateSkinOptions()
end)

RegisterNUICallback('UpdateFaceOptions', function(data, cb)
    cb('ok')
    for _, key in ipairs({
        'eyesColor','eyesOpening',
        'eyebrowsHeight','eyebrowsWidth',
        'noseWidth','noseHeight','noseLength','noseBridge','noseTip','noseShift',
        'cheekboneHeight','cheekboneWidth','cheeksWidth',
        'lips','jawWidth','jawHeight',
        'chinLength','chinPosition','chinWidth','chinShape',
        'neckWidth',
    }) do
        if data[key] ~= nil then currentCharacterMode[key] = data[key] end
    end
    TaskUpdateFaceOptions()
end)

RegisterNUICallback('UpdateHeadOptions', function(data, cb)
    cb('ok')
    for _, key in ipairs({
        'hairModel','firstHairColor','secondHairColor','hairHighlight',
        'eyebrowsModel','eyebrowsColor',
        'beardModel','beardColor',
        'chestModel','chestColor',
        'blushModel','blushColor',
        'lipstickModel','lipstickColor',
        'blemishesModel','ageingModel','complexionModel','sundamageModel',
        'frecklesModel','makeupModel',
        'bodyBlemishes','bodyBlemishesAdd',
    }) do
        if data[key] ~= nil then currentCharacterMode[key] = data[key] end
    end
    TaskUpdateHeadOptions()
end)

-- Roupas iniciais
-- =====================================================================
RegisterNetEvent('Character:UpdateClothes', function(custom)
    local ped = PlayerPedId()

    if not isInCharacterMode and GetEntityHealth(ped) <= 101 then return end

    if custom[1] == -1 then SetPedComponentVariation(ped, 1, 0, 0, 2) else SetPedComponentVariation(ped, 1, custom[1], custom[2], 2) end
    if custom[3] == -1 then SetPedComponentVariation(ped, 5, 0, 0, 2) else SetPedComponentVariation(ped, 5, custom[3], custom[4], 2) end
    if custom[5] == -1 then SetPedComponentVariation(ped, 7, 0, 0, 2) else SetPedComponentVariation(ped, 7, custom[5], custom[6], 2) end
    if custom[7] == -1 then SetPedComponentVariation(ped, 3, 15, 0, 2) else SetPedComponentVariation(ped, 3, custom[7], custom[8], 2) end
    if custom[9] == -1 then
        if GetEntityModel(ped) == GetHashKey('mp_m_freemode_01') then SetPedComponentVariation(ped, 4, 18, 0, 2) else SetPedComponentVariation(ped, 4, 15, 0, 2) end
    else SetPedComponentVariation(ped, 4, custom[9], custom[10], 2) end
    if custom[11] == -1 then SetPedComponentVariation(ped, 8, 15, 0, 2) else SetPedComponentVariation(ped, 8, custom[11], custom[12], 2) end
    if custom[13] == -1 then
        if GetEntityModel(ped) == GetHashKey('mp_m_freemode_01') then SetPedComponentVariation(ped, 6, 34, 0, 2) else SetPedComponentVariation(ped, 6, 35, 0, 2) end
    else SetPedComponentVariation(ped, 6, custom[13], custom[14], 2) end
    if custom[15] == -1 then SetPedComponentVariation(ped, 11, 15, 0, 2) else SetPedComponentVariation(ped, 11, custom[15], custom[16], 2) end
    if custom[17] == -1 then SetPedComponentVariation(ped, 9, 0, 0, 2) else SetPedComponentVariation(ped, 9, custom[17], custom[18], 2) end
    if custom[19] == -1 then SetPedComponentVariation(ped, 10, 0, 0, 2) else SetPedComponentVariation(ped, 10, custom[19], custom[20], 2) end

    for i, prop in ipairs({ { idx = 0, c = 21 }, { idx = 1, c = 23 }, { idx = 2, c = 25 }, { idx = 6, c = 27 }, { idx = 7, c = 29 } }) do
        if custom[prop.c] == -1 then ClearPedProp(ped, prop.idx) else SetPedPropIndex(ped, prop.idx, custom[prop.c], custom[prop.c + 1], 2) end
    end
end)

-- Comandos CLIENT
-- =====================================================================
local function clientCmdAbrirCreator(source, args)
    TriggerServerEvent('axl_creator:runCommand', 'openCreator', args or {})
end

local function clientCmdResetChar(source, args)
    TriggerServerEvent('axl_creator:runCommand', 'resetChar', args or {})
end
CreateThread(function()
    Wait(500)
    if Config and Config.commands then
        if Config.commands.openCreator ~= '' then
            RegisterCommand(Config.commands.openCreator, clientCmdAbrirCreator, false)
        end
        if Config.commands.resetChar ~= '' then
            RegisterCommand(Config.commands.resetChar, clientCmdResetChar, false)
        end
        if Config.debugMode then
            print(('^5[axl_creator:client]^7 comandos: /%s, /%s'):format(
                Config.commands.openCreator,
                Config.commands.resetChar))
        end
    end
end)

-- Notify interno
-- =====================================================================
RegisterNetEvent('axl_creator:internalNotify')
AddEventHandler('axl_creator:internalNotify', function(notifyType, message, duration)
    SendNUIMessage({
        toast = {
            type     = notifyType,
            message  = message,
            duration = (duration or 5) * 1000,
        },
    })
end)

CreateThread(function()
    Wait(500)
    SendNUIMessage({ action = 'unlock' })
end)
