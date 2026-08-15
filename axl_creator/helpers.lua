-- axl_creator — helpers de whitelist, conversão de roupas e migrations
-- do banco.

AXL = {}


MultiChar = AXL

local function jsonDecode(s)
    if not s or s == '' or s == 'null' then return nil end
    local ok, t = pcall(json.decode, s)
    return ok and t or nil
end

function AXL.getLicense(source)
    if not source or source == 0 then return nil end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

function AXL.getDiscord(source)
    if not source or source == 0 then return nil end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:sub(1, 8) == 'discord:' then return id:sub(9) end
    end
    return nil
end

-- Converte a customization do vRP no array linear de 30 valores.
local function getEntry(tbl, key) return tbl[key] or tbl[tostring(key)] end
local function getProp(tbl, idx)  return tbl["p"..idx] end

local function vrpCustomToClothesArray(vrpCustom)
    if type(vrpCustom) ~= 'table' then return nil end
    local out = {}
    local compMap = {
        { 1,  1  }, { 3,  5  }, { 5,  7  }, { 7,  3  }, { 9,  4  },
        { 11, 8  }, { 13, 6  }, { 15, 11 }, { 17, 9  }, { 19, 10 },
    }
    for _, m in ipairs(compMap) do
        local arrIdx, compIdx = m[1], m[2]
        local entry = getEntry(vrpCustom, compIdx)
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
        local entry = getProp(vrpCustom, propIdx)
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
AXL.vrpCustomToClothesArray = vrpCustomToClothesArray

-- Converte o array de 30 valores de volta pra customization do vRP.

local function clothesArrayToVrpCustom(arr)
    if type(arr) ~= 'table' then return nil end
    local out = {}
    local compMap = {
        { 1,  1  }, { 5,  3  }, { 7,  5  }, { 3,  7  }, { 4,  9  },
        { 8,  11 }, { 6,  13 }, { 11, 15 }, { 9,  17 }, { 10, 19 },
    }
    for _, m in ipairs(compMap) do
        local compIdx, arrIdx = m[1], m[2]
        local v1 = tonumber(arr[arrIdx])     or 0
        local v2 = tonumber(arr[arrIdx + 1]) or 0
        out[compIdx] = { v1, v2, 2 }  -- palette default 2 (vRP padrão)
    end
    local propMap = { { 0, 21 }, { 1, 23 }, { 2, 25 }, { 6, 27 }, { 7, 29 } }
    for _, m in ipairs(propMap) do
        local propIdx, arrIdx = m[1], m[2]
        local v1 = tonumber(arr[arrIdx])     or -1
        local v2 = tonumber(arr[arrIdx + 1]) or 0
        out['p'..propIdx] = { v1, v2, 2 }
    end
    return out
end
AXL.clothesArrayToVrpCustom = clothesArrayToVrpCustom

-- Reaplica no jogador as roupas salvas em vRP:saveClothes.

function AXL.reloadUserResources(source, user_id)
    if not source or not user_id then return end
    pcall(function()
        local rawClothes = vRP.getUData(user_id, 'vRP:saveClothes')
        if not rawClothes or rawClothes == '' then return end
        local ok, clothes = pcall(json.decode, rawClothes)
        if not ok or type(clothes) ~= 'table' then return end
        local arr
        if type(clothes[1]) == 'table' or type(clothes[3]) == 'table' or
           type(clothes['p0']) == 'table' or type(clothes[0]) == 'table' then
            arr = vrpCustomToClothesArray(clothes)
        else
            arr = clothes
        end

        if arr then
            TriggerClientEvent('Character:UpdateClothes', source, arr)
        end
    end)
end


local function ensureColumn(table_name, column_name, definition)
    local rows = exports.oxmysql:query_async(
        'SELECT COUNT(*) AS cnt FROM information_schema.COLUMNS '..
        'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { table_name, column_name }
    ) or {}
    local cnt = (rows[1] and rows[1].cnt) or 0
    if cnt == 0 then
        exports.oxmysql:execute_async(
            ('ALTER TABLE `%s` ADD COLUMN %s'):format(table_name, definition),
            {}
        )
        if Config.debugMode then
            print(('^5[axl_creator:helpers:migration]^7 + coluna %s.%s'):format(table_name, column_name))
        end
    end
end


local function ensureIndex(table_name, index_name, columns)
    local rows = exports.oxmysql:query_async(
        'SELECT COUNT(*) AS cnt FROM information_schema.STATISTICS '..
        'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?',
        { table_name, index_name }
    ) or {}
    local cnt = (rows[1] and rows[1].cnt) or 0
    if cnt == 0 then
        local ok, err = pcall(function()
            exports.oxmysql:execute_async(
                ('CREATE INDEX `%s` ON `%s`(%s)'):format(index_name, table_name, columns),
                {}
            )
        end)
        if ok then
            print(('^5[axl_creator:helpers:migration]^7 + índice %s.%s(%s)'):format(
                table_name, index_name, columns))
        else
            print(('^3[axl_creator:helpers:migration]^7 índice %s.%s falhou (não-fatal): %s'):format(
                table_name, index_name, tostring(err)))
        end
    end
end

