/* =====================================================================
   AXL Creator — o que fica em volta das telas
   =====================================================================
   Coluna da esquerda (progresso e ficha), câmera no mouse e os avisos.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.chrome = (function () {

    var elLateral, elMarca, elEtapas, elFicha, elAleatorio, elAvisos;

    /* -----------------------------------------------------------------
       Progresso das etapas
       -----------------------------------------------------------------
       4 etapas no fluxo normal, 3 quando a whitelist não entra.
       ----------------------------------------------------------------- */
    function ordemDasEtapas() {
        var c = AXL.config.get();
        var semWl = c.mode === 'reset' || c.skipWL === true;
        var base = [
            { id: 'face',    rotulo: AXL.config.t('face.title', 'Aparência') },
            { id: 'head',    rotulo: AXL.config.t('head.title', 'Cabelo') },
            { id: 'confirm', rotulo: AXL.config.t('confirm.title', 'Identidade') }
        ];
        if (!semWl) {
            base.push({ id: 'whitelist', rotulo: AXL.config.t('whitelist.titleAccent', 'Whitelist') });
        }
        return base;
    }

    function desenharEtapas() {
        if (!elEtapas) return;
        var ordem = ordemDasEtapas();
        var atual = AXL.app.S.tela;
        var iAtual = -1;
        for (var i = 0; i < ordem.length; i++) {
            if (ordem[i].id === atual) { iAtual = i; break; }
        }

        elEtapas.innerHTML = '';
        for (var j = 0; j < ordem.length; j++) {
            var li = document.createElement('li');
            li.className = 'etapa';
            if (iAtual > -1 && j <  iAtual) li.classList.add('feita');
            if (iAtual > -1 && j === iAtual) li.classList.add('atual');

            var bola = document.createElement('span');
            bola.className = 'etapa-bola';
            bola.innerHTML = (iAtual > -1 && j < iAtual)
                ? AXL.icons.get('check', '.7rem', 3)
                : String(j + 1);

            var txt = document.createElement('span');
            txt.textContent = ordem[j].rotulo;

            li.appendChild(bola);
            li.appendChild(txt);
            elEtapas.appendChild(li);
        }
    }

    /* -----------------------------------------------------------------
       Ficha
       ----------------------------------------------------------------- */
    function desenharFicha() {
        if (!elFicha) return;
        var S = AXL.app.S;
        var p = S.personagem;

        var linhas = [];
        linhas.push(['Passaporte', '#' + String(S.userId || 0).padStart(3, '0')]);
        if (p && p.name) {
            linhas.push(['Nome', p.name + (p.surname ? ' ' + p.surname : '')]);
        }
        if (p && p.age) {
            linhas.push(['Idade', p.age + ' ' + AXL.config.t('whitelist.ageSuffix', 'anos')]);
        }

        var dl = document.createElement('dl');
        dl.style.margin = '0';
        for (var i = 0; i < linhas.length; i++) {
            var div = document.createElement('div');
            div.className = 'ficha-linha';
            var dt = document.createElement('dt'); dt.textContent = linhas[i][0];
            var dd = document.createElement('dd'); dd.textContent = linhas[i][1];
            div.appendChild(dt); div.appendChild(dd);
            dl.appendChild(div);
        }
        elFicha.innerHTML = '';
        elFicha.appendChild(dl);
    }

    function desenharMarca() {
        if (!elMarca) return;
        var b = AXL.config.get().branding || {};
        elMarca.innerHTML = '';
        var nome = document.createTextNode(b.cityName || '');
        elMarca.appendChild(nome);
        if (b.tagline) {
            var s = document.createElement('small');
            s.textContent = b.tagline;
            elMarca.appendChild(s);
        }
    }

    /* -----------------------------------------------------------------
       Câmera
       -----------------------------------------------------------------
       Arrastar com o botão esquerdo gira o personagem, a roda aproxima.
       O client espera o ângulo final: o giro sai daqui com +180.
       ----------------------------------------------------------------- */
    var cam = {
        angulo: 0,
        arrastando: false,
        orbitando: false,
        ultimoX: 0,
        ultimoY: 0,
        pendente: false,
        zoomAcumulado: 0,
        zoomPendente: false,
        orbX: 0,
        orbY: 0,
        orbPendente: false
    };

    function enviarGiro() {
        cam.pendente = false;
        AXL.nui.send('cChangeHeading', { camRotation: cam.angulo + 180 });
    }

    function girar(graus) {
        var a = graus % 360;
        if (a < 0) a += 360;
        cam.angulo = a;
        // Junta o movimento e manda uma vez por quadro.
        if (!cam.pendente) {
            cam.pendente = true;
            requestAnimationFrame(enviarGiro);
        }
    }

    function enviarZoom() {
        cam.zoomPendente = false;
        if (!cam.zoomAcumulado) return;
        AXL.nui.send('camZoom', { delta: cam.zoomAcumulado });
        cam.zoomAcumulado = 0;
    }

    function enviarOrbita() {
        cam.orbPendente = false;
        if (!cam.orbX && !cam.orbY) return;
        AXL.nui.send('camLivre', { dx: cam.orbX, dy: cam.orbY });
        cam.orbX = 0;
        cam.orbY = 0;
    }

    function ligarPalco() {
        var palco = document.getElementById('palco');
        if (!palco) return;

        palco.addEventListener('mousedown', function (ev) {
            if (ev.button === 0) {
                cam.arrastando = true;
            } else if (ev.button === 2) {
                cam.orbitando = true;
                palco.classList.add('orbitando');
            } else {
                return;
            }
            cam.ultimoX = ev.clientX;
            cam.ultimoY = ev.clientY;
            if (cam.arrastando) palco.classList.add('arrastando');
        });

        // Sem isto o menu do navegador abre e engole o arrasto.
        palco.addEventListener('contextmenu', function (ev) { ev.preventDefault(); });

        // Só o sinal da roda conta, o passo do zoom é fixo.
        palco.addEventListener('wheel', function (ev) {
            cam.zoomAcumulado += (ev.deltaY > 0 ? 0.3 : -0.3);
            if (!cam.zoomPendente) {
                cam.zoomPendente = true;
                requestAnimationFrame(enviarZoom);
            }
        }, { passive: true });
    }

    /* Ouvinte na janela inteira pro giro não travar fora do palco. */
    function aoMover(ev) {
        if (cam.arrastando) {
            var sensibilidade = 0.4;      // graus por pixel arrastado
            girar(cam.angulo + (ev.clientX - cam.ultimoX) * sensibilidade);
        } else if (cam.orbitando) {
            cam.orbX += ev.clientX - cam.ultimoX;
            cam.orbY += ev.clientY - cam.ultimoY;
            if (!cam.orbPendente) {
                cam.orbPendente = true;
                requestAnimationFrame(enviarOrbita);
            }
        } else {
            return;
        }
        cam.ultimoX = ev.clientX;
        cam.ultimoY = ev.clientY;
    }

    function aoSoltar() {
        if (!cam.arrastando && !cam.orbitando) return;
        if (cam.orbitando) enviarOrbita();
        cam.arrastando = false;
        cam.orbitando = false;
        var palco = document.getElementById('palco');
        if (palco) palco.classList.remove('arrastando', 'orbitando');
    }

    /* -----------------------------------------------------------------
       Avisos
       ----------------------------------------------------------------- */
    var ICONE_AVISO = {
        sucesso: 'check', negado: 'x', alerta: 'alerta',
        importante: 'info', info: 'info'
    };

    function aviso(dados) {
        if (!elAvisos || !dados || !dados.message) return;

        var tipo = dados.type || 'info';
        var el = document.createElement('div');
        el.className = 'aviso aviso-' + tipo;
        el.innerHTML = AXL.icons.get(ICONE_AVISO[tipo] || 'info');

        var txt = document.createElement('span');
        txt.innerHTML = String(dados.message);   // o Lua manda <b> nas mensagens
        el.appendChild(txt);

        elAvisos.appendChild(el);

        var tempo = Number(dados.duration) || 4000;
        setTimeout(function () {
            el.classList.add('saindo');
            setTimeout(function () {
                if (el.parentNode) el.parentNode.removeChild(el);
            }, 220);
        }, tempo);
    }

    /* -----------------------------------------------------------------
       Ciclo
       ----------------------------------------------------------------- */
    function iniciar() {
        elLateral   = document.getElementById('lateral');
        elMarca     = document.getElementById('lateral-marca');
        elEtapas    = document.getElementById('linha-etapas');
        elFicha     = document.getElementById('ficha');
        elAleatorio = document.getElementById('btn-aleatorio');
        elAvisos    = document.getElementById('avisos');

        if (elAleatorio) {
            elAleatorio.innerHTML = AXL.icons.get('dado', '.95rem') +
                '<span>' + AXL.config.t('common.randomize', 'Aleatorizar') + '</span>';
            elAleatorio.addEventListener('mousedown', function (e) { e.preventDefault(); });
            elAleatorio.addEventListener('click', function () {
                AXL.nui.send('randomizeChar');
            });
        }

        ligarPalco();
        window.addEventListener('mousemove', aoMover);
        window.addEventListener('mouseup', aoSoltar);

        reconstruir();
    }

    /** Chamado quando o config muda. */
    function reconstruir() {
        desenharMarca();
        desenharEtapas();
        desenharFicha();

        if (elAleatorio) {
            var lbl = elAleatorio.querySelector('span');
            if (lbl) lbl.textContent = AXL.config.t('common.randomize', 'Aleatorizar');
        }
    }

    /** Chamado a cada troca de tela. */
    function sincronizar() {
        var criando = document.body.classList.contains('em-criacao');
        if (elLateral) elLateral.hidden = !criando;
        desenharEtapas();
        desenharFicha();
    }

    return {
        iniciar: iniciar,
        reconstruir: reconstruir,
        sincronizar: sincronizar,
        aviso: aviso,
        girar: girar
    };
})();
