/* AXL Creator — valores e textos padrão da interface.
   O config.lua sobrescreve tudo isso via SendNUIMessage.
   Pra mudar um texto, mexa no config.lua — não aqui. */

window.AXL = window.AXL || {};
AXL.config = AXL.config || {};

AXL.config.TEXTOS_PADRAO = {
  common: {
    back:   'Voltar',
    next:   'Próximo',
    reset:  'Resetar',
    close:  'Fechar',
    save:   'Finalizar',
    saving: 'Finalizando...',
    footer: '© UnityDev - Axldev',
  },
  whitelist: {
    step: 'Etapa 4 de 4',
    title: 'Verificação de Whitelist',
    titleAccent: 'Whitelist',
    idLabel: 'Seu ID',
    charLabel: 'Personagem',
    ageLabel: 'Idade',
    ageSuffix: 'anos',
    idleTitle: 'Quase lá',
    idleDesc: 'Personagem criado com sucesso! Para entrar na cidade, precisamos verificar sua whitelist.',
    checkingTitle: 'Verificando',
    checkingDesc: 'Consultando o banco de dados...',
    okTitle: 'Whitelist aprovada',
    okDesc: 'Tudo certo! Entrando na cidade...',
    idleTitleGreet: 'Quase lá, %s',
    failTitle: 'Você ainda não tem whitelist',
    failDesc: 'Entre no nosso Discord, vá até o canal de whitelist e faça a prova. Depois volte aqui e clique em verificar novamente.',
    btnVerify: 'Verificar whitelist',
    btnVerifyAgain: 'Verificar novamente',
    btnDiscord: 'Abrir Discord',
  },
  transition: {
    welcomeSmall: 'UnityDev - Axldev',
    welcomeTitle: 'Bem-vindo',
    messages: ['Conectando à cidade', 'Preparando seu personagem', 'Calibrando o espelho', 'Aguarde'],
    startTag: 'initializing',
    endTag: 'ready',
  },
  face: {
    step: 'Etapa 1 de 4',
    title: 'Aparência',
    subtitle: 'Ajuste o rosto do seu personagem',
    cameraLabel: 'Câmera',
    cameraHintOk: 'Zoom disponível',
    cameraHintLock: 'Zoom só em 0° · clique pra voltar',
    tabs: { dna: 'DNA', rosto: 'Rosto', olhos: 'Olhos' },
    gender: { label: 'Gênero', masculine: 'Masculino', feminine: 'Feminino' },
    genetic: { label: 'Genética', father: 'Pai', mother: 'Mãe', mix: 'Mistura (pai ↔ mãe)' },
    skin: { label: 'Pele', tone: 'Tom de pele' },
    eyes: {
      label: 'Cor dos olhos',
      openingLabel: 'Abertura dos olhos',
      opening: 'Abrir / fechar',
      tooltip: '💡 Arraste o slider pra mudar a cor. Mexa o dial pra ajustar a abertura dos olhos.',
    },
    groups: {
      nose:       { label: 'Nariz', width: 'Largura', height: 'Altura', length: 'Comprimento', bridge: 'Ponte', tip: 'Ponta', shift: 'Inclinação' },
      eyebrows:   { label: 'Sobrancelhas', height: 'Altura', width: 'Largura' },
      cheekbones: { label: 'Bochechas', boneHeight: 'Altura osso', boneWidth: 'Largura osso', faceWidth: 'Largura face' },
      mouth:      { label: 'Boca e Mandíbula', lips: 'Lábios', jawWidth: 'Mand. largura', jawHeight: 'Mand. altura' },
      chin:       { label: 'Queixo', length: 'Comprimento', position: 'Posição', width: 'Largura', shape: 'Forma' },
      neck:       { label: 'Pescoço', width: 'Largura' },
    },
  },
  head: {
    step: 'Etapa 2 de 4',
    title: 'Cabelo e detalhes',
    subtitle: 'Cabelo, barba, maquiagem e pele',
    tabs: { cabelo: 'Cabelo', maquiagem: 'Maquiagem', pele: 'Pele' },
    sections: {
      hair: {
        label: 'Cabelo', model: 'Modelo',
        color1: 'Cor principal', color2: 'Cor da mecha',
        highlightNone: 'Sem mecha', highlightOn: 'Com mecha',
      },
      eyebrows:  { label: 'Sobrancelhas', model: 'Modelo' },
      beard:     { label: 'Barba', model: 'Modelo' },
      chest:     { label: 'Pelo corporal', model: 'Modelo' },
      makeup:    { label: 'Base', model: 'Estilo' },
      blush:     { label: 'Blush', model: 'Modelo' },
      lipstick:  { label: 'Batom', model: 'Modelo' },
      blemishes: { label: 'Imperfeições', acne: 'Acne / manchas', freckles: 'Sardas' },
      ageing:    { label: 'Idade e aspecto', ageing: 'Envelhecimento', complexion: 'Aspecto', sundamage: 'Dano solar' },
      bodyMarks: {
        label: 'Marcas no corpo',
        scars: 'Marca', extra: 'Marca extra',
        hint: 'Visíveis em roupas que mostram peito/costas (regata, sem camisa).',
      },
    },
  },
  confirm: {
    step: 'Etapa 3 de 4',
    title: 'Identidade',
    subtitle: 'Últimos detalhes antes de entrar na cidade',
    identity: {
      label: 'Identidade',
      fullName: 'Nome completo',
      firstName: 'Primeiro nome',
      lastName: 'Sobrenome',
      age: 'Idade',
      ageMin: 'mínimo %d anos',
      ageError: 'A cidade aceita apenas maiores de %d anos.',
    },
    vehicle: {
      label: 'Veículo inicial',
      empty: 'Nenhum veículo disponível.',
      emptyHint: '(Configure em config.lua → Config.starterCars)',
    },
  },
  discord: {
    sectionLabel: 'Entrar no Discord',
    title: 'Copie o link abaixo',
    description: 'O FiveM não permite abrir links externos automaticamente. Copie e cole no seu navegador.',
    linkLabel: 'Link do Discord',
    hintInstruction: 'Alt+Tab, cole no navegador, entre no canal de whitelist e volte aqui.',
    btnCopy: 'Copiar link',
    btnCopied: 'Copiado!',
    placeholderTitle: 'Link não configurado',
    placeholderDesc: 'O administrador da cidade ainda não configurou o link do Discord.',
    placeholderWarn: 'Configuração pendente',
    placeholderBody: 'O link atual é o padrão do creator. Peça ao admin da cidade para editar o arquivo:',
    placeholderFoot: 'Enquanto isso, você pode procurar o Discord oficial da cidade manualmente.',
  },
  characterSelect: {
    sectionLabel:    'Personagens',
    title:           'Selecionar',
    titleAccent:     'Selecionar',
    subtitle:        'Escolha um personagem ou crie um novo',
    slotLabel:       'Slot %d',
    slotEmpty:       'Vazio',
    slotPlay:        'Jogar',
    slotCreate:      'Criar Personagem',
    slotDelete:      'Apagar',
    emptyTitle:      'Slot disponível',
    emptyDesc:       'Crie seu personagem agora',
    passportLbl:     'Passaporte',
    ageLbl:          'anos',
    lastPlayedLbl:   'Última vez',
    confirmDelTitle: 'Apagar personagem',
    confirmDelDesc:  'Tem certeza? %s será apagado pra sempre.',
    confirmDelYes:   'Sim, apagar',
    confirmDelNo:    'Cancelar',
  },
}
AXL.config.PADRAO = {
  branding: {
    logoUrl:    '',
    cityName:   'UnityDev - Axldev',
    tagline:    'Cidade Virtual',
    slogan:     '',
    discordUrl: '',
  },
  idade: { min: 18, max: 99 },
  mode:  'new',
  skipWL: false,
  slot:   1,
  starterCars: [],
  characters: { maxSlots: 2, allowDelete: true },
  creatorCamera: {
    orientation:     'horizontal',
    bottomOffset:    '1rem',
    horizontalShift: '0rem',     // 0 = centralizado no viewport
    topOffset:       '8rem',
    leftOffset:      '22rem',
    sliderLength:    '12rem',
    buttonSize:      '2.5rem',
    iconSize:        18,
  },
  texts: AXL.config.TEXTOS_PADRAO,
  // Fundo da tela de whitelist: 'nenhum', 'imagem', 'video' ou 'cenario'.
  whitelistFundo: { fundo: 'nenhum', imagem: '', video: '' },
  limits: {
    fathersID: { min: 0, max: 45 },
    mothersID: { min: 0, max: 45 },
    skinColor: { min: 0, max: 10 },
    hairModel:       { min: 0, max: 40 },
    firstHairColor:  { min: 0, max: 63 },
    secondHairColor: { min: 0, max: 63 },
    eyebrowsModel: { min: -1, max: 33 },
    eyebrowsColor: { min: 0,  max: 63 },
    beardModel: { min: -1, max: 28 },
    beardColor: { min: 0,  max: 63 },
    chestModel: { min: -1, max: 16 },
    chestColor: { min: 0,  max: 63 },
    makeupModel:   { min: -1, max: 33 },
    blushModel:    { min: -1, max: 7  },
    blushColor:    { min: 0,  max: 31 },
    lipstickModel: { min: -1, max: 9  },
    lipstickColor: { min: 0,  max: 31 },
    blemishesModel:  { min: -1, max: 23 },
    ageingModel:     { min: -1, max: 14 },
    complexionModel: { min: -1, max: 11 },
    sundamageModel:  { min: -1, max: 10 },
    frecklesModel:   { min: -1, max: 17 },
    eyesColor: { min: 0, max: 30 },
  },
}

