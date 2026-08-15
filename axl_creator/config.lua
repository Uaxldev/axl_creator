-- axl_creator — configurações do creator de personagem.

print('^2[axl_creator]^7 config.lua carregando...')
Config = {}

-- true = loga cada etapa do fluxo no console.
-- Alterna em runtime pelo console do server: /debugcreator on|off
Config.debugMode = false

Config.branding = {
    -- Logo da tela inicial: nome do arquivo colocado em axl_creator/nui/
    -- (ex.: 'logo.png') ou URL. Vazio = só o nome da cidade em texto.
    logoUrl    = '',
    cityName   = 'UnityDev - vRPEX',
    tagline    = 'Criação de Personagem',
    slogan     = 'Acesse UnityDev - vRPEX',
    -- Link mostrado na etapa de whitelist. Vazio = a tela avisa que falta configurar.
    discordUrl = 'https://discord.gg/KaEZ6DBJPa',

    -- Logo da sidebar do creator. Mesmas regras do logoUrl acima.
    creatorSidebarLogo = '',
}

-- TEMA — accent é o destaque, dark os fundos, gray os textos secundários; o
-- resto da interface sai deles. Aceita hex ('#71368a') ou 'r, g, b'.
Config.theme = {
    accent = '#71368a',

    -- Hover dos botões. Vazio = derivado do accent, mais claro.
    accentLight = '#9e5cbb',

    dark = '#0a0a0a',
    gray = '#8a8798',

    -- Status
    ok     = '#22c55e',
    warn   = '#f59e0b',
    danger = '#ef4444',
}

-- CÂMERA — posição e tamanho da barra de controles (slider 360° + zoom).
Config.creatorCamera = {
    -- Orientação da barra: 'horizontal' (rodapé) ou 'vertical' (lateral esquerda).
    orientation = 'horizontal',

    -- ===== MODO HORIZONTAL =====
    -- Distância do rodapé.
    bottomOffset = '1rem',

    -- Deslocamento horizontal. 0 = centralizado na tela;
    -- positivo joga pra esquerda, negativo pra direita.
    horizontalShift = '0rem',

    -- ===== MODO VERTICAL =====
    -- Distância do topo da tela.
    topOffset = '8rem',

    -- Distância da lateral esquerda
    leftOffset = '22rem',

    -- ===== TAMANHOS =====
    -- Largura do slider no modo horizontal, altura no vertical.
    sliderLength = '12rem',

    -- Tamanho dos botões de lupa (quadrado).
    buttonSize = '2.5rem',

    -- Tamanho dos ícones de lupa (em px, não rem).
    iconSize = 18,
}

Config.commands = {
    openCreator = 'abrircreator',
    resetChar   = 'resetchar',
}

Config.permissions = {
    -- Quem pode abrir o creator pelo comando (modo showroom, não grava nada).
    openCreator = { 'owner.permissao' },
    -- Quem pode usar /resetchar <id> pra jogar outro player no creator.
    resetChar   = { 'admin.permissao' },
}

-- Webhook do Discord avisado quando uma whitelist é aprovada.
-- Vazio = desligado.
Config.creationWebhook = ''

Config.notify = {
    type  = 'base',
    event = 'Notify',
}

-- LUGARES — pegue as coordenadas no jogo com /coords.
-- O `h` é a direção pra onde o personagem olha.
Config.coords = {
    -- Onde o jogador monta o personagem.
    studio     = { x = 402.55,   y = -996.37,  z = -99.01, h = 180.0 },

    -- Onde ele nasce quando termina tudo e entra na cidade.
    finalSpawn = { x = -271.5,   y = -1906.19, z = 27.76,  h = 323.15 },

    -- Ponto neutro usado enquanto o personagem carrega.
    prepare    = { x = -1170.57, y = -1644.02, z = 4.38 },
}

-- FUNDO DA WHITELIST — `fundo`: 'cenario', 'imagem', 'video' ou 'nenhum'.
-- Imagem/vídeo vão em axl_creator/nui/ (só o nome) ou URL: png, jpg, webp, mp4.
Config.whitelistFundo = {
    fundo = 'cenario',

    -- Usado quando fundo = 'imagem' ou 'video'
    imagem = '',      -- ex.: 'cidade.jpg'
    video  = '',      -- ex.: 'cidade.mp4'

    -- Usado quando fundo = 'cenario'. `cam` é onde a câmera fica
    -- e `alvo` é pra onde ela olha.
    cam   = { x = -1043.0, y = -2745.0, z = 60.0 },
    alvo  = { x = -1100.0, y = -2900.0, z = 30.0 },
    girar = true,
    -- Graus por segundo do giro.
    velocidadeGiro = 1.2,
}

