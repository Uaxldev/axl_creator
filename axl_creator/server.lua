AddEventHandler("onResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    print("^6[UnityDev - Axldev] axl_creator: ^2Autenticacao completa^0")
end)

-- axl_creator (server) — creator de personagem, whitelist e spawn inicial.
local Tunnel = module('vrp', 'lib/Tunnel')
local Proxy  = module('vrp', 'lib/Proxy')

vRP       = Proxy.getInterface('vRP')
vRPclient = Tunnel.getInterface('vRP')

src = {}
Tunnel.bindInterface(GetCurrentResourceName(), src)

local inCreator          = {}
local WhitelistPending   = {}
local finishingCharacter = {}

-- Modo em que o creator foi aberto: 'new', 'reset', 'showroom' ou 'resume'.
-- Definido no servidor, nunca vem do cliente.
local creatorMode        = {}

-- Quem terminou o creator e está esperando a whitelist liberar o spawn.
local awaitingWlSpawn    = {}

-- Lock em memória pra não entregar as recompensas duas vezes.
local deliveringRewards  = {}
-- Dedupe por source, feito antes de qualquer chamada que possa dar yield.
local finishingCharacterBySource = {}
local discordAuthEnabled = false

-- Players que entraram no flow e ainda não chegaram num estado conhecido.
-- Quem passar do timeout abaixo leva kick.
local AWAITING_FLOW = {} -- user_id → timestamp (os.time())
local AWAITING_FLOW_TIMEOUT_SEC = 300 -- 5 minutos

-- Tempo de cada fase do connect. Ative com /debugcreator on no console.
local FLOW_TIMING = {} -- user_id → { phase_name = start_timestamp_ms }

local function telemetry(user_id, phase, status, extra)
    local duration_ms = 0
    if FLOW_TIMING[user_id] and FLOW_TIMING[user_id][phase] then
        duration_ms = GetGameTimer() - FLOW_TIMING[user_id][phase]
        FLOW_TIMING[user_id][phase] = nil
    end

    local shouldPrint = Config.debugMode or duration_ms > 1000 or status == 'fail'
    if not shouldPrint then return end

    local color = '^2'
    if status == 'fail' then color = '^1'
    elseif duration_ms > 1000 then status = 'slow'; color = '^3'
    end

    print(('%s[telemetry]^7 user_id=%s phase=%s duration_ms=%d status=%s%s'):format(
        color, tostring(user_id), phase, duration_ms, status,
        extra and (' ' .. tostring(extra)) or ''))
end

local function telemetryStart(user_id, phase)
    if not FLOW_TIMING[user_id] then FLOW_TIMING[user_id] = {} end
    FLOW_TIMING[user_id][phase] = GetGameTimer()
end

local function markFlowStart(user_id)
    if user_id and user_id > 0 then
        AWAITING_FLOW[user_id] = os.time()
        telemetryStart(user_id, 'connect_to_state')
    end
end

local function markFlowResolved(user_id)
    if user_id and AWAITING_FLOW[user_id] then
        AWAITING_FLOW[user_id] = nil
        telemetry(user_id, 'connect_to_state', 'ok')
    end
end

-- Lookup dos carros iniciais liberados, montada a partir de Config.starterCars.
local carrosIniciais = {}
if not Config then
    print('^1[axl_creator]^7 ERRO: Config é nil ao carregar server.lua. shared_scripts não carregaram primeiro?')
end
for _, car in ipairs((Config and Config.starterCars) or {}) do
    if type(car) == 'table' and car.id then
        carrosIniciais[car.id] = true
    end
end

-- Entrega dinheiro, itens e VIP iniciais. Roda quando o creator abre.
-- Entrega uma vez só por personagem, marcado em UData.
local function deliverStarterRewardsInner(user_id)

    -- Já entregue antes? Sai.
    local already = vRP.getUData(user_id, "axl_creator:rewards_delivered")
    if already == "1" or already == "true" then
        deliveringRewards[user_id] = nil
        if Config.debugMode then
            print(('^5[axl_creator]^7 starter rewards ja entregues pra user_id=%s — skip'):format(user_id))
        end
        return
    end

    -- Só entrega pra quem está com o inventário vazio.
    local existingInv = vRP.getInventory and vRP.getInventory(user_id)
    if type(existingInv) == 'table' and next(existingInv) ~= nil then
        vRP.setUData(user_id, "axl_creator:rewards_delivered", "1")
        deliveringRewards[user_id] = nil
        print(('^3[axl_creator]^7 user_id=%s ja tem itens no inventario — starter rewards nao entregues (conta existente)'):format(user_id))
        return
    end

    -- Inicializa o inventário antes de entregar os itens.
    -- Sem isso o axl_inventory apaga o que acabou de ser dado.
    pcall(function()
        if vRP.clearInventory then
            vRP.clearInventory(user_id)
        else
            -- Fallback se a base não tiver clearInventory.
            vRP.replaceInventory(user_id, {})
        end
    end)
    -- Espera o axl_inventory terminar de limpar antes de entregar os itens.
    Wait(150)

    local _inv_check = vRP.getInventory and vRP.getInventory(user_id)
    if not _inv_check and vRP.replaceInventory then
        vRP.replaceInventory(user_id, {})
    end
    if Config.debugMode then
        print(('^5[axl_creator]^7 inventory inicializado (cache + data) pra user_id=%s'):format(user_id))
    end

    -- Dinheiro inicial.
    if Config.rewards.money and Config.rewards.money > 0 then
        local okMoney, errMoney = pcall(function()
            vRP.giveMoney(user_id, parseInt(Config.rewards.money))
        end)
        if not okMoney then
            print(('^1[axl_creator]^7 erro ao entregar money pra user_id=%s: %s'):format(
                user_id, tostring(errMoney)))
        end
    end

    -- Itens iniciais, com 1 retry se a quantidade não bater.
    for _, item in ipairs(Config.rewards.items or {}) do
        local expectedAmount = parseInt(item.amount)
        local okItem, errItem = pcall(function()
            -- 4o argumento = entrega silenciosa, sem popup.
            vRP.giveInventoryItem(user_id, item.name, expectedAmount, true)
        end)
        if not okItem then
            print(('^1[axl_creator]^7 erro ao entregar item "%s" pra user_id=%s: %s'):format(
                tostring(item.name), user_id, tostring(errItem)))
        else
            local got = (vRP.getInventoryItemAmount and vRP.getInventoryItemAmount(user_id, item.name)) or 0
            if got < expectedAmount then
                local missing = expectedAmount - got
                pcall(function()
                    vRP.giveInventoryItem(user_id, item.name, missing, true)
                end)
                if Config.debugMode then
                    print(('^3[axl_creator]^7 item "%s" entregou %d/%d — retry com missing=%d'):format(
                        item.name, got, expectedAmount, missing))
                end
            end
        end
    end

    -- VIP inicial
    if Config.rewards.vipGroup and Config.rewards.vipGroup ~= '' then
        local okVip, errVip = pcall(function()
            vRP.addUserGroup(user_id, Config.rewards.vipGroup)
            if Config.rewards.vipUseVrpNative and vRP.insertNewVip then
                vRP.insertNewVip(user_id, Config.rewards.vipGroup)
            end
        end)
        if not okVip then
            print(('^1[axl_creator]^7 erro ao dar VIP pra user_id=%s: %s'):format(
                user_id, tostring(errVip)))
        end
    end

    vRP.setUData(user_id, "axl_creator:rewards_delivered", "1")

    if Config.debugMode then
        print(('^5[axl_creator]^7 starter rewards entregues SILENCIOSAMENTE pra user_id=%s'):format(user_id))
    end
