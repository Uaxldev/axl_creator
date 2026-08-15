# axl_creator

Criador de personagem em 4 etapas (Aparência → Cabelo → Identidade → Whitelist) + entrega de itens iniciais + transição cinematográfica pra cidade.

Interface em HTML/CSS/JS puro, em `nui/` — sem build e sem `node_modules`. Editou o arquivo, deu restart no resource, está valendo.

---

## Como funciona

1. Player entra na cidade pela primeira vez → creator abre automaticamente
2. **Etapa 1 — Aparência**: gênero, genética (pai/mãe/mistura), pele, rosto, olhos
3. **Etapa 2 — Cabelo**: cabelo, sobrancelhas, barba, maquiagem, marcas no corpo
4. **Etapa 3 — Identidade**: nome, sobrenome, idade, escolha do veículo inicial
5. **Etapa 4 — Whitelist**: tela mostra o ID do passaporte e botão pra abrir o Discord. Player faz a WL no bot e volta aqui pra clicar em **Verificar**
6. WL aprovada → entrega rewards (dinheiro, itens, VIP opcional, veículo escolhido) → câmera cinematográfica desce do céu → axl_spawn assume

Comandos disponíveis (configuráveis):
- `/abrircreator` — reabre o creator (modo cosmético, sem trocar nome/itens)
- `/resetchar [id]` — reseta personagem (zera aparência, força creator de novo)

---

## Setup

### 1. Discord da cidade

Edita `Config.branding.discordUrl` no `config.lua`. O botão **Abrir Discord** da tela de WL usa esse link.

### 2. Bot de whitelist (opcional mas recomendado)

Veja o `LEIA-ME INFOS.md` da pasta `axl_bot_whitelist`. Sem o bot, a whitelist precisa ser aprovada manualmente via SQL (`UPDATE vrp_users SET whitelisted=1 WHERE id=X`).

### 3. Logo da cidade

`Config.branding.logoUrl` aceita URL externa OU arquivo local. Pra usar local, joga o arquivo em `axl_creator/nui/logo.png` e seta `logoUrl = 'logo.png'`. Mesmo vale pra `creatorSidebarLogo` (logo da sidebar). Vazio nos dois = sem logo, só o nome da cidade em texto.


---

## O que pode ser customizado (`config.lua`)

### `Config.branding`
Logo principal, nome da cidade, tagline, slogan, link do Discord, logo da sidebar.

### `Config.theme` — sistema de cores simplificado
Mexe em **3 cores** e o resto se ajusta sozinho:
- `accent` — cor principal (botões, bordas, slider, ícones, glow)
- `dark` — fundos (painel, cards, modais)
- `gray` — textos e bordas finas

Tem opções avançadas (`accentLight`, `accentGlow`, `accentSoft`, `accentBorder`) pra ajuste fino do hover dos botões

### `Config.creatorCamera` — barra de controles da câmera
Posição e tamanho da barrinha que rotaciona o ped. Padrão é horizontal no rodapé. Pode trocar pra vertical na lateral.

### `Config.commands` + `Config.permissions`
Renomeia os comandos (`abrircreator`, `resetchar`) e define quem pode usar (`'everyone'`, `'admin'`, etc.).

### `Config.creationWebhook`
URL de webhook do Discord. Posta um log toda vez que uma WL é aprovada (com ID, Discord, license). Vazio = desligado.

### `Config.coords`
- `studio` → onde o ped fica durante o creator (interior do estúdio do GTA)
- `finalSpawn` → coords pro player aparecer DEPOIS de aprovado
- `prepare` → ponto invisível usado pelo cinematic durante a transição

### `Config.rewards` — recompensas iniciais
- `money` → quantia em dinheiro na carteira (vRP.giveMoney). 0 = nada
- `items` → lista de itens entregues no inventário (idname + quantidade)
- `vipGroup` → group VIP opcional dado UMA vez por user_id. Vazio = sem VIP
- `vipUseVrpNative` → ler comentário detalhado no config (true exige `_config` completo no `groups.lua`)

### `Config.starterCars` — carros iniciais
Lista de veículos pro player escolher na Etapa 3. Cada item: `id` (spawn name do GTA), `name`, `tagline`, `image` (PNG em `nui/`). Imagem vazia ou que não carregue = mostra só o nome.

### `Config.startClothes` — roupa padrão (masc + fem)
Mesmo formato do `/vroupas2` da unity_core. Use o comando in-game pra extrair, copia o output e cola aqui.

### `Config.integrations`
Liga/desliga integração com `vrp_barbershop` e `vrp_tattoo` (botões na sidebar do creator). `discordAuthResource` se você usa um sistema externo de auth Discord (deixa vazio se não usa).

### `Config.idade`
Faixa permitida pro campo "Idade" na Etapa 3 (`min = 18`, `max = 99` por padrão).

### `Config.messages` + `Config.texts`
**TODOS os textos da UI estão aqui** — labels, títulos, descrições, placeholders, mensagens de erro. Mude pra outro idioma só editando este bloco. Cobertura completa:
- `common` — botões genéricos (Voltar, Próximo, etc.)
- `whitelist` — tela de WL
- `transition` — tela de loading entre WL e cidade
- `face` / `head` / `confirm` — labels das 3 etapas do creator
- `discord` — modal do botão "Abrir Discord"

### `Config.notify`
Tipo de notify usado nas mensagens (`'base'` usa o evento `Notify` da base; `'internal'` usa o do próprio resource).

### `Config.debugMode`
Em produção (cidade com 100+ players), deixa `false`. Liga só pra debugar — gera logs verbosos.

---

## Comandos do console (admin)

- `/axllimits` — detecta automaticamente os limites máximos de cada feature do ped (overhead, sobrancelhas, barba, etc.) e popula `Config.limitsOverride`. Útil se você adicionou DLCs novas

---


## Troubleshooting

**Creator não abre**
- `axl_creator` deu ensure no `resources.cfg`?
- Tabela `vrp_users` tem o user_id do player?
- Já tem personagem criado? Use `/resetchar` pra forçar abrir de novo

**Cores não mudam após editar `Config.theme`**
- Salvou o arquivo?
- `restart axl_creator` no console (NÃO `refresh`)

**Botão Discord abre URL errada**
- Edita `Config.branding.discordUrl`. Se o link aparece como placeholder, é porque tá no valor padrão do creator — precisa trocar

**Veículo escolhido não aparece**
- O `id` em `starterCars` precisa existir em `vrp/cfg/vehicles.lua` (mesma chave). Spawn names que não estão registrados no vRP não funcionam

**Roupa volta pro padrão depois do barbershop**
- Bug conhecido em versões antigas — corrigido. Atualiza pro `axl_creator` da base atual

**Webhook não posta log de criação**
- URL está correta?
- A WL foi aprovada via bot/SQL? O webhook só dispara na transição `whitelisted 0 → 1`