Config.rewards = {
    -- Dinheiro entregue na carteira. 0 = não entrega nada.
    money = 5000,

    -- Itens entregues no inventário. `name` = idname do item no vRP.
    items = {
        { name = 'celular', amount = 1 },
        { name = 'mochila', amount = 3 },
        { name = 'radio',   amount = 1 },
        { name = 'identidade', amount = 1 },
        { name = 'resetarpersonagem', amount = 1 },
    },
    -- VIP inicial, dado uma vez ao criar o personagem: nome do group
    -- em vrp/cfg/groups.lua. Vazio = sem VIP.
    vipGroup = '',

    -- true = registra em vrp_vips e expira sozinho (o group precisa ter
    -- `gtype = "vip"` e `dias` no groups.lua). false = só dá o group.
    vipUseVrpNative = false,

}

-- VEÍCULOS INICIAIS — `id` é o spawn name, precisa existir em vrp/cfg/vehicles.lua;
-- `image` é o PNG em nui/ (só o nome) ou URL. Lista vazia = identidade sem veículo.
Config.starterCars = {
    { id = 'primo',       name = 'Primo',       tagline = 'Popular',   image = 'primo.png' },
    { id = 'freecrawler', name = 'Freecrawler', tagline = 'Esportivo', image = 'freecrawler.png' },
    { id = 'enduro',      name = 'Enduro',      tagline = 'Moto',      image = 'enduro.png' },
}

-- ROUPAS PADRÃO — formato do /vroupas2: {drawable, texture, palette}. Número =
-- componente, "p0".."p7" = prop, drawable -1 tira a peça. Cabelo [2] é da barbearia.
Config.startClothes = {
    male = {
        [1] = {0,0,2},
        [3] = {0,0,1},
        [4] = {0,1,1},
        [5] = {0,0,2},
        [6] = {1,1,1},
        [7] = {0,0,2},
        [8] = {15,0,2},
        [9] = {0,0,2},
        [10] = {0,0,2},
        [11] = {0,0,1},
        [0] = {0,0,0},
        ["p7"] = {-1,0},
        ["p2"] = {-1,0},
        ["p6"] = {-1,0},
        ["p0"] = {-1,0},
        ["p1"] = {-1,0},
    },
    female = {
        [1] = {0,0,2},
        [3] = {14,0,1},
        [4] = {0,0,1},
        [5] = {0,0,2},
        [6] = {1,0,2},
        [7] = {0,0,2},
        [8] = {14,0,2},
        [9] = {0,0,2},
        [10] = {0,0,2},
        [11] = {73,0,1},
        [0] = {0,0,0},
        ["p7"] = {-1,0},
        ["p6"] = {-1,0},
        ["p2"] = {-1,0},
        ["p1"] = {-1,0},
        ["p0"] = {-1,0},
    },
}

Config.integrations = {
    -- Reaplica cabelo/barba e tatuagens no ped ao criar o personagem.
    barbershop          = true,
    tattoos             = true,

    -- Resource externo de auth por Discord. Vazio = o creator cuida do fluxo.
    -- Preenchido, ele precisa chamar exports['axl_creator']:processSpawn(source, user_id).
    discordAuthResource = '',
}

-- Botão esquerdo gira o personagem, direito move a câmera, roda dá zoom.
Config.camera = {
    rotateSpeed     = 1.5,
    initialDistance = 1.4,
    zoomStep        = 0.3,
    orbitSpeed      = 0.4,    -- graus por pixel, no botão direito
    heightSpeed     = 0.004,  -- metros por pixel, subir e descer
    heightMin       = -1.1,   -- até onde a câmera desce (pés)
    heightMax       = 0.6,    -- e sobe
}

Config.idade = { min = 18, max = 99 }

Config.limitsOverride = {}

Config.messages = {
    onlyLogin  = 'Você precisa estar logado.',
    notAdmin   = 'Você não tem permissão.',
    notOnline  = 'Player não está online.',
    resetOther = 'Personagem de ID %s foi resetado.',
    resetSelf  = 'Seu personagem foi resetado. Aguarde o creator abrir.',
}