end

-- Libera o lock em qualquer saída, inclusive erro.
local function deliverStarterRewards(user_id)
    if not user_id or user_id <= 0 then return end

    if deliveringRewards[user_id] then
        if Config.debugMode then
            print(('^5[axl_creator]^7 deliverStarterRewards ja em andamento pra user_id=%s — skip'):format(user_id))
        end
        return
    end
    deliveringRewards[user_id] = true

    local ok, err = pcall(deliverStarterRewardsInner, user_id)
    deliveringRewards[user_id] = nil
    if not ok then
        print(('^1[axl_creator]^7 erro entregando starter rewards pra user_id=%s: %s'):format(
            tostring(user_id), tostring(err)))
    end
end

-- Filtra a aparência que vem da NUI: chave desconhecida sai, valor fora da
-- faixa é cortado. Nada que o client manda é confiável.
local MAX_INDEX = 255  -- teto de sanidade pra indice de modelo/cor

local APPARENCE_LIMITS = {
    -- Head blend — limites fixos do motor
    fathersID       = { 0, 45 },   mothersID       = { 0, 45 },
    skinColor       = { 0, 10 },   shapeMix        = { 0.0, 1.0 },
    eyesColor       = { 0, 30 },
    hairHighlight   = { 0, 1 },

    -- Features de rosto (SetPedFaceFeature) — float -1.0 a 1.0
    eyesOpening     = { -1.0, 1.0 },
    eyebrowsHeight  = { -1.0, 1.0 }, eyebrowsWidth = { -1.0, 1.0 },
    noseWidth       = { -1.0, 1.0 }, noseHeight    = { -1.0, 1.0 },
    noseLength      = { -1.0, 1.0 }, noseBridge    = { -1.0, 1.0 },
    noseTip         = { -1.0, 1.0 }, noseShift     = { -1.0, 1.0 },
    cheekboneHeight = { -1.0, 1.0 }, cheekboneWidth= { -1.0, 1.0 },
    cheeksWidth     = { -1.0, 1.0 },
    lips            = { -1.0, 1.0 }, jawWidth      = { -1.0, 1.0 },
    jawHeight       = { -1.0, 1.0 },
    chinLength      = { -1.0, 1.0 }, chinPosition  = { -1.0, 1.0 },
    chinWidth       = { -1.0, 1.0 }, chinShape     = { -1.0, 1.0 },
    neckWidth       = { -1.0, 1.0 },

    -- Modelos e cores — teto folgado de propósito, a UI sabe o máximo real
    hairModel       = { 0,  MAX_INDEX }, firstHairColor  = { 0, MAX_INDEX },
    secondHairColor = { 0,  MAX_INDEX },
    eyebrowsModel   = { -1, MAX_INDEX }, eyebrowsColor   = { 0, MAX_INDEX },
    beardModel      = { -1, MAX_INDEX }, beardColor      = { 0, MAX_INDEX },
    chestModel      = { -1, MAX_INDEX }, chestColor      = { 0, MAX_INDEX },
    blushModel      = { -1, MAX_INDEX }, blushColor      = { 0, MAX_INDEX },
    lipstickModel   = { -1, MAX_INDEX }, lipstickColor   = { 0, MAX_INDEX },
    blemishesModel  = { -1, MAX_INDEX }, ageingModel     = { -1, MAX_INDEX },
    complexionModel = { -1, MAX_INDEX }, sundamageModel  = { -1, MAX_INDEX },
    frecklesModel   = { -1, MAX_INDEX }, makeupModel     = { -1, MAX_INDEX },
    bodyBlemishes   = { -1, MAX_INDEX }, bodyBlemishesAdd= { -1, MAX_INDEX },
}

-- Chaves que ficam como float. O resto é arredondado pra inteiro.
local APPARENCE_FLOAT_KEYS = {
    shapeMix = true, eyesOpening = true,
    eyebrowsHeight = true, eyebrowsWidth = true,
    noseWidth = true, noseHeight = true, noseLength = true,
    noseBridge = true, noseTip = true, noseShift = true,
    cheekboneHeight = true, cheekboneWidth = true, cheeksWidth = true,
    lips = true, jawWidth = true, jawHeight = true,
    chinLength = true, chinPosition = true, chinWidth = true, chinShape = true,
    neckWidth = true,
}

local function clampNumber(value, minV, maxV)
    local n = tonumber(value)
    if not n then return nil end
    if n ~= n then return nil end -- NaN
    if n < minV then return minV end
    if n > maxV then return maxV end
    return n
end

local function sanitizeApparence(raw)
    local clean = {}
    if type(raw) ~= 'table' then return clean end
    for key, range in pairs(APPARENCE_LIMITS) do
        local v = clampNumber(raw[key], range[1], range[2])
        if v ~= nil then
            if not APPARENCE_FLOAT_KEYS[key] then
                v = math.floor(v)
            end
            clean[key] = v
        end
    end
    return clean
end

-- Filtra a roupa: só passam componentes [0..11] e props "p0".."p9".
local function sanitizeClothes(raw)
    if type(raw) ~= 'table' then return nil end

    local clean = {}
    local count = 0
    for key, entry in pairs(raw) do
        if count >= 40 then break end

        local validKey = false
        if type(key) == 'number' and key >= 0 and key <= 11 then
            validKey = true
        elseif type(key) == 'string' then
            local slot = key:match('^p(%d)$')
            if slot then validKey = true end
        end

        if validKey and type(entry) == 'table' then
            -- Props usam -1 como "sem item" — não clampar em 0.
            local minDraw  = (type(key) == 'string') and -1 or 0
            local drawable = clampNumber(entry[1], minDraw, 1000)
            local texture  = clampNumber(entry[2], 0, 1000)
            -- 3o valor é a paleta da cor.
            local palette  = clampNumber(entry[3], 0, 15)
            if drawable then
                clean[key] = {
                    math.floor(drawable),
                    math.floor(texture or 0),
                    palette and math.floor(palette) or nil,
                }
                count = count + 1
            end
        end
    end

    if count == 0 then return nil end

    -- modelhash/model definem o gênero do ped. Só os dois freemode passam.
    local MODELOS_OK = {
        [GetHashKey('mp_m_freemode_01')] = 'mp_m_freemode_01',
        [GetHashKey('mp_f_freemode_01')] = 'mp_f_freemode_01',
    }
    local hash = tonumber(raw.modelhash)
    if hash then
        hash = math.floor(hash)
        if MODELOS_OK[hash] then
            clean.modelhash = hash
            clean.model = MODELOS_OK[hash]
        end
    end
    if not clean.model and (raw.model == 'mp_m_freemode_01' or raw.model == 'mp_f_freemode_01') then
        clean.model = raw.model
        clean.modelhash = GetHashKey(raw.model)
    end

    return clean