/* Config em uso: o padrão mais o que o Lua mandou. */
AXL.config.atual = null;

/** Junta o config do Lua com o atual. Array é substituído inteiro, nunca mesclado. */
AXL.config.merge = function merge(base, patch) {
    if (!patch || typeof patch !== 'object') return base;
    var saida = Array.isArray(base) ? base.slice() : Object.assign({}, base);
    for (var k in patch) {
        if (!Object.prototype.hasOwnProperty.call(patch, k)) continue;
        var v = patch[k];
        if (v && typeof v === 'object' && !Array.isArray(v)
            && saida[k] && typeof saida[k] === 'object' && !Array.isArray(saida[k])) {
            saida[k] = merge(saida[k], v);
        } else {
            saida[k] = v;
        }
    }
    return saida;
};

/** Aplica um pedaço de config vindo do Lua. */
AXL.config.aplicar = function (patch) {
    if (!AXL.config.atual) AXL.config.atual = AXL.config.merge({}, AXL.config.PADRAO);
    AXL.config.atual = AXL.config.merge(AXL.config.atual, patch);
    return AXL.config.atual;
};

/** Config corrente, já com os padrões preenchidos. */
AXL.config.get = function () {
    if (!AXL.config.atual) AXL.config.atual = AXL.config.merge({}, AXL.config.PADRAO);
    return AXL.config.atual;
};