Config.texts = {
    common = {
        back='Voltar', next='Próximo', reset='Resetar',
        close='Fechar', save='Finalizar', saving='Finalizando...',
        footer='© UnityDev - Axldev',
    },
    whitelist = {
        step='Etapa 4 de 4', title='Verificação de Whitelist', titleAccent='Whitelist',
        idLabel='Seu ID',
        charLabel='Personagem', ageLabel='Idade', ageSuffix='anos',
        idleTitle='Quase lá', idleTitleGreet='Quase lá, %s',
        idleDesc='Personagem criado com sucesso! Para entrar na cidade, precisamos verificar sua whitelist.',
        checkingTitle='Verificando', checkingDesc='Consultando o banco de dados...',
        okTitle='Whitelist aprovada', okDesc='Tudo certo! Entrando na cidade...',
        failTitle='Você ainda não tem whitelist',
        failDesc='Entre no nosso Discord, vá até o canal de whitelist. Depois volte aqui e clique em verificar novamente.',
        btnVerify='Verificar whitelist', btnVerifyAgain='Verificar novamente', btnDiscord='Abrir Discord',
    },
    transition = {
        welcomeSmall='UnityDev', welcomeTitle='Bem-vindo',
        messages={ 'Conectando à cidade', 'Preparando seu personagem', 'Calibrando o espelho', 'Aguarde' },
        startTag='initializing', endTag='ready',
    },
    face = {
        step='Etapa 1 de 4', title='Aparência', subtitle='Ajuste o rosto do seu personagem',
        cameraLabel='Câmera',
        cameraHintOk='Zoom disponível',
        cameraHintLock='Zoom só em 0° · clique pra voltar',
        tabs={ dna='DNA', rosto='Rosto', olhos='Olhos' },
        gender={ label='Gênero', masculine='Masculino', feminine='Feminino' },
        genetic={ label='Genética', father='Pai', mother='Mãe', mix='Mistura (pai <-> mãe)' },
        skin={ label='Pele', tone='Tom de pele' },
        eyes={
            label='Cor dos olhos',
            openingLabel='Abertura dos olhos',
            opening='Abrir / fechar',
            tooltip='Arraste o slider pra mudar a cor. Mexa o dial pra ajustar a abertura dos olhos.',
        },
        groups={
            nose       ={ label='Nariz',            width='Largura', height='Altura', length='Comprimento', bridge='Ponte', tip='Ponta', shift='Inclinação' },
            eyebrows   ={ label='Sobrancelhas',     height='Altura', width='Largura' },
            cheekbones ={ label='Bochechas',        boneHeight='Altura osso', boneWidth='Largura osso', faceWidth='Largura face' },
            mouth      ={ label='Boca e Mandíbula', lips='Lábios', jawWidth='Mand. largura', jawHeight='Mand. altura' },
            chin       ={ label='Queixo',           length='Comprimento', position='Posição', width='Largura', shape='Forma' },
            neck       ={ label='Pescoço',          width='Largura' },
        },
    },
    head = {
        step='Etapa 2 de 4', title='Cabelo', subtitle='Cabelo, barba, maquiagem e pele',
        tabs={ cabelo='Cabelo', maquiagem='Maquiagem', pele='Pele' },
        sections={
            hair      ={
                label='Cabelo', model='Modelo',
                color1='Cor principal', color2='Cor da mecha',
                highlightNone='Sem mecha', highlightOn='Com mecha',
            },
            eyebrows  ={ label='Sobrancelhas',   model='Modelo' },
            beard     ={ label='Barba',          model='Modelo' },
            chest     ={ label='Pelo corporal',  model='Modelo' },
            makeup    ={ label='Base',           model='Estilo' },
            blush     ={ label='Blush',          model='Modelo' },
            lipstick  ={ label='Batom',          model='Modelo' },
            blemishes ={ label='Imperfeições',   acne='Acne / manchas', freckles='Sardas' },
            ageing    ={ label='Idade e aspecto', ageing='Envelhecimento', complexion='Aspecto', sundamage='Dano solar' },
            bodyMarks ={
                label='Marcas no corpo',
                scars='Marca', extra='Marca extra',
                hint='Visíveis em roupas que mostram peito/costas (regata, sem camisa).',
            },
        },
    },
    confirm = {
        step='Etapa 3 de 4', title='Identidade', subtitle='Últimos detalhes antes de entrar na cidade',
        identity={
            label='Identidade', fullName='Nome completo',
            firstName='Primeiro nome', lastName='Sobrenome',
            age='Idade', ageMin='mínimo %d anos', ageError='A cidade aceita apenas %d a 99 anos.',
        },
        vehicle={
            label='Veículo inicial', empty='Nenhum veículo disponível.',
            emptyHint='(Configure em config.lua -> Config.starterCars)',
        },
    },
    discord = {
        sectionLabel='Entrar no Discord',
        title='Copie o link abaixo',
        description='O FiveM não permite abrir links externos automaticamente. Copie e cole no seu navegador.',
        linkLabel='Link do Discord',
        hintInstruction='Alt+Tab, cole no navegador, entre no canal de whitelist e volte aqui.',
        btnCopy='Copiar link', btnCopied='Copiado!',
        placeholderTitle='Link não configurado',
        placeholderDesc='O administrador da cidade ainda não configurou o link do Discord.',
        placeholderWarn='Configuração pendente',
        placeholderBody='O link atual é o padrão do creator. Peça ao admin da cidade para editar o arquivo:',
        placeholderFoot='Enquanto isso, você pode procurar o Discord oficial da cidade manualmente.',
    },
}