end

-- Retorna o user_id do player, usado na tela de whitelist.
src.getUserId = function()
    local source = source
    return vRP.getUserId(source) or 0
end

-- Marca o player como pendente de whitelist ao abrir a tela.
src.startWhitelist = function()
    local source = source
    local id = vRP.getUserId(source)
    if id then WhitelistPending[id] = source end
    return id
end

src.checkWhitelist = function()
    local source = source
    local user_id = vRP.getUserId(source)
    if not user_id then return false end

    local license = AXL.getLicense(source)

    -- License já liberada em axl_whitelist: aprova e corrige o vrp_users.
    if license and AXL.isLicenseWhitelisted(license) then
        pcall(function()
            exports.oxmysql:execute_async(
                'UPDATE vrp_users SET whitelisted = 1 WHERE id = ?', { user_id }
            )
        end)
        WhitelistPending[user_id] = nil
        return true
    end

    -- WL aprovada direto em vrp_users (bot externo ou SQL manual).
    local query = exports.oxmysql:query_async('SELECT whitelisted FROM vrp_users WHERE id = ? LIMIT 1', { user_id })
    if query and #query > 0 and (query[1].whitelisted == 1 or query[1].whitelisted == true) then
        WhitelistPending[user_id] = nil

        -- Primeira vez detectando a aprovação: sincroniza a axl_whitelist e loga.
        if license then
            AXL.syncWhitelistFromVrpUsers(user_id, license, source)
        end

        return true
    end
    return false
end

-- Auth externa de Discord (opcional): resource em Config.integrations.discordAuthResource.
-- Ativa, é ele quem libera o spawn via exports['axl_creator']:processSpawn(source, user_id).
CreateThread(function()
    Wait(5000)
    discordAuthEnabled = Bridges.discordAuthEnabled()
    if discordAuthEnabled and Config.debugMode then
        print(('^5[axl_creator]^7 auth externa ativa: %s'):format(
            tostring(Config.integrations.discordAuthResource)))
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= '' and resource == Config.integrations.discordAuthResource then
        discordAuthEnabled = false
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= '' and resource == Config.integrations.discordAuthResource then
        discordAuthEnabled = true
    end
end)

-- Ponto de entrada para o resource de auth externa liberar o player.
exports('processSpawn', function(source, user_id)
    if not source or not user_id then return false end
    local raw = vRP.getUData(user_id, "vRP:spawnController")
    local controller = 0
    if raw and raw ~= "" then
        local ok, decoded = pcall(json.decode, raw)
        if ok then controller = tonumber(decoded) or 0 end
    end
    processSpawnController(source, controller, user_id)
    return true
end)

-- Em todo playerSpawn: sincroniza a whitelist e restaura vida/colete.
AddEventHandler('vRP:playerSpawn', function(user_id, source, first_spawn)
    if not user_id or not source then return end
    if inCreator[user_id] then return end

    -- Sincroniza a whitelist caso o admin tenha liberado direto no SQL.
    local license = AXL.getLicense(source)
    if license and AXL.syncWhitelistFromVrpUsers then
        pcall(AXL.syncWhitelistFromVrpUsers, user_id, license, source)
    end

    -- Guarda a vida/colete que o player tinha ao sair, antes do client sobrescrever.
    local snapshot_data = vRP.getUserDataTable(user_id)
    local snapshot_health = nil
    local snapshot_health_max = nil
    local snapshot_armour = nil
    if snapshot_data then
        if snapshot_data.health and tonumber(snapshot_data.health) then
            snapshot_health = tonumber(snapshot_data.health)
        end
        if snapshot_data.health_max and tonumber(snapshot_data.health_max) then
            snapshot_health_max = tonumber(snapshot_data.health_max)
        end
        if snapshot_data.colete and tonumber(snapshot_data.colete) then
            snapshot_armour = tonumber(snapshot_data.colete)
        end
    end

    -- Espera o setCustomization aplicar o modelo antes de mexer na vida.
    SetTimeout(3000, function()
        if inCreator[user_id] then return end -- entrou no creator nesse meio tempo
        -- Pula se ainda tá em routing bucket != 0 (slot select / creator).
        if GetPlayerRoutingBucket(tostring(source)) ~= 0 then return end

        -- Roupa não é reaplicada aqui: o vRP já faz isso no spawn.

        -- Restaura a vida na mesma porcentagem que o player tinha ao sair.
        if snapshot_health then
            local saved = snapshot_health
            local saved_max = snapshot_health_max

            local effective_max
            if saved_max and saved_max > 100 then
                effective_max = saved_max
            else
                -- Sem health_max salvo, assume pelo valor.
                if saved > 200 then
                    effective_max = 400
                else
                    effective_max = 200
                end
            end

            local hud_pct
            if saved <= 100 then
                -- Quitou morto: volta morto.
                hud_pct = 0
            else
                hud_pct = (saved - 100) / (effective_max - 100)
            end

            if hud_pct < 0 then hud_pct = 0 end
            if hud_pct > 1 then hud_pct = 1 end

            local target
            if hud_pct == 0 then
                target = 0  -- morto
            else
                target = math.floor(hud_pct * 300) + 100
                -- Mínimo 101 pra ficar vivo.
                if target < 101 then target = 101 end
                if target > 400 then target = 400 end
            end

            pcall(function()
                vRPclient.setHealth(source, target)
            end)
            local data_now = vRP.getUserDataTable(user_id)
            if data_now then
                data_now.health = target
                data_now.health_max = 400
            end

            if snapshot_armour and snapshot_armour > 0 then
                pcall(function() vRPclient.setArmour(source, snapshot_armour) end)
                if data_now then data_now.colete = snapshot_armour end
            end
            if Config.debugMode then
                print(('^5[axl_creator]^7 reaplicado SNAPSHOT health saved=%s/%s hud_pct=%.2f -> target=%s armour=%s pra user_id=%d'):format(
                    tostring(saved), tostring(effective_max), hud_pct,
                    tostring(target), tostring(snapshot_armour or 0), user_id))
            end
        end
    end)
end)