function AXL.runMigrations()

    exports.oxmysql:execute_async([[
        CREATE TABLE IF NOT EXISTS `axl_whitelist` (
            `license`    VARCHAR(64) NOT NULL,
            `discord_id` VARCHAR(32) NOT NULL DEFAULT '',
            `fivem_id`   VARCHAR(32) NULL DEFAULT NULL,
            `passed_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`license`),
            INDEX `idx_discord_id` (`discord_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {})

    ensureColumn('vrp_users', 'discord',
        "`discord` VARCHAR(32) NULL DEFAULT NULL AFTER `whitelisted`")


    ensureIndex('vrp_users', 'idx_vrp_users_discord', '`discord`')
    ensureIndex('vrp_user_identities', 'idx_vrp_user_identities_user_id', '`user_id`')

    if Config.debugMode then
        print('^5[axl_creator:helpers:migration]^7 schema verificado/aplicado com sucesso')
    end
end

-- Aplica o schema no start do resource.
CreateThread(function()
    Wait(2000)  -- espera oxmysql/MySQL ficar pronto
    local ok, err = pcall(AXL.runMigrations)
    if not ok then
        print(('^1[axl_creator:helpers:migration]^7 ERRO: %s'):format(tostring(err)))
    end
end)

function AXL.saveUserDiscord(user_id, discord_id)
    if not user_id or not discord_id or discord_id == '' then return end
    pcall(function()
        exports.oxmysql:execute_async(
            'UPDATE vrp_users SET discord = ? WHERE id = ?',
            { tostring(discord_id), tonumber(user_id) }
        )
    end)
end

function AXL.getUserDiscord(user_id)
    if not user_id then return nil end
    local rows = exports.oxmysql:query_async(
        'SELECT discord FROM vrp_users WHERE id = ? LIMIT 1',
        { tonumber(user_id) }
    )
    if not rows or #rows == 0 then return nil end
    local d = rows[1].discord
    if d == nil or d == '' then return nil end
    return d
end

function AXL.isUserWhitelisted(user_id)
    if not user_id then return false end
    local rows = exports.oxmysql:query_async(
        'SELECT whitelisted FROM vrp_users WHERE id = ? LIMIT 1',
        { tonumber(user_id) }
    )
    if not rows or #rows == 0 then return false end
    return rows[1].whitelisted == 1 or rows[1].whitelisted == true
end

function AXL.isLicenseWhitelisted(license)
    if not license or license == '' then return false end
    local rows = exports.oxmysql:query_async(
        'SELECT 1 AS ok FROM axl_whitelist WHERE license = ? LIMIT 1',
        { license }
    )
    return rows and #rows > 0
end

function AXL.markLicenseWhitelisted(license, discord_id, fivem_id)
    if not license or license == '' then return false end
    pcall(function()
        exports.oxmysql:execute_async(
            'INSERT INTO axl_whitelist (license, discord_id, fivem_id) VALUES (?, ?, ?) '..
            'ON DUPLICATE KEY UPDATE discord_id = VALUES(discord_id), fivem_id = VALUES(fivem_id)',
            { license, tostring(discord_id or ''), tostring(fivem_id or '') }
        )
    end)
    return true
end

function AXL.getWhitelistDiscord(license)
    if not license then return nil end
    local rows = exports.oxmysql:query_async(
        'SELECT discord_id FROM axl_whitelist WHERE license = ? LIMIT 1',
        { license }
    )
    if not rows or #rows == 0 then return nil end
    local d = rows[1].discord_id
    if d == nil or d == '' then return nil end
    return d
end

-- Sincroniza a axl_whitelist quando o jogador foi aprovado direto no
-- vrp_users.

function AXL.syncWhitelistFromVrpUsers(user_id, license, source)
    if not user_id or not license then return false end
    if not AXL.isUserWhitelisted(user_id) then return false end
    if AXL.isLicenseWhitelisted(license) then return false end

    local discord = nil
    if source and source > 0 then
        discord = AXL.getDiscord(source)
    end
    if not discord or discord == '' then
        discord = AXL.getUserDiscord(user_id)
    end

    AXL.markLicenseWhitelisted(license, discord, tostring(user_id))

    if AXL.logCreatorWebhook then
        AXL.logCreatorWebhook(license, user_id)
    end

    if Config.debugMode then
        print(('^5[axl_creator:helpers:wl-sync]^7 license=%s sincronizada (user_id=%d, discord=%s)'):format(
            license, user_id, tostring(discord)))
    end
    return true
end

-- Log de novo personagem no webhook (Config.creationWebhook).

local function formatCreatorWebhookContent(license, user_id)
    local discord = AXL.getWhitelistDiscord(license)
    if not discord or discord == '' then
        discord = AXL.getUserDiscord(user_id)
    end
    if not discord or discord == '' then discord = '?' end

    return table.concat({
        '**NOVO PERSONAGEM**',
        ('Discord: <@%s>'):format(tostring(discord)),
        ('License: %s'):format(tostring(license or '?')),
        ('ID: %s'):format(tostring(user_id or '?')),
    }, '\n')
end

function AXL.logCreatorWebhook(license, user_id)
    local cfg = Config and Config.creationWebhook
    if not cfg or cfg == '' then return end

    CreateThread(function()
        pcall(function()
            local content = formatCreatorWebhookContent(license, user_id)
            local payload = json.encode({ content = content, allowed_mentions = { parse = {} } })
            -- O 4o argumento traz o motivo quando o Discord recusa; sem ele o
            -- log falha calado e ninguém fica sabendo.
            PerformHttpRequest(cfg, function(status, _, _, erro)
                if status and (status < 200 or status >= 300) then
                    print(('^1[axl_creator]^7 webhook recusado (HTTP %s): %s')
                        :format(tostring(status), tostring(erro):sub(1, 300)))
                end
            end, 'POST', payload, {
                ['Content-Type'] = 'application/json',
            })
        end)
    end)
end

if Config.debugMode then
    print('^5[axl_creator:helpers]^7 módulo carregado (single-char, WL only)')
end
