/* =====================================================================
   AXL Creator — peças de interface
   =====================================================================
   Cada fábrica devolve { el, set(valor, silencioso), destroy() }.
   set() só atualiza a interface: nunca dispara o onChange.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.ui = (function () {

    /** Atalho pra criar elemento com classe e conteúdo. */
    function el(tag, classe, texto) {
        var e = document.createElement(tag);
        if (classe) e.className = classe;
        if (texto !== undefined && texto !== null) e.textContent = texto;
        return e;
    }

    /** Botão da interface. Aceita { classe, icone, texto, onClick }. */
    function botao(opts) {
        var b = document.createElement('button');
        b.type = 'button';
        b.className = 'btn ' + (opts.classe || 'btn-secundario');
        if (opts.icone) b.innerHTML = AXL.icons.get(opts.icone, '.95rem');
        if (opts.texto) {
            var s = el('span', null, opts.texto);
            b.appendChild(s);
        }
        b.addEventListener('mousedown', function (e) { e.preventDefault(); });
        if (opts.onClick) b.addEventListener('click', opts.onClick);
        return b;
    }

    /**
     * Abas. Devolve { el, selecionar(id) }.
     * Com `hostExistente`, os botões entram nele em vez de num <nav> novo.
     */
    function abas(itens, aoTrocar, hostExistente) {
        var host = hostExistente || el('nav', 'abas');
        var botoes = {};

        function selecionar(id) {
            for (var k in botoes) {
                botoes[k].classList.toggle('ativa', k === id);
            }
            if (aoTrocar) aoTrocar(id);
        }

        itens.forEach(function (it) {
            var b = document.createElement('button');
            b.type = 'button';
            b.className = 'aba';
            b.textContent = it.rotulo;
            b.addEventListener('mousedown', function (e) { e.preventDefault(); });
            b.addEventListener('click', function () { selecionar(it.id); });
            botoes[it.id] = b;
            host.appendChild(b);
        });

        if (itens.length) selecionar(itens[0].id);
        return { el: host, selecionar: selecionar };
    }

    /* -----------------------------------------------------------------
       Dial — barra deslizante pros traços do rosto
       -----------------------------------------------------------------
       Clique pula pro ponto, arrastar ajusta, roda faz micro-ajuste e
       duplo-clique volta pro meio.
       ----------------------------------------------------------------- */
    function dial(opts) {
        var min  = (opts.min !== undefined) ? opts.min : -1;
        var max  = (opts.max !== undefined) ? opts.max :  1;
        var step = opts.step || 0.01;
        var faixa = max - min;
        var cruzaZero = (min < 0 && max > 0);
        var valor = 0, arrastando = false, silencioso = false;

        var raiz = el('div', 'controle');
        var topo = el('div', 'controle-topo');
        topo.appendChild(el('span', 'controle-rotulo', opts.label || ''));
        var num = el('span', 'controle-valor');
        topo.appendChild(num);

        var trilho = el('div', 'dial-trilho');
        var preenchido = el('span', 'dial-preenchido');
        var pino = el('span', 'dial-pino');
        trilho.appendChild(preenchido);
        if (cruzaZero) trilho.appendChild(el('span', 'dial-meio'));
        trilho.appendChild(pino);

        raiz.appendChild(topo);
        raiz.appendChild(trilho);

        /** Prende nos limites e gruda nos pontos redondos. */
        function ajustar(v) {
            var c = Math.max(min, Math.min(max, v));
            var tol = Math.abs(step) / 2;
            if (c >= max - tol) return max;                  // gruda no fim
            if (c <= min + tol) return min;                  // gruda no começo
            if (cruzaZero && Math.abs(c) < tol) return 0;    // e no zero
            var passos = Math.round(c / step) * step;
            return Math.max(min, Math.min(max, passos));
        }

        function desenhar() {
            var p = ((valor - min) / faixa) * 100;
            pino.style.left = p + '%';
            if (cruzaZero) {
                var zero = ((0 - min) / faixa) * 100;
                preenchido.style.left  = Math.min(p, zero) + '%';
                preenchido.style.width = Math.abs(p - zero) + '%';
            } else {
                preenchido.style.left  = '0%';
                preenchido.style.width = p + '%';
            }
            num.textContent = (step < 1)
                ? valor.toFixed(2).replace('-0.00', '0.00')
                : String(Math.round(valor));
        }

        function definir(v, semAvisar) {
            var novo = ajustar(Number(v) || 0);
            var mudou = (novo !== valor);
            valor = novo;
            desenhar();
            if (mudou && !semAvisar && !silencioso && opts.onChange) opts.onChange(valor);
        }

        function pelaPosicao(clientX) {
            var r = trilho.getBoundingClientRect();
            var razao = Math.max(0, Math.min(1, (clientX - r.left) / r.width));
            definir(min + razao * faixa);
        }

        function aoMover(ev) { if (arrastando) pelaPosicao(ev.clientX); }
        function aoSoltar()  { arrastando = false; trilho.classList.remove('arrastando'); }

        trilho.addEventListener('mousedown', function (ev) {
            ev.preventDefault();
            arrastando = true;
            trilho.classList.add('arrastando');
            pelaPosicao(ev.clientX);
        });
        trilho.addEventListener('dblclick', function () {
            definir(cruzaZero ? 0 : (min + max) / 2);
        });
        // passive:false é obrigatório pra cancelar a rolagem da página.
        trilho.addEventListener('wheel', function (ev) {
            ev.preventDefault();
            definir(valor + (ev.deltaY < 0 ? 1 : -1) * step * 4);
        }, { passive: false });

        window.addEventListener('mousemove', aoMover);
        window.addEventListener('mouseup', aoSoltar);

        definir(opts.value !== undefined ? opts.value : 0, true);

        return {
            el: raiz,
            set: function (v, semAvisar) {
                silencioso = true;
                definir(v, semAvisar !== false);
                silencioso = false;
            },
            destroy: function () {
                window.removeEventListener('mousemove', aoMover);
                window.removeEventListener('mouseup', aoSoltar);
            }
        };
    }

    /* -----------------------------------------------------------------
       Stepper — escolher entre opções numeradas
       -----------------------------------------------------------------
       Mostra sempre valor+1. Com `permiteVazio`, o -1 vira "—" (nenhum).
       ----------------------------------------------------------------- */
    function stepper(opts) {
        var min = opts.min || 0;
        var max = (opts.max !== undefined) ? opts.max : 10;
        var permiteVazio = !!opts.permiteVazio;
        var minReal = permiteVazio ? -1 : min;
        var valor = 0, silencioso = false;

        var raiz = el('div', 'controle');
        var topo = el('div', 'controle-topo');
        topo.appendChild(el('span', 'controle-rotulo', opts.label || ''));
        var num = el('span', 'controle-valor');
        topo.appendChild(num);

        var linha = el('div', 'stepper');
        var bAnt = botao({ classe: 'btn-icone stepper-seta', icone: 'setaEsq',
                           onClick: function () { definir(valor - 1); } });
        var visor = el('div', 'stepper-visor');
        var bProx = botao({ classe: 'btn-icone stepper-seta', icone: 'setaDir',
                            onClick: function () { definir(valor + 1); } });
        linha.appendChild(bAnt); linha.appendChild(visor); linha.appendChild(bProx);

        var barra = el('div', 'stepper-barra');
        var barraCheia = el('span');
        barra.appendChild(barraCheia);

        raiz.appendChild(topo);
        raiz.appendChild(linha);
        raiz.appendChild(barra);

        function texto(v) {
            return (v === -1 && permiteVazio) ? '—' : String(v + 1);
        }

        function desenhar() {
            visor.textContent = texto(valor);
            var total = max - min + 1;
            var p = valor < 0 ? 0 : ((valor - min) / (total - 1)) * 100;
            barraCheia.style.width = p + '%';
            num.textContent = (valor < 0 ? '—' : (valor + 1) + ' / ' + total);
            bAnt.disabled  = (valor <= minReal);
            bProx.disabled = (valor >= max);
        }

        function definir(v, semAvisar) {
            var novo = Math.max(minReal, Math.min(max, Math.round(Number(v))));
            var mudou = (novo !== valor);
            valor = novo;
            desenhar();
            if (mudou && !semAvisar && !silencioso && opts.onChange) opts.onChange(valor);
        }

        definir(opts.value !== undefined ? opts.value : min, true);

        return {
            el: raiz,
            set: function (v, semAvisar) {
                silencioso = true;
                definir(v, semAvisar !== false);
                silencioso = false;
            },
            destroy: function () {}
        };
    }

    return {
        el: el, botao: botao, abas: abas,
        dial: dial, stepper: stepper
    };
})();