AddEventHandler('vRP:playerSpawn', function(user_id, source, first_spawn)
    if Config.debugMode then
        print(('^5[axl_creator]^7 vRP:playerSpawn | user_id=%s | first_spawn=%s | discord=%s'):format(
            tostring(user_id), tostring(first_spawn), tostring(discordAuthEnabled)))
    end

    -- Com auth externa ativa, quem chama o spawn é aquele resource.
    if discordAuthEnabled then return end
    if first_spawn then
        -- Entra no watchdog: se não resolver o flow em 5min, leva kick.
        markFlowStart(user_id)

        -- spawnController: 2 = já criou personagem, 0/nil = vai pro creator.
        local raw = vRP.getUData(user_id, "vRP:spawnController")
        local controller = 0
        if raw and raw ~= "" then
            local ok, decoded = pcall(json.decode, raw)
            if ok then controller = tonumber(decoded) or 0 end
        end
        if Config.debugMode then
            print(('^5[axl_creator]^7 spawnController=%s (raw=%s)'):format(tostring(controller), tostring(raw)))
        end

        if controller >= 1 then
            processSpawnController(source, controller, user_id)
        else
            if Config.debugMode then
                print('^5[axl_creator]^7 controller=0 — abrindo creator (user novo)')
            end
            processSpawnController(source, 0, user_id)
        end
    end
end)

-- Decide o destino no spawn: quem tem aparência salva vai pra cidade,
-- quem não tem cai no creator.
function processSpawnController(source, statusSent, user_id)

    if Config.debugMode then
        print(('^5[axl_creator]^7 processSpawnController | user_id=%s | statusSent=%s'):format(
            tostring(user_id), tostring(statusSent)))
    end

    local raw = vRP.getUData(user_id, "currentCharacterMode")
    local hasApparence = raw and raw ~= "" and raw ~= "{}"

    if hasApparence then
        -- Tem personagem mas não tem whitelist: volta pra tela de WL.
        local wlRow = exports.oxmysql:query_async(
            'SELECT whitelisted FROM vrp_users WHERE id = ? LIMIT 1', { user_id })
        local isWhitelisted = wlRow and wlRow[1] and (wlRow[1].whitelisted == 1 or wlRow[1].whitelisted == true)

        if not isWhitelisted then
            -- Pega identidade salva pra pré-preencher a tela
            local idRow = exports.oxmysql:query_async(
                'SELECT name, firstname, age FROM vrp_user_identities WHERE user_id = ? LIMIT 1', { user_id })
            local identity = (idRow and idRow[1]) or {}

            if Config.debugMode then
                print(('^3[axl_creator]^7 user_id=%d tem aparência mas WL=0 — voltando pra tela de WL'):format(user_id))
            end

            -- Isola no bucket privado enquanto espera a WL.
            inCreator[user_id] = true
            -- Modo 'resume': já tem personagem, só falta a WL.
            creatorMode[user_id] = 'resume'
            SetPlayerRoutingBucket(source, user_id)

            markFlowResolved(user_id)

            TriggerClientEvent('axl_creator:resumeWhitelist', source, {
                userId  = user_id,
                name    = identity.name or '',
                surname = identity.firstname or '',
                age     = tonumber(identity.age) or 18,
            })
            return
        end

        -- Tenta abrir o seletor de spawn do axl_spawn.
        -- Se o player já spawnou nesta sessão, cai no spawn padrão.
        local spawnShown = false
        if GetResourceState('axl_spawn') == 'started' and not inCreator[user_id] then
            -- Não libere o BOOT_LOCK aqui: quem libera é o axl_spawn:open no client.
            local ok, result = pcall(function()
                return exports['axl_spawn']:requestShow(source, user_id)
            end)
            spawnShown = ok and result == true
            if spawnShown then
                markFlowResolved(user_id)
            end
            if Config.debugMode then
                print(('^5[axl_creator]^7 axl_spawn:requestShow user_id=%d → %s')
                    :format(user_id, tostring(spawnShown)))
            end
        end

        if not spawnShown then
            -- Spawn padrão: o vRP carrega posição e aparência do datatable.
            doSpawnPlayer(source, user_id, false)
        end
        return
    end

    -- Player novo: abre o creator e zera o spawnController.
    inCreator[user_id] = true
    creatorMode[user_id] = 'new'
    if statusSent and statusSent >= 1 then
        vRP.setUData(user_id, 'vRP:spawnController', json.encode(0))
    end
    if Config.debugMode then
        print(('^5[axl_creator]^7 user_id=%d sem aparência — abrindo creator'):format(user_id))
    end
    SetPlayerRoutingBucket(source, user_id)

    markFlowResolved(user_id)

    -- Entrega as recompensas iniciais em thread separada pra não atrasar o open.
    CreateThread(function()
        deliverStarterRewards(user_id)
    end)

    TriggerClientEvent('axl_creator:characterCreate', source)
end

-- Último passo do personagem novo: o client pede pra entrar na cidade.
-- O servidor reconsulta a whitelist no banco antes de liberar o bucket.
RegisterServerEvent('axl_creator:requestSpawn')
AddEventHandler('axl_creator:requestSpawn', function()
    local source = source
    local user_id = vRP.getUserId(source)
    if not user_id then return end

    -- Pedido sem estado em memória (restart do resource): valida pelo bucket.
    if not awaitingWlSpawn[user_id] then
        -- Só aceita quem ainda está isolado no bucket privado do creator.
        local bucketOk = false
        pcall(function()
            bucketOk = GetPlayerRoutingBucket(source) == user_id
        end)

        if not (bucketOk and inCreator[user_id]) then
            print(('^3[axl_creator]^7 requestSpawn recusado pra user_id=%s (fora do fluxo do creator)'):format(user_id))
            TriggerClientEvent('axl_creator:spawnDenied', source)
            return
        end
        print(('^3[axl_creator]^7 requestSpawn orfao aceito pra user_id=%s (estado perdido em restart)'):format(user_id))
    end

    local approved = false
    local okCheck, err = pcall(function()
        local license = AXL.getLicense(source)
        if license and AXL.isLicenseWhitelisted(license) then
            approved = true
            return
        end

        local rows = exports.oxmysql:query_async(
            'SELECT whitelisted FROM vrp_users WHERE id = ? LIMIT 1', { user_id })
        if rows and rows[1] and (rows[1].whitelisted == 1 or rows[1].whitelisted == true) then
            approved = true
            if license then
                AXL.syncWhitelistFromVrpUsers(user_id, license, source)
            end
        end
    end)

    if not okCheck then
        print(('^1[axl_creator]^7 erro ao validar WL em requestSpawn user_id=%s: %s'):format(
            user_id, tostring(err)))
        TriggerClientEvent('axl_creator:spawnDenied', source)
        return
    end

    if not approved then
        print(('^3[axl_creator]^7 requestSpawn NEGADO pra user_id=%s — sem whitelist'):format(user_id))
        TriggerClientEvent('axl_creator:spawnDenied', source)
        return
    end

    awaitingWlSpawn[user_id] = nil
    inCreator[user_id] = nil
    SetPlayerRoutingBucket(source, 0)

    if GetResourceState('axl_spawn') == 'started' then
        pcall(function()
            exports['axl_spawn']:markSpawnedForUser(user_id)
        end)
    end

    markFlowResolved(user_id)
    TriggerClientEvent('axl_creator:approvedSpawn', source)

    if Config.debugMode then
        print(('^5[axl_creator]^7 requestSpawn aprovado pra user_id=%s — entrando na cidade'):format(user_id))
    end
end)

