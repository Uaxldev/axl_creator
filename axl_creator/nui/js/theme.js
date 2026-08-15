/* =====================================================================
   AXL Creator — aplica o Config.theme do config.lua nas CSS vars
   =====================================================================
   As cores em hex do Lua viram triplet "r g b" nas vars de CSS.
   Separado por espaço: com vírgula o CSS descarta a regra inteira.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.theme = (function () {

    /** Aceita '#71368a', '#718', 'rgb(113,54,138)' ou '113 54 138' e devolve [r,g,b]. */
    function paraRgb(cor) {
        if (!cor) return null;
        var s = String(cor).trim();

        var m = s.match(/^#?([0-9a-f]{3})$/i);
        if (m) {
            var c = m[1];
            return [
                parseInt(c[0] + c[0], 16),
                parseInt(c[1] + c[1], 16),
                parseInt(c[2] + c[2], 16)
            ];
        }

        m = s.match(/^#?([0-9a-f]{6})$/i);
        if (m) {
            return [
                parseInt(m[1].slice(0, 2), 16),
                parseInt(m[1].slice(2, 4), 16),
                parseInt(m[1].slice(4, 6), 16)
            ];
        }

        var nums = s.match(/\d+/g);
        if (nums && nums.length >= 3) {
            return [ +nums[0], +nums[1], +nums[2] ];
        }
        return null;
    }

    /** Vira a string que o CSS espera: "113 54 138". */
    function triplet(cor) {
        var rgb = paraRgb(cor);
        return rgb ? rgb.join(' ') : null;
    }

    /** Clareia (fator > 0) ou escurece (fator < 0) uma cor. */
    function tom(cor, fator) {
        var rgb = paraRgb(cor);
        if (!rgb) return null;
        return rgb.map(function (v) {
            var novo = fator >= 0
                ? v + (255 - v) * fator
                : v * (1 + fator);
            return Math.max(0, Math.min(255, Math.round(novo)));
        }).join(' ');
    }

    // Cada chave do Config.theme e a var de CSS que ela alimenta.
    var MAPA = {
        accent:      '--c-accent',
        accentLight: '--c-accent-light',
        bgDeep:      '--c-bg-deep',
        bgCard:      '--c-bg-card',
        bgElev:      '--c-bg-elev',
        textHi:      '--c-text-hi',
        textMid:     '--c-text-mid',
        textLo:      '--c-text-lo',
        border:      '--c-border',
        ok:          '--c-ok',
        warn:        '--c-warn',
        danger:      '--c-danger'
    };

    /** Escreve o tema recebido do Lua nas vars do documento. */
    function aplicar(tema) {
        if (!tema || typeof tema !== 'object') return;
        var raiz = document.documentElement;

        // `dark` e `gray` são atalhos: um valor só define a família toda.
        if (tema.dark) {
            var fundo = triplet(tema.dark);
            if (fundo) {
                raiz.style.setProperty('--c-bg-deep', fundo);
                raiz.style.setProperty('--c-bg-card', tom(tema.dark, .05));
                raiz.style.setProperty('--c-bg-elev', tom(tema.dark, .11));
            }
        }
        if (tema.gray) {
            var cinza = triplet(tema.gray);
            if (cinza) {
                raiz.style.setProperty('--c-text-hi',  tom(tema.gray, .70));
                raiz.style.setProperty('--c-text-mid', cinza);
                raiz.style.setProperty('--c-text-lo',  tom(tema.gray, -.40));
            }
        }

        for (var chave in MAPA) {
            if (!tema[chave]) continue;
            var t = triplet(tema[chave]);
            if (t) raiz.style.setProperty(MAPA[chave], t);
        }

        // Sem accentLight no config, deriva do accent.
        if (tema.accent && !tema.accentLight) {
            var claro = tom(tema.accent, .25);
            if (claro) raiz.style.setProperty('--c-accent-light', claro);
        }

        // Cantos arredondados, se o config definir.
        if (tema.radius)   raiz.style.setProperty('--raio', tema.radius);
        if (tema.radiusSm) raiz.style.setProperty('--raio-sm', tema.radiusSm);
        if (tema.radiusLg) raiz.style.setProperty('--raio-lg', tema.radiusLg);
    }

    return { aplicar: aplicar, paraRgb: paraRgb, triplet: triplet, tom: tom };
})();
