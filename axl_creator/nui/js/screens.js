/* =====================================================================
   AXL Creator — as telas
   =====================================================================
   Cada tela expõe { montar, desmontar }: o montar preenche os textos e
   cria os controles, o desmontar solta timers e listeners.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.screens = (function () {

    /* =================================================================
       ABERTURA
       =================================================================
       Passa as mensagens do config uma a uma, revela o ped e abre a etapa 1.
       ================================================================= */
    var transicao = (function () {
        var timers = [];

        function limpar() {
            timers.forEach(clearTimeout);
            timers = [];
        }

        function montar() {
            limpar();
            var t = AXL.config.get().texts.transition || {};
            var msgs = t.messages || [];
            var total = 2800;                       // duração total da abertura, em ms
            var passo = msgs.length ? total / msgs.length : total;

            var elTag  = document.getElementById('tr-tag');
            var elPeq  = document.getElementById('tr-pequeno');
            var elTit  = document.getElementById('tr-titulo');
            var elMsg  = document.getElementById('tr-msg');
            var elProg = document.getElementById('tr-progresso');

            if (elTag) elTag.textContent = t.startTag || '';
            if (elPeq) elPeq.textContent = t.welcomeSmall || '';
            if (elTit) elTit.textContent = t.welcomeTitle || '';
            if (elMsg) elMsg.textContent = msgs[0] || '';
            if (elProg) elProg.style.width = '0%';

            // Monta o personagem escondido; ele só aparece na etapa 1.
            AXL.nui.send('beginCreator', { revelar: false });

            msgs.forEach(function (m, i) {
                timers.push(setTimeout(function () {
                    if (elMsg)  elMsg.textContent = m;
                    if (elProg) elProg.style.width = (((i + 1) / msgs.length) * 100) + '%';
                }, passo * i));
            });

            timers.push(setTimeout(function () {
                if (elTag)  elTag.textContent = t.endTag || '';
                if (elProg) elProg.style.width = '100%';
                AXL.nui.send('revelarPed');
                AXL.app.irPara('face');
            }, total));
        }

        return { montar: montar, desmontar: limpar };
    })();

    /* =================================================================
       ETAPAS DE CRIAÇÃO (1 e 2)
       =================================================================
       As duas usam a mesma tela: abas > grupos > controles. O que muda é
       só a tabela de descritores lá embaixo.
       ================================================================= */

    function criarControle(d) {
        var lim = AXL.config.limite(d.chave, d.min, d.max);
        var comum = {
            label: d.rotulo,
            value: AXL.character.get(d.chave),
            onChange: function (v) { AXL.character.mudar(d.chave, v); }
        };

        var c;
        if (d.tipo === 'dial') {
            comum.min  = (d.min !== undefined) ? d.min : -1;
            comum.max  = (d.max !== undefined) ? d.max :  1;
            comum.step = d.step || 0.01;
            c = AXL.ui.dial(comum);
        } else {
            comum.min = lim.min; comum.max = lim.max;
            comum.permiteVazio = !!d.permiteVazio;
            c = AXL.ui.stepper(comum);
        }

        // Registro que faz o "Aleatorizar" mover todos os controles.
        AXL.controles[d.chave] = c;
        return c;
    }

    /* def = { voltar, avancar, abas: [{ id, rotulo, grupos: [{ titulo, itens }] }] } */
    function telaDeCriacao(id, def) {
        var vivos = [];   // controles criados nesta aba

        function limpar() {
            for (var i = 0; i < vivos.length; i++) {
                if (vivos[i].destroy) vivos[i].destroy();
                for (var k in AXL.controles) {
                    if (AXL.controles[k] === vivos[i]) delete AXL.controles[k];
                }
            }
            vivos = [];
        }

        function desenharAba(abaId) {
            var corpo = document.getElementById(id + '-corpo');
            if (!corpo) return;
            limpar();
            corpo.innerHTML = '';

            var aba = null;
            for (var i = 0; i < def.abas.length; i++) {
                if (def.abas[i].id === abaId) { aba = def.abas[i]; break; }
            }
            if (!aba) return;

            (aba.grupos || []).forEach(function (g) {
                var bloco = AXL.ui.el('div', 'grupo');
                if (g.titulo) bloco.appendChild(AXL.ui.el('span', 'grupo-titulo', g.titulo));

                (g.itens || []).forEach(function (d) {
                    if (d.tipo === 'duplo') {
                        // Par de botões: só um fica escolhido.
                        var par = AXL.ui.el('div', 'duplo');
                        d.opcoes.forEach(function (o) {
                            var b = AXL.ui.botao({
                                classe: 'btn-secundario',
                                texto: o.rotulo,
                                onClick: function () {
                                    d.aoEscolher(o.valor);
                                    var irmaos = par.querySelectorAll('.btn');
                                    for (var j = 0; j < irmaos.length; j++) {
                                        irmaos[j].classList.remove('escolhido');
                                    }
                                    b.classList.add('escolhido');
                                }
                            });
                            if (d.escolhido && d.escolhido() === o.valor) b.classList.add('escolhido');
                            par.appendChild(b);
                        });
                        bloco.appendChild(par);
                        return;
                    }
                    var c = criarControle(d);
                    vivos.push(c);
                    bloco.appendChild(c.el);
                });

                corpo.appendChild(bloco);
            });
        }

        return {
            montar: function () {
                var etapa = document.querySelector('[data-etapa="' + id + '"]');
                if (etapa) etapa.textContent = AXL.config.etapa(id);

                var tit = document.getElementById(id + '-titulo');
                var sub = document.getElementById(id + '-sub');
                if (tit) tit.textContent = AXL.config.t(id + '.title', '');
                if (sub) sub.textContent = AXL.config.t(id + '.subtitle', '');

                var hostAbas = document.getElementById(id + '-abas');
                if (hostAbas) {
                    hostAbas.innerHTML = '';
                    AXL.ui.abas(
                        def.abas.map(function (a) { return { id: a.id, rotulo: a.rotulo }; }),
                        desenharAba,
                        hostAbas
                    );
                }

                var rodape = document.getElementById(id + '-rodape');
                if (rodape) {
                    rodape.innerHTML = '';
                    if (def.voltar) {
                        rodape.appendChild(AXL.ui.botao({
                            classe: 'btn-secundario',
                            icone: 'setaEsq',
                            texto: AXL.config.t('common.back', 'Voltar'),
                            onClick: function () { AXL.nui.send(def.voltar); }
                        }));
                    }
                    if (def.avancar) {
                        rodape.appendChild(AXL.ui.botao({
                            classe: 'btn-primario btn-largo',
                            texto: AXL.config.t('common.next', 'Próximo'),
                            onClick: function () { AXL.nui.send(def.avancar); }
                        }));
                    }
                }
            },
            desmontar: limpar
        };
    }

    /* ----------------- descritores da etapa 1 (aparência) ------------- */
    function defFace() {
        var t = AXL.config.get().texts.face;
        var g = t.groups;

        function dials(grupo, pares) {
            return {
                titulo: grupo,
                itens: pares.map(function (p) {
                    return { tipo: 'dial', chave: p[0], rotulo: p[1], min: -1, max: 1, step: 0.01 };
                })
            };
        }

        return {
            voltar: null,
            avancar: 'goToHead',
            abas: [
                {
                    id: 'dna', rotulo: t.tabs.dna,
                    grupos: [
                        { titulo: t.gender.label, itens: [{
                            tipo: 'duplo',
                            opcoes: [
                                { rotulo: t.gender.masculine, valor: 1 },
                                { rotulo: t.gender.feminine,  valor: 2 }
                            ],
                            escolhido: function () { return AXL.app.S.sexo; },
                            aoEscolher: function (v) {
                                AXL.app.S.sexo = v;
                                AXL.nui.send('changeGender', { sex: v });
                            }
                        }]},
                        { titulo: t.genetic.label, itens: [
                            { tipo: 'stepper', chave: 'fathersID', rotulo: t.genetic.father, min: 0, max: 45 },
                            { tipo: 'stepper', chave: 'mothersID', rotulo: t.genetic.mother, min: 0, max: 45 },
                            { tipo: 'dial', chave: 'shapeMix', rotulo: t.genetic.mix, min: 0, max: 1, step: 0.01 }
                        ]},
                        { titulo: t.skin.label, itens: [
                            { tipo: 'stepper', chave: 'skinColor', rotulo: t.skin.tone, min: 0, max: 10 }
                        ]}
                    ]
                },
                {
                    id: 'rosto', rotulo: t.tabs.rosto,
                    grupos: [
                        dials(g.nose.label, [
                            ['noseWidth', g.nose.width], ['noseHeight', g.nose.height],
                            ['noseLength', g.nose.length], ['noseBridge', g.nose.bridge],
                            ['noseTip', g.nose.tip], ['noseShift', g.nose.shift]
                        ]),
                        dials(g.cheekbones.label, [
                            ['cheekboneHeight', g.cheekbones.boneHeight],
                            ['cheekboneWidth',  g.cheekbones.boneWidth],
                            ['cheeksWidth',     g.cheekbones.faceWidth]
                        ]),
                        dials(g.mouth.label, [
                            ['lips', g.mouth.lips], ['jawWidth', g.mouth.jawWidth],
                            ['jawHeight', g.mouth.jawHeight]
                        ]),
                        dials(g.chin.label, [
                            ['chinLength', g.chin.length], ['chinPosition', g.chin.position],
                            ['chinWidth', g.chin.width], ['chinShape', g.chin.shape]
                        ]),
                        dials(g.neck.label, [['neckWidth', g.neck.width]])
                    ]
                },
                {
                    id: 'olhos', rotulo: t.tabs.olhos,
                    grupos: [
                        { titulo: t.eyes.label, itens: [
                            { tipo: 'stepper', chave: 'eyesColor', rotulo: t.eyes.label, min: 0, max: 30 }
                        ]},
                        { titulo: t.eyes.openingLabel, itens: [
                            { tipo: 'dial', chave: 'eyesOpening', rotulo: t.eyes.opening, min: -1, max: 1, step: 0.01 }
                        ]}
                    ]
                }
            ]
        };
    }

    /* ----------------- descritores da etapa 2 (cabelo) ---------------- */
    function defHead() {
        var t = AXL.config.get().texts.head;
        var s = t.sections;

        return {
            voltar: 'backToFace',
            avancar: 'goToConfirm',
            abas: [
                {
                    id: 'cabelo', rotulo: t.tabs.cabelo,
                    grupos: [
                        { titulo: s.hair.label, itens: [
                            { tipo: 'stepper', chave: 'hairModel', rotulo: s.hair.model, min: 0, max: 40 },
                            { tipo: 'stepper', chave: 'firstHairColor', rotulo: s.hair.color1, min: 0, max: 63 },
                            { tipo: 'stepper', chave: 'secondHairColor', rotulo: s.hair.color2, min: 0, max: 63 }
                        ]},
                        { titulo: s.eyebrows.label, itens: [
                            { tipo: 'stepper', chave: 'eyebrowsModel', rotulo: s.eyebrows.model, min: -1, max: 33, permiteVazio: true },
                            { tipo: 'stepper', chave: 'eyebrowsColor', rotulo: s.hair.color1, min: 0, max: 63 },
                            { tipo: 'dial', chave: 'eyebrowsHeight', rotulo: AXL.config.t('face.groups.eyebrows.height', 'Altura'), min: -1, max: 1, step: 0.01 },
                            { tipo: 'dial', chave: 'eyebrowsWidth',  rotulo: AXL.config.t('face.groups.eyebrows.width', 'Largura'), min: -1, max: 1, step: 0.01 }
                        ]},
                        { titulo: s.beard.label, itens: [
                            { tipo: 'stepper', chave: 'beardModel', rotulo: s.beard.model, min: -1, max: 28, permiteVazio: true },
                            { tipo: 'stepper', chave: 'beardColor', rotulo: s.hair.color1, min: 0, max: 63 }
                        ]},
                        { titulo: s.chest.label, itens: [
                            { tipo: 'stepper', chave: 'chestModel', rotulo: s.chest.model, min: -1, max: 16, permiteVazio: true },
                            { tipo: 'stepper', chave: 'chestColor', rotulo: s.hair.color1, min: 0, max: 63 }
                        ]}
                    ]
                },
                {
                    id: 'maquiagem', rotulo: t.tabs.maquiagem,
                    grupos: [
                        { titulo: s.makeup.label, itens: [
                            { tipo: 'stepper', chave: 'makeupModel', rotulo: s.makeup.model, min: -1, max: 33, permiteVazio: true }
                        ]},
                        { titulo: s.blush.label, itens: [
                            { tipo: 'stepper', chave: 'blushModel', rotulo: s.blush.model, min: -1, max: 7, permiteVazio: true },
                            { tipo: 'stepper', chave: 'blushColor', rotulo: s.hair.color1, min: 0, max: 31 }
                        ]},
                        { titulo: s.lipstick.label, itens: [
                            { tipo: 'stepper', chave: 'lipstickModel', rotulo: s.lipstick.model, min: -1, max: 9, permiteVazio: true },
                            { tipo: 'stepper', chave: 'lipstickColor', rotulo: s.hair.color1, min: 0, max: 31 }
                        ]}
                    ]
                },
                {
                    id: 'pele', rotulo: t.tabs.pele,
                    grupos: [
                        { titulo: s.blemishes.label, itens: [
                            { tipo: 'stepper', chave: 'blemishesModel', rotulo: s.blemishes.acne, min: -1, max: 23, permiteVazio: true },
                            { tipo: 'stepper', chave: 'frecklesModel', rotulo: s.blemishes.freckles, min: -1, max: 17, permiteVazio: true }
                        ]},
                        { titulo: s.ageing.label, itens: [
                            { tipo: 'stepper', chave: 'ageingModel', rotulo: s.ageing.ageing, min: -1, max: 14, permiteVazio: true },
                            { tipo: 'stepper', chave: 'complexionModel', rotulo: s.ageing.complexion, min: -1, max: 11, permiteVazio: true },
                            { tipo: 'stepper', chave: 'sundamageModel', rotulo: s.ageing.sundamage, min: -1, max: 10, permiteVazio: true }
                        ]},
                        { titulo: s.bodyMarks.label, itens: [
                            { tipo: 'stepper', chave: 'bodyBlemishes', rotulo: s.bodyMarks.scars, min: -1, max: 11, permiteVazio: true },
                            { tipo: 'stepper', chave: 'bodyBlemishesAdd', rotulo: s.bodyMarks.extra, min: -1, max: 11, permiteVazio: true }
                        ]}
                    ]
                }
            ]
        };
    }

    /* Os descritores são montados na hora de abrir a tela: antes disso os
       textos do config ainda não chegaram. */
    function telaFace() {
        var real = null;
        return {
            montar: function () { real = telaDeCriacao('face', defFace()); real.montar(); },
            desmontar: function () { if (real) real.desmontar(); }
        };
    }
    function telaHead() {
        var real = null;
        return {
            montar: function () { real = telaDeCriacao('head', defHead()); real.montar(); },
            desmontar: function () { if (real) real.desmontar(); }
        };
    }

    /* =================================================================
       ETAPA 3 — IDENTIDADE
       =================================================================
       Nome, sobrenome, idade e veículo inicial. O botão de finalizar só
       habilita com tudo preenchido e trava enquanto o jogo grava.
       ================================================================= */
    function telaConfirm() {
        var form = { name: '', surname: '', age: 18, vehicle: '' };
        var salvando = false;
        var btnSalvar = null;

        function idadeMin() { return (AXL.config.get().idade || {}).min || 18; }
        function idadeMax() { return (AXL.config.get().idade || {}).max || 99; }

        /* No /resetchar o personagem só troca de aparência: o servidor não
           entrega carro, então a escolha nem aparece. */
        function ehReset() {
            return AXL.config.get().mode === 'reset';
        }

        /* Lista vazia no Lua chega como {} no JSON, não como []. */
        function listaCarros() {
            if (ehReset()) return [];
            var c = AXL.config.get().starterCars;
            return Array.isArray(c) ? c : [];
        }

        function valido() {
            var carros = listaCarros();
            return form.name.trim().length >= 2
                && form.surname.trim().length >= 2
                && form.age >= idadeMin() && form.age <= idadeMax()
                && (carros.length === 0 || !!form.vehicle);
        }

        function revalidar() {
            if (btnSalvar) btnSalvar.disabled = (!valido() || salvando);
        }

        function campo(rotulo, chave, opts) {
            opts = opts || {};
            var bloco = AXL.ui.el('div', 'controle');
            bloco.appendChild(AXL.ui.el('label', 'rotulo-campo', rotulo));

            var inp = document.createElement('input');
            inp.className = 'campo';
            inp.type = opts.tipo || 'text';
            if (opts.max) inp.maxLength = opts.max;
            if (opts.tipo === 'number') {
                inp.min = idadeMin();
                inp.max = idadeMax();
            }
            inp.value = form[chave];

            var erro = AXL.ui.el('span', 'erro-campo');
            erro.style.display = 'none';

            inp.addEventListener('input', function () {
                form[chave] = (opts.tipo === 'number')
                    ? (parseInt(inp.value, 10) || 0)
                    : inp.value;

                var ruim = opts.checar ? !opts.checar(form[chave]) : false;
                inp.classList.toggle('invalido', ruim && inp.value !== '');
                erro.style.display = (ruim && inp.value !== '') ? '' : 'none';
                if (ruim) erro.textContent = opts.mensagem || '';
                revalidar();
            });

            bloco.appendChild(inp);
            bloco.appendChild(erro);
            return bloco;
        }

        function cardsDeVeiculo() {
            var carros = listaCarros();
            var bloco = AXL.ui.el('div', 'grupo');
            bloco.appendChild(AXL.ui.el('span', 'grupo-titulo',
                AXL.config.t('confirm.vehicle.label', 'Veículo inicial')));

            if (!carros.length) {
                bloco.appendChild(AXL.ui.el('p', 'texto-fraco',
                    AXL.config.t('confirm.vehicle.empty', 'Nenhum veículo disponível.')));
                bloco.appendChild(AXL.ui.el('p', 'texto-fraco',
                    AXL.config.t('confirm.vehicle.emptyHint', '')));
                return bloco;
            }

            var grade = AXL.ui.el('div', 'carros');
            carros.forEach(function (c, i) {
                var card = AXL.ui.el('button', 'cartao carro');
                card.type = 'button';

                // Sem imagem, ou se ela falhar, mostra o ícone genérico.
                var generico = AXL.ui.el('div', 'carro-generico');
                generico.innerHTML = AXL.icons.get('carro', '2.4rem', 1.4);

                if (c.image) {
                    var img = document.createElement('img');
                    img.src = c.image;
                    img.alt = c.name || '';
                    generico.style.display = 'none';
                    img.addEventListener('error', function () {
                        img.style.display = 'none';
                        generico.style.display = '';
                    });
                    card.appendChild(img);
                }
                card.appendChild(generico);
                card.appendChild(AXL.ui.el('span', 'carro-nome', c.name || c.id));
                if (c.tagline) card.appendChild(AXL.ui.el('span', 'carro-tipo', c.tagline));

                card.addEventListener('mousedown', function (e) { e.preventDefault(); });
                card.addEventListener('click', function () {
                    form.vehicle = c.id;
                    var todos = grade.querySelectorAll('.carro');
                    for (var j = 0; j < todos.length; j++) todos[j].classList.remove('escolhido');
                    card.classList.add('escolhido');
                    revalidar();
                });

                if (i === 0) { card.classList.add('escolhido'); form.vehicle = c.id; }
                grade.appendChild(card);
            });

            bloco.appendChild(grade);
            return bloco;
        }

        function salvar() {
            if (!valido() || salvando) return;
            salvando = true;
            revalidar();
            if (btnSalvar) {
                var s = btnSalvar.querySelector('span');
                if (s) s.textContent = AXL.config.t('common.saving', 'Finalizando...');
            }

            var dados = {
                name: form.name.trim(),
                surname: form.surname.trim(),
                age: form.age,
                vehicle: form.vehicle
            };

            AXL.nui.send('cDoneSave', dados).then(function () {
                var cfg = AXL.config.get();

                // No modo reset quem fecha tudo é o jogo.
                if (cfg.mode === 'reset') return;

                // Guarda o nome pro título da whitelist.
                AXL.app.S.personagem = dados;

                if (cfg.skipWL === true) {
                    // Já aprovado antes: vai direto pro spawn.
                    AXL.nui.send('wlApprovedSpawn');
                } else {
                    AXL.app.irPara('whitelist');
                }
            });
        }

        return {
            montar: function () {
                form = { name: '', surname: '', age: idadeMin(), vehicle: '' };
                salvando = false;

                var etapa = document.querySelector('[data-etapa="confirm"]');
                if (etapa) etapa.textContent = AXL.config.etapa('confirm');
                var tit = document.getElementById('confirm-titulo');
                var sub = document.getElementById('confirm-sub');
                if (tit) tit.textContent = AXL.config.t('confirm.title', '');
                if (sub) sub.textContent = AXL.config.t('confirm.subtitle', '');

                var corpo = document.getElementById('confirm-corpo');
                if (corpo) {
                    corpo.innerHTML = '';
                    var ident = AXL.ui.el('div', 'grupo');
                    ident.appendChild(AXL.ui.el('span', 'grupo-titulo',
                        AXL.config.t('confirm.identity.label', 'Identidade')));

                    ident.appendChild(campo(
                        AXL.config.t('confirm.identity.firstName', 'Primeiro nome'), 'name',
                        { max: 20, checar: function (v) { return v.trim().length >= 2; },
                          mensagem: 'Use pelo menos 2 letras.' }));

                    ident.appendChild(campo(
                        AXL.config.t('confirm.identity.lastName', 'Sobrenome'), 'surname',
                        { max: 20, checar: function (v) { return v.trim().length >= 2; },
                          mensagem: 'Use pelo menos 2 letras.' }));

                    ident.appendChild(campo(
                        AXL.config.t('confirm.identity.age', 'Idade'), 'age',
                        { tipo: 'number',
                          checar: function (v) { return v >= idadeMin() && v <= idadeMax(); },
                          mensagem: AXL.config.fmt(
                              AXL.config.t('confirm.identity.ageError', ''), idadeMin()) }));

                    corpo.appendChild(ident);
                    if (!ehReset()) corpo.appendChild(cardsDeVeiculo());
                }

                var rodape = document.getElementById('confirm-rodape');
                if (rodape) {
                    rodape.innerHTML = '';
                    rodape.appendChild(AXL.ui.botao({
                        classe: 'btn-secundario', icone: 'setaEsq',
                        texto: AXL.config.t('common.back', 'Voltar'),
                        onClick: function () { AXL.nui.send('backToHead'); }
                    }));
                    btnSalvar = AXL.ui.botao({
                        classe: 'btn-primario btn-largo',
                        texto: AXL.config.t('common.save', 'Finalizar'),
                        onClick: salvar
                    });
                    rodape.appendChild(btnSalvar);
                }
                revalidar();
            },
            desmontar: function () { btnSalvar = null; }
        };
    }

    /* =================================================================
       WHITELIST
       ================================================================= */
    var whitelist = (function () {
        var estado = 'idle';
        var fecharModal = null;
        var tempoLimite = null;
        var geracao = 0;          // invalida resposta que chega atrasada

        function desenhar() {
            var corpo  = document.getElementById('wl-corpo');
            var rodape = document.getElementById('wl-rodape');
            var tit    = document.getElementById('wl-titulo');
            var etapa  = document.querySelector('[data-etapa="whitelist"]');
            if (!corpo || !rodape) return;

            if (etapa) etapa.textContent = AXL.config.etapa('whitelist');

            var p = AXL.app.S.personagem;
            var titulo;
            if (estado === 'checking')   titulo = AXL.config.t('whitelist.checkingTitle');
            else if (estado === 'ok')    titulo = AXL.config.t('whitelist.okTitle');
            else if (estado === 'fail')  titulo = AXL.config.t('whitelist.failTitle');
            else titulo = p && p.name
                ? AXL.config.fmt(AXL.config.t('whitelist.idleTitleGreet'), p.name)
                : AXL.config.t('whitelist.idleTitle');

            if (tit) tit.textContent = titulo;

            var desc = estado === 'checking' ? 'checkingDesc'
                     : estado === 'ok'       ? 'okDesc'
                     : estado === 'fail'     ? 'failDesc'
                     : 'idleDesc';

            corpo.innerHTML = '';
            var d = AXL.ui.el('p', 'texto-fraco', AXL.config.t('whitelist.' + desc));
            corpo.appendChild(d);

            rodape.innerHTML = '';
            if (estado === 'idle' || estado === 'fail') {
                // Sem link configurado o botão abre o aviso de "falta configurar".
                var url = (AXL.config.get().branding || {}).discordUrl || '';
                rodape.appendChild(AXL.ui.botao({
                    classe: 'btn-secundario',
                    texto: AXL.config.t('whitelist.btnDiscord', 'Abrir Discord'),
                    onClick: function () { abrirModalDiscord(url); }
                }));
                rodape.appendChild(AXL.ui.botao({
                    classe: 'btn-primario btn-largo',
                    icone: 'escudo',
                    texto: AXL.config.t(estado === 'fail'
                        ? 'whitelist.btnVerifyAgain' : 'whitelist.btnVerify'),
                    onClick: verificar
                }));
            }
        }

        /* Mostra o link pra copiar: o jogo não abre link externo. */
        function abrirModalDiscord(url) {
            var fundo = AXL.ui.el('div', 'modal-fundo');
            var caixa = AXL.ui.el('div', 'modal');
            var temLink = !!url && url.indexOf('http') === 0;

            caixa.appendChild(AXL.ui.el('span', 'rotulo-secao',
                AXL.config.t('discord.sectionLabel', 'Entrar no Discord')));
            caixa.appendChild(AXL.ui.el('h3', 'painel-titulo',
                temLink ? AXL.config.t('discord.title', 'Copie o link abaixo')
                        : AXL.config.t('discord.placeholderTitle', 'Link não configurado')));
            caixa.appendChild(AXL.ui.el('p', 'texto-fraco',
                temLink ? AXL.config.t('discord.description', '')
                        : AXL.config.t('discord.placeholderDesc', '')));

            var acoes = AXL.ui.el('div', 'modal-acoes');

            if (temLink) {
                var campo = document.createElement('input');
                campo.className = 'campo';
                campo.readOnly = true;
                campo.value = url;
                campo.addEventListener('focus', function () { campo.select(); });
                caixa.appendChild(campo);

                caixa.appendChild(AXL.ui.el('p', 'texto-fraco',
                    AXL.config.t('discord.hintInstruction', '')));

                var btnCopiar = AXL.ui.botao({
                    classe: 'btn-primario btn-largo',
                    texto: AXL.config.t('discord.btnCopy', 'Copiar link'),
                    onClick: function () {
                        campo.select();
                        try { document.execCommand('copy'); } catch (e) {}
                        var s = btnCopiar.querySelector('span');
                        if (s) s.textContent = AXL.config.t('discord.btnCopied', 'Copiado!');
                    }
                });
                acoes.appendChild(btnCopiar);
            } else {
                var dica = AXL.ui.el('p', 'texto-fraco',
                    'axl_creator/config.lua → Config.branding.discordUrl');
                dica.style.marginTop = '.6rem';
                caixa.appendChild(dica);
            }

            acoes.appendChild(AXL.ui.botao({
                classe: temLink ? 'btn-secundario' : 'btn-primario btn-largo',
                texto: AXL.config.t('common.close', 'Fechar'),
                onClick: fechar
            }));
            caixa.appendChild(acoes);

            function fechar() {
                if (fundo.parentNode) fundo.parentNode.removeChild(fundo);
                document.removeEventListener('keyup', aoTeclar);
                fecharModal = null;
            }
            function aoTeclar(ev) { if (ev.key === 'Escape') fechar(); }

            fundo.addEventListener('click', function (ev) {
                if (ev.target === fundo) fechar();
            });
            document.addEventListener('keyup', aoTeclar);

            fundo.appendChild(caixa);
            document.getElementById('app').appendChild(fundo);

            // Guarda o fechar: o modal mora no #app e não sai sozinho ao trocar de tela.
            fecharModal = fechar;

            // Só existe campo quando há link configurado.
            if (campo) campo.focus();
        }

        function verificar() {
            if (document.activeElement && document.activeElement.blur) {
                document.activeElement.blur();
            }
            estado = 'checking';
            desenhar();

            var meu = ++geracao;

            // Se o jogo não responder em 15s, cai em falha e o botão volta.
            clearTimeout(tempoLimite);
            tempoLimite = setTimeout(function () {
                if (meu !== geracao) return;
                estado = 'fail';
                desenhar();
            }, 15000);

            AXL.nui.send('verify').then(function (resp) {
                if (meu !== geracao) return;   // resposta de uma tentativa velha
                clearTimeout(tempoLimite);
                if (resp && resp.whitelisted) {
                    estado = 'ok';
                    desenhar();
                    AXL.nui.send('wlApprovedSpawn');
                } else {
                    estado = 'fail';
                    desenhar();
                }
            });
        }

        /* Fundo da whitelist: imagem, vídeo ou cenário do jogo, conforme o config. */
        function montarFundo() {
            var el = document.getElementById('wl-fundo');
            if (!el) return;
            el.innerHTML = '';
            el.className = 'wl-fundo';

            var cfg = AXL.config.get().whitelistFundo || {};
            var modo = cfg.fundo || 'nenhum';

            if (modo === 'imagem' && cfg.imagem) {
                el.style.backgroundImage = 'url("' + cfg.imagem + '")';
                el.classList.add('com-midia');
            } else if (modo === 'video' && cfg.video) {
                var v = document.createElement('video');
                v.src = cfg.video;
                v.autoplay = true;
                v.loop = true;
                v.muted = true;       // sem isto o navegador barra o autoplay
                v.playsInline = true;
                el.appendChild(v);
                el.classList.add('com-midia');
            } else {
                el.style.backgroundImage = '';
                if (modo === 'cenario') {
                    // A câmera de cenário é montada pelo jogo.
                    AXL.nui.send('cenarioWhitelist');
                }
            }
        }

        return {
            montar: function () { estado = 'idle'; montarFundo(); desenhar(); },
            desmontar: function () {
                if (fecharModal) fecharModal();
                // Invalida a verificação em voo pra não spawnar depois de sair.
                geracao++;
                clearTimeout(tempoLimite);

                AXL.nui.send('fecharCenarioWhitelist');
                var el = document.getElementById('wl-fundo');
                if (el) el.innerHTML = '';
            }
        };
    })();

    /* ----------------------------------------------------------------- */
    function registrar(add) {
        add('transition', transicao);
        add('face',    telaFace());
        add('head',    telaHead());
        add('confirm', telaConfirm());
        add('whitelist', whitelist);
        add('hidden', { montar: function () {}, desmontar: function () {} });
    }

    return { registrar: registrar };
})();