-- Falha crítica de carregamento no client: kicka o player pra ele reconectar.
RegisterServerEvent('axl_creator:flowFailed')
AddEventHandler('axl_creator:flowFailed', function(reason)
    local source = source
    local user_id = vRP.getUserId(source) or 0

    -- Sanitiza o motivo antes de logar.
    reason = tostring(reason or 'UNKNOWN'):sub(1, 80):gsub('[^A-Za-z0-9_:.,-]', '')

    print(('^1[axl_creator:flowFailed]^7 source=%s user_id=%s reason=%s — kickando'):format(
        tostring(source), tostring(user_id), reason))

    -- Limpa o estado em memória.
    if user_id and user_id > 0 then
        if inCreator[user_id]          then inCreator[user_id]          = nil end
        if WhitelistPending[user_id]   then WhitelistPending[user_id]   = nil end
        if finishingCharacter[user_id] then finishingCharacter[user_id] = nil end
    end

    DropPlayer(source,
        'Falha ao carregar a cidade.\n\n' ..
        'Reconecte para tentar novamente.\n\n' ..
        'Se o problema persistir, abra um ticket no Discord.\n\n' ..
        'Código: ' .. reason)
end)

-- Player confirmou a WL na tela de retorno: server revalida no banco e spawna.
RegisterServerEvent('axl_creator:resumeWlApproved')
AddEventHandler('axl_creator:resumeWlApproved', function()
    local source = source
    local user_id = vRP.getUserId(source)
    if not user_id then return end

    -- Só processa quem está mesmo no fluxo do creator.
    if not inCreator[user_id] then
        if Config.debugMode then
            print(('^3[axl_creator]^7 resumeWlApproved ignorado pra user_id=%s (não estava em creator)'):format(user_id))
        end
        return
    end

    -- Re-checa a whitelist no banco.
    local wlRow = exports.oxmysql:query_async(
        'SELECT whitelisted FROM vrp_users WHERE id = ? LIMIT 1', { user_id })
    local isWhitelisted = wlRow and wlRow[1] and (wlRow[1].whitelisted == 1 or wlRow[1].whitelisted == true)

    if not isWhitelisted then
        -- Ainda não tá WL — re-abre tela com mesma data
        local idRow = exports.oxmysql:query_async(
            'SELECT name, firstname, age FROM vrp_user_identities WHERE user_id = ? LIMIT 1', { user_id })
        local identity = (idRow and idRow[1]) or {}

        TriggerClientEvent('axl_creator:resumeWhitelist', source, {
            userId  = user_id,
            name    = identity.name or '',
            surname = identity.firstname or '',
            age     = tonumber(identity.age) or 18,
        })
        return
    end

    -- WL aprovada: sempre spawna no Config.coords.finalSpawn.
    inCreator[user_id] = nil
    SetPlayerRoutingBucket(source, 0)

    if Config.debugMode then
        print(('^5[axl_creator]^7 resumeWlApproved user_id=%d → spawn no finalSpawn (loadCutSine)'):format(user_id))
    end

    -- Marca como spawnado pra o axl_spawn não abrir o seletor nesta sessão.
    if GetResourceState('axl_spawn') == 'started' then
        pcall(function()
            exports['axl_spawn']:markSpawnedForUser(user_id)
        end)
    end

    -- firstspawn=true: o client teleporta pro finalSpawn com a cinemática.
    doSpawnPlayer(source, user_id, true)
end)

function doSpawnPlayer(source, user_id, firstspawn)
    if source then
        markFlowResolved(user_id)
        TriggerClientEvent('axl_creator:normalSpawn', source, firstspawn)
    end
end