/** Busca um texto por caminho: t('whitelist.btnVerify').
 *  Se não achar, devolve o alt ou o próprio caminho. */
AXL.config.t = function (caminho, alt) {
    var no = AXL.config.get().texts;
    var partes = String(caminho).split('.');
    for (var i = 0; i < partes.length; i++) {
        if (!no || typeof no !== 'object') return alt !== undefined ? alt : caminho;
        no = no[partes[i]];
    }
    return (no === undefined || no === null) ? (alt !== undefined ? alt : caminho) : no;
};

/** Troca %s / %d pelos valores, na ordem. */
AXL.config.fmt = function (txt, /* ...valores */) {
    var vals = Array.prototype.slice.call(arguments, 1), i = 0;
    return String(txt).replace(/%[sd]/g, function () {
        return i < vals.length ? vals[i++] : '';
    });
};

/** "Etapa X de Y": 4 etapas no fluxo normal, 3 quando pula a whitelist. */
AXL.config.etapa = function (tela) {
    var c = AXL.config.get();
    var semWl = c.mode === 'reset' || c.skipWL === true;
    var ordem = semWl ? ['face', 'head', 'confirm']
                      : ['face', 'head', 'confirm', 'whitelist'];
    var i = ordem.indexOf(tela);
    if (i === -1) return '';
    return 'Etapa ' + (i + 1) + ' de ' + ordem.length;
};

/** Limite min/max de um campo, com valor de reserva. */
AXL.config.limite = function (chave, minPadrao, maxPadrao) {
    var l = (AXL.config.get().limits || {})[chave];
    return {
        min: (l && typeof l.min === 'number') ? l.min : (minPadrao || 0),
        max: (l && typeof l.max === 'number') ? l.max : (maxPadrao || 0)
    };
};