-- Disparado pela NUI quando o player conclui o creator.
RegisterServerEvent('axl_creator:finishedCharacter')
AddEventHandler('axl_creator:finishedCharacter', function(currentCharacterMode, clothes, formData)
    local source = source

    -- Dedupe por source: barra evento duplicado antes de qualquer yield.
    if finishingCharacterBySource[source] then
        if Config.debugMode then
            print(('^5[axl_creator]^7 finishedCharacter dupe (source=%s) ignorado'):format(source))
        end
        return
    end
    finishingCharacterBySource[source] = true

    local _uid_to_clear = nil

    -- Cronometra o handler. Acima de 300ms loga warning.
    local _t_start = GetGameTimer()

    -- pcall em tudo pra garantir que as flags sejam limpas no fim.
    local _ok, _err = pcall(function()

    local user_id = vRP.getUserId(source)
    if not user_id then return end

    -- Dedupe redundante por user_id.
    if finishingCharacter[user_id] then
        if Config.debugMode then
            print(('^5[axl_creator]^7 finishedCharacter dupe ignorado pra user_id=%s'):format(user_id))
        end
        return
    end
    finishingCharacter[user_id] = true
    _uid_to_clear = user_id  -- track pra cleanup no finally

    -- Sai antes do finally
    if not inCreator[user_id] then
        finishingCharacter[user_id] = nil
        finishingCharacterBySource[source] = nil
        return
    end
    inCreator[user_id] = nil

    -- O modo vem do servidor, gravado quando o creator foi aberto.
    local mode = creatorMode[user_id] or 'new'
    creatorMode[user_id] = nil

    -- Quem está na tela de retorno de WL sai por 'axl_creator:resumeWlApproved'.
    if mode == 'resume' then
        creatorMode[user_id] = 'resume'
        inCreator[user_id] = true
        print(('^3[axl_creator]^7 finishedCharacter ignorado pra user_id=%s (esta no fluxo de retorno de WL)'):format(user_id))
        return
    end

    -- Showroom: só visualização, não grava nada.
    if mode == 'showroom' then
        SetPlayerRoutingBucket(source, 0)
        if Config.debugMode then
            print(('^5[axl_creator]^7 showroom finalizado pra user_id=%s — nada gravado'):format(user_id))
        end
        return
    end

    local isReset = (mode == 'reset')

    -- Marca antes de gravar: se algo falhar, o player ainda consegue pedir spawn.
    if not isReset then awaitingWlSpawn[user_id] = true end

    -- Salva o rosto na UData 'currentCharacterMode' — barbearia e lojas leem daqui.
    currentCharacterMode = sanitizeApparence(currentCharacterMode)
    clothes = sanitizeClothes(clothes)

    local apparenceJson = json.encode(currentCharacterMode)
    vRP.setUData(user_id, "currentCharacterMode", apparenceJson)
    vRP.setUData(user_id, "vRP:spawnController", json.encode(2))

    -- Atualiza nome/sobrenome/idade em vrp_user_identities.
    -- Não chamar init_user_identity aqui: zera registration/phone.
    if formData and formData.name and formData.surname and formData.age then
        -- Sanitiza nome e idade antes de gravar: o formData vem do client.
        local function limpaNome(s)
            s = tostring(s or '')
            s = s:gsub('[<>]', '')                                  -- mata tags/iframe
            s = s:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '') -- normaliza espaços
            s = s:sub(1, 20)                                         -- limite de tamanho
            if s == '' then s = 'Cidadao' end                       -- fallback se sobrou vazio
            return s
        end
        local nome      = limpaNome(formData.name)
        local sobrenome = limpaNome(formData.surname)
        local amin  = (Config.idade and Config.idade.min) or 18
        local amax  = (Config.idade and Config.idade.max) or 99
        local idade = math.floor(tonumber(formData.age) or amin)
        if idade < amin then idade = amin elseif idade > amax then idade = amax end

        vRP.execute("vRP/update_user_first_spawn", {
            user_id   = user_id,
            firstname = sobrenome,  -- UnityDev: firstname = sobrenome
            name      = nome,       -- name = primeiro nome
            age       = idade,
        })
        if Config.debugMode then
            print(('^5[axl_creator]^7 identidade salva: user_id=%s | %s %s | %d anos'):format(
                user_id, nome, sobrenome, idade))
        end
    end

    -- Atualiza cache de apparence em memória (pra barbershop/loja lerem na hora)
    if vRP.updateUserApparence then
        vRP.updateUserApparence(user_id, 'rosto', currentCharacterMode)
        if clothes then vRP.updateUserApparence(user_id, 'clothes', clothes) end
    end

    -- Salva a roupa no datatable + UData pro vRP aplicar no próximo spawn.
    -- O clothes já chega no formato do vRP: não converter de novo.
    if clothes then
        local data = vRP.getUserDataTable(user_id)
        if data then
            -- Preserva model/modelhash do datatable original (gênero do ped).
            if data.customization then
                if data.customization.modelhash and not clothes.modelhash then
                    clothes.modelhash = data.customization.modelhash
                end
                if data.customization.model and not clothes.model then
                    clothes.model = data.customization.model
                end
            end
            data.customization = clothes
        end
        vRP.setUData(user_id, 'vRP:saveClothes', json.encode(clothes))
        if data then
            vRP.setUData(user_id, 'vRP:datatable', json.encode(data))
        end
    else
        -- Sem roupa: só faz o flush do datatable.
        local data = vRP.getUserDataTable(user_id)
        if data then
            vRP.setUData(user_id, 'vRP:datatable', json.encode(data))
        end
    end

    -- Recompensas e carro só no personagem novo. /resetchar só troca a aparência.
    if not isReset then
        -- Rede de segurança: já rodou quando o creator abriu, aqui é no-op.
        deliverStarterRewards(user_id)

        -- Entrega na garagem o carro que o player escolheu no creator.
        if formData and formData.vehicle and carrosIniciais[formData.vehicle] then
            local ok, err = pcall(function()
                vRP.execute('creative/add_vehicle', {
                    user_id = parseInt(user_id),
                    vehicle = formData.vehicle,
                    ipva    = os.time(),
                })
            end)
            if ok then
                if Config.debugMode then
                    print(('^5[axl_creator]^7 veículo entregue: user_id=%s, vehicle=%s'):format(
                        user_id, formData.vehicle))
                end
            else
                print(('^1[axl_creator]^7 erro ao inserir veículo pra user_id=%s: %s'):format(
                    user_id, tostring(err)))
            end
        elseif formData and formData.vehicle then
            print(('^1[axl_creator]^7 vehicle inválido (não tá em Config.starterCars): %s'):format(tostring(formData.vehicle)))
        end
    elseif Config.debugMode then
        print(('^5[axl_creator]^7 reset finalizado pra user_id=%s — aparência atualizada, sem reward'):format(user_id))
    end

    -- Personagem novo continua no bucket privado até a WL liberar o spawn.
    -- No /resetchar o player já passou pela WL, então volta pro bucket público.
    if isReset then
        SetPlayerRoutingBucket(source, 0)

        -- Marca como spawnado pra o seletor de spawn não aparecer agora.
        if GetResourceState('axl_spawn') == 'started' then
            pcall(function()
                exports['axl_spawn']:markSpawnedForUser(user_id)
            end)
        end
    elseif Config.debugMode then
        print(('^5[axl_creator]^7 user_id=%s finalizou o creator — aguardando WL pra liberar spawn'):format(user_id))
    end

    Bridges.barbershopInit(user_id, source)

    -- A tatuagem fica numa UData própria, fora do que o creator regrava.
    if isReset then
        vRP.setUData(user_id, 'vRP:tattoos', json.encode({}))
    end
    Bridges.tattoosInit(user_id, source)

    -- Dá vida cheia depois da cinemática de entrada (12s cobrem o spawn inteiro).
    if not isReset then
        local _save_uid = user_id
        local _save_src = source
        SetTimeout(12000, function()
            -- Re-resolve o source: o player pode ter saído ou reconectado.
            local nowSrc = vRP.getUserSource(_save_uid) or _save_src
            if not nowSrc or nowSrc == 0 then
                if Config.debugMode then
                    print(('^3[axl_creator]^7 first_spawn health: user_id=%s offline, pula setHealth'):format(_save_uid))
                end
                return
            end
            pcall(function()
                vRPclient.setHealth(nowSrc, 400)
            end)
            local data_now = vRP.getUserDataTable(_save_uid)
            if data_now then
                data_now.health = 400
                data_now.health_max = 400
            end
            if Config.debugMode then
                print(('^5[axl_creator]^7 first_spawn health: user_id=%s recebeu vida cheia (400/400)'):format(_save_uid))
            end
        end)
    end

    local _t_elapsed = GetGameTimer() - _t_start
    if _t_elapsed > 300 then
        print(('^3[axl_creator:perf]^7 finishedCharacter user_id=%s levou %dms (>300ms)'):format(
            user_id, _t_elapsed))
    elseif Config.debugMode then
        print(('^5[axl_creator:perf]^7 finishedCharacter user_id=%s OK em %dms'):format(
            user_id, _t_elapsed))
    end

    end)  -- fim do pcall envolvendo o trabalho

    -- Cleanup das flags, com sucesso ou erro.
    if _uid_to_clear then
        finishingCharacter[_uid_to_clear] = nil
    end
    finishingCharacterBySource[source] = nil

    if not _ok then
        print(('^1[axl_creator]^7 erro fatal em finishedCharacter src=%s: %s'):format(
            tostring(source), tostring(_err)))
    end
end)

-- /verroupas — mostra o JSON da roupa atual do player (só admin).
RegisterCommand('verroupas', function(source)
    if source == 0 then return end -- bloqueia console
    local user_id = vRP.getUserId(source)
    if not user_id then return end
    if vRP.hasPermission and not vRP.hasPermission(user_id, 'admin.permissao') then return end

    local clothes = vRPclient.getCustomization(source)
    if clothes then
        vRP.prompt(source, 'Código da Roupa', json.encode(clothes))
    end
end)

-- Limpa o estado em memória do player que saiu.
AddEventHandler('vRP:playerLeave', function(uid)
    if WhitelistPending[uid] then WhitelistPending[uid] = nil end
    if inCreator[uid]        then inCreator[uid]        = nil end
    if finishingCharacter[uid] then finishingCharacter[uid] = nil end
    if AWAITING_FLOW[uid]    then AWAITING_FLOW[uid]    = nil end
    if creatorMode[uid]      then creatorMode[uid]      = nil end
    if awaitingWlSpawn[uid]  then awaitingWlSpawn[uid]  = nil end
    if deliveringRewards[uid] then deliveringRewards[uid] = nil end
    -- Sem esta linha a sub-tabela do FLOW_TIMING vaza memória.
    if FLOW_TIMING[uid]      then FLOW_TIMING[uid]      = nil end
end)

-- Watchdog: kicka quem ficar preso no carregamento além do timeout.
-- Quem está no creator, na tela de WL ou no seletor de spawn não é afetado.
CreateThread(function()
    while true do
        Wait(60000) -- checa a cada 60s

        local now = os.time()
        for uid, started_at in pairs(AWAITING_FLOW) do
            if (now - started_at) > AWAITING_FLOW_TIMEOUT_SEC then
                local source = vRP.getUserSource(uid)
                if source then
                    print(('^1[axl_creator:watchdog]^7 user_id=%d em limbo por %ds — kickando'):format(
                        uid, now - started_at))
                    DropPlayer(source,
                        'Tempo limite pra carregar a cidade.\n\n' ..
                        'Reconecte para tentar novamente.\n\n' ..
                        'Código: WATCHDOG_LIMBO_TIMEOUT')
                end
                AWAITING_FLOW[uid] = nil
            end
        end
    end
end)

-- Comandos /abrircreator e /resetchar.

-- Checa se o player tem alguma das permissões/grupos da lista ('everyone' libera geral).
local function hasAnyPermission(user_id, permsList)
    if not permsList or #permsList == 0 then return false end
    for _, p in ipairs(permsList) do
        if p == 'everyone' then return true end
        -- Tenta como permissão e como grupo
        if vRP.hasPermission and vRP.hasPermission(user_id, p) then return true end
        if vRP.hasGroup      and vRP.hasGroup(user_id, p)      then return true end
    end
    return false
end

-- Notify wrapper (usa Bridges.notify se existir, senão TriggerClientEvent direto)
local function notifyPlayer(source, nType, message, duration)
    if Bridges and Bridges.notify then
        Bridges.notify(source, nType, message, duration or 5)
    else
        TriggerClientEvent(Config.notify and Config.notify.event or 'Notify',
            source, nType, message, duration or 5)
    end
end

-- /abrircreator — abre o creator pra quem chamou (sem resetar dados)
local function cmdAbrirCreator(source, user_id)
    if not hasAnyPermission(user_id, Config.permissions.openCreator) then
        notifyPlayer(source, 'negado', Config.messages.notAdmin)
        return
    end

    if Config.debugMode then
        print(('^5[axl_creator]^7 /%s solicitado por user_id=%s (modo showroom)'):format(
            Config.commands.openCreator, user_id))
    end

    -- Showroom: isola no bucket privado sem mexer no spawnController.
    inCreator[user_id] = true
    creatorMode[user_id] = 'showroom'
    SetPlayerRoutingBucket(source, user_id)

    TriggerClientEvent('axl_creator:resetAndCreate', source, { mode = 'showroom' })
end

-- /resetchar [user_id?] — reseta o personagem (próprio ou de outro player)
local function cmdResetChar(source, user_id, args)
    -- Se args[1] foi passado, é o user_id de OUTRO player (modo admin)
    local targetId = tonumber(args and args[1])
    local targetSource = source

    if targetId and targetId ~= user_id then
        -- Reset em outro player — precisa de permissão admin
        if not hasAnyPermission(user_id, Config.permissions.resetChar) then
            notifyPlayer(source, 'negado', Config.messages.notAdmin)
            return
        end
        targetSource = vRP.getUserSource(targetId)
        if not targetSource then
            notifyPlayer(source, 'negado', Config.messages.notOnline)
            return
        end
    else
        -- Reset próprio
        if not hasAnyPermission(user_id, Config.permissions.resetChar) then
            notifyPlayer(source, 'negado', Config.messages.notAdmin)
            return
        end
        targetId = user_id
    end

    if Config.debugMode then
        print(('^5[axl_creator]^7 /%s solicitado por user_id=%s | alvo=%s'):format(
            Config.commands.resetChar, user_id, targetId))
    end

    inCreator[targetId] = true
    creatorMode[targetId] = 'reset'
    SetPlayerRoutingBucket(targetSource, targetId)

    -- controller=0: se cair antes de terminar, volta pro creator no próximo login.
    vRP.setUData(targetId, "vRP:spawnController", json.encode(0))

    TriggerClientEvent('axl_creator:resetAndCreate', targetSource, { mode = 'reset' })

    if targetId ~= user_id then
        notifyPlayer(source, 'sucesso', (Config.messages.resetOther):format(targetId))
    else
        notifyPlayer(source, 'sucesso', Config.messages.resetSelf)
    end
end

-- Reset pedido pelo item
AddEventHandler('axl_creator:startReset', function(target)
    local targetSource = tonumber(target)
    if not targetSource then return end
    local targetId = vRP.getUserId(targetSource)
    if not targetId then return end
    if inCreator[targetId] then return end

    inCreator[targetId]   = true
    creatorMode[targetId] = 'reset'
    SetPlayerRoutingBucket(targetSource, targetId)

    -- controller=0: se cair antes de terminar, volta pro creator no proximo login.
    vRP.setUData(targetId, "vRP:spawnController", json.encode(0))

    TriggerClientEvent('axl_creator:resetAndCreate', targetSource, { mode = 'reset' })
end)

-- O client dispara isto quando o player usa /abrircreator ou /resetchar.
RegisterServerEvent('axl_creator:runCommand')
AddEventHandler('axl_creator:runCommand', function(action, args)
    local source  = source
    local user_id = vRP.getUserId(source)
    if not user_id then
        notifyPlayer(source, 'negado', Config.messages.onlyLogin)
        return
    end

    if action == 'openCreator' then
        cmdAbrirCreator(source, user_id)
    elseif action == 'resetChar' then
        cmdResetChar(source, user_id, args or {})
    else
        print(('^1[axl_creator]^7 runCommand: ação desconhecida "%s"'):format(tostring(action)))
    end
end)

-- /axlunlock — destrava de emergência. O server valida admin antes de autorizar.
RegisterServerEvent('axl_creator:requestUnlock')
AddEventHandler('axl_creator:requestUnlock', function()
    local source = source
    local user_id = vRP.getUserId(source)
    if not user_id then return end
    if not vRP.hasPermission(user_id, 'admin.permissao') then
        notifyPlayer(source, 'negado', Config.messages.notAdmin)
        return
    end
    TriggerClientEvent('axl_creator:doUnlock', source)
end)

-- Registro dos comandos no chat. O F8 é coberto pelo client.
CreateThread(function()
    Wait(2000) -- espera Config carregar
    if Config and Config.commands then
        if Config.commands.openCreator and Config.commands.openCreator ~= '' then
            RegisterCommand(Config.commands.openCreator, function(source, args)
                if source == 0 then
                    print('^3[axl_creator]^7 console: use no chat in-game (não funciona no console).')
                    return
                end
                local user_id = vRP.getUserId(source)
                if user_id then cmdAbrirCreator(source, user_id) end
            end, false)
        end

        if Config.commands.resetChar and Config.commands.resetChar ~= '' then
            RegisterCommand(Config.commands.resetChar, function(source, args)
                if source == 0 then
                    print('^3[axl_creator]^7 console: use no chat in-game (não funciona no console).')
                    return
                end
                local user_id = vRP.getUserId(source)
                if user_id then cmdResetChar(source, user_id, args or {}) end
            end, false)
        end

        if Config.debugMode then
            print(('^5[axl_creator:server]^7 comandos registrados: /%s, /%s'):format(
                Config.commands.openCreator, Config.commands.resetChar))
        end
    end
end)

-- Exports usados por outros resources (lojas, bot de WL).

-- true se o player está com o creator aberto. As lojas checam isso.
exports('isInCreator', function(user_id)
    return inCreator[user_id] == true
end)

-- Marca uma license como whitelistada.
exports('adminMarkWhitelist', function(license, discord_id)
    return AXL.markLicenseWhitelisted(license, discord_id, '')
end)

-- Bot de WL chama ao aprovar: salva o discord, marca vrp_users.whitelisted = 1,
-- insere em axl_whitelist e dispara o webhook. Pode repetir sem duplicar nada.
exports('botApproveWhitelist', function(user_id, license, discord_id)
    if not user_id or not license then return false end
    user_id = tonumber(user_id)
    if not user_id then return false end

    if discord_id and discord_id ~= '' then
        AXL.saveUserDiscord(user_id, discord_id)
    end
    pcall(function()
        exports.oxmysql:execute_async(
            'UPDATE vrp_users SET whitelisted = 1 WHERE id = ?', { user_id }
        )
    end)
    AXL.syncWhitelistFromVrpUsers(user_id, license, nil)
    return true
end)

-- Bot consulta Discord salvo de um user_id
exports('getUserDiscord', function(user_id)
    return AXL.getUserDiscord(user_id)
end)

-- Salva o Discord sem aprovar a WL. Não dispara webhook.
exports('saveUserDiscord', function(user_id, discord_id)
    return AXL.saveUserDiscord(user_id, discord_id)
end)

-- Limpa de tempos em tempos o estado em memória de quem não está mais online.
CreateThread(function()
    while true do
        Wait(120000)
        local staleCount = 0
        for uid, _ in pairs(inCreator) do
            if not vRP.getUserSource(uid) then
                inCreator[uid] = nil
                staleCount = staleCount + 1
            end
        end
        for uid, _ in pairs(WhitelistPending) do
            if not vRP.getUserSource(uid) then
                WhitelistPending[uid] = nil
                staleCount = staleCount + 1
            end
        end
        for uid, _ in pairs(finishingCharacter) do
            if not vRP.getUserSource(uid) then
                finishingCharacter[uid] = nil
                staleCount = staleCount + 1
            end
        end
        -- Limpa também o dedupe por source.
        for src, _ in pairs(finishingCharacterBySource) do
            if not GetPlayerName(src) then
                finishingCharacterBySource[src] = nil
                staleCount = staleCount + 1
            end
        end
        if staleCount > 0 and Config.debugMode then
            print(('^5[axl_creator]^7 cleanup removeu %d stale entries'):format(staleCount))
        end
    end
end)

-- /debugcreator on|off — liga o log de debug. Só pelo console do server.
RegisterCommand('debugcreator', function(source, args)
    if source ~= 0 then return end -- só do console do server
    if args[1] == 'on' then
        Config.debugMode = true
        print('^5[axl_creator]^7 debugMode: ON')
    elseif args[1] == 'off' then
        Config.debugMode = false
        print('^5[axl_creator]^7 debugMode: OFF')
    else
        print(('^5[axl_creator]^7 debugMode: %s (use /debugcreator on|off)'):format(tostring(Config.debugMode)))
    end
end, true)


-- Disparado pela barbearia, skinshop e tattoo quando a aparência muda.
-- Só confere se o save foi gravado e avisa no console. Roda em debugMode.
AddEventHandler('axl_creator:appearanceChanged', function(user_id)
    if not user_id then return end
    if not (Config and Config.debugMode) then return end

    local raw = vRP.getUData(user_id, "currentCharacterMode")
    if not raw or raw == "" or raw == "{}" then
        print(('^3[axl_creator]^7 appearanceChanged: user_id=%s mudou de apar\195\170ncia mas '
            .. '`currentCharacterMode` est\195\161 vazio no banco — o save falhou em sil\195\170ncio.')
            :format(tostring(user_id)))
        return
    end

    print(('^5[axl_creator]^7 appearanceChanged: user_id=%s | %d bytes gravados')
        :format(tostring(user_id), #raw))
end)
