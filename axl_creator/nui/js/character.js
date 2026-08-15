/* =====================================================================
   AXL Creator — personagem em construção
   =====================================================================
   Guarda os traços do personagem e avisa o jogo a cada mudança, em três
   grupos: pele/genética, rosto e cabeça.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.character = (function () {

    var PADRAO = {
        fathersID: 0, mothersID: 0, skinColor: 0, shapeMix: 0,
        eyesColor: 0, eyesOpening: 0,
        eyebrowsHeight: 0, eyebrowsWidth: 0,
        noseWidth: 0, noseHeight: 0, noseLength: 0, noseBridge: 0, noseTip: 0, noseShift: 0,
        cheekboneHeight: 0, cheekboneWidth: 0, cheeksWidth: 0,
        lips: 0, jawWidth: 0, jawHeight: 0,
        chinLength: 0, chinPosition: 0, chinWidth: 0, chinShape: 0,
        neckWidth: 0,
        hairModel: 4, firstHairColor: 0, secondHairColor: 0, hairHighlight: 1,
        eyebrowsModel: 0, eyebrowsColor: 0,
        beardModel: -1, beardColor: 0,
        chestModel: -1, chestColor: 0,
        blushModel: -1, blushColor: 0,
        lipstickModel: -1, lipstickColor: 0,
        blemishesModel: -1, ageingModel: -1, complexionModel: -1, sundamageModel: -1,
        frecklesModel: -1, makeupModel: -1,
        bodyBlemishes: -1, bodyBlemishesAdd: -1
    };

    var PELE = ['fathersID', 'mothersID', 'skinColor', 'shapeMix'];

    var ROSTO = [
        'eyesColor', 'eyesOpening',
        'eyebrowsHeight', 'eyebrowsWidth',
        'noseWidth', 'noseHeight', 'noseLength', 'noseBridge', 'noseTip', 'noseShift',
        'cheekboneHeight', 'cheekboneWidth', 'cheeksWidth',
        'lips', 'jawWidth', 'jawHeight',
        'chinLength', 'chinPosition', 'chinWidth', 'chinShape',
        'neckWidth'
    ];

    var CABECA = [
        'hairModel', 'firstHairColor', 'secondHairColor', 'hairHighlight',
        'eyebrowsModel', 'eyebrowsColor',
        'beardModel', 'beardColor',
        'chestModel', 'chestColor',
        'blushModel', 'blushColor',
        'lipstickModel', 'lipstickColor',
        'blemishesModel', 'ageingModel', 'complexionModel', 'sundamageModel',
        'frecklesModel', 'makeupModel',
        'bodyBlemishes', 'bodyBlemishesAdd'
    ];

    var atual = Object.assign({}, PADRAO);

    /** Separa só as chaves de um grupo, na ordem. */
    function recortar(chaves) {
        var out = {};
        for (var i = 0; i < chaves.length; i++) out[chaves[i]] = atual[chaves[i]];
        return out;
    }

    function get(chave) {
        return chave === undefined ? atual : atual[chave];
    }

    /* Mandam sempre o grupo inteiro: campo faltando chega nil no Lua e quebra a mistura. */
    function mudarPele(patch) {
        Object.assign(atual, patch);
        AXL.nui.send('UpdateSkinOptions', recortar(PELE));
    }

    function mudarRosto(patch) {
        Object.assign(atual, patch);
        AXL.nui.send('UpdateFaceOptions', recortar(ROSTO));
    }

    function mudarCabeca(patch) {
        Object.assign(atual, patch);
        AXL.nui.send('UpdateHeadOptions', recortar(CABECA));
    }

    /** Descobre a que grupo o traço pertence e usa o envio certo. */
    function mudar(chave, valor) {
        var patch = {};
        patch[chave] = valor;
        if (PELE.indexOf(chave)  !== -1) return mudarPele(patch);
        if (ROSTO.indexOf(chave) !== -1) return mudarRosto(patch);
        if (CABECA.indexOf(chave)!== -1) return mudarCabeca(patch);
        Object.assign(atual, patch);
    }

    /** Volta tudo ao padrão, só no lado da interface. */
    function resetar() {
        atual = Object.assign({}, PADRAO);
    }

    /** Aplica o que o jogo mandou sem devolver eco. */
    function aplicar(doJogo) {
        if (!doJogo || typeof doJogo !== 'object') return;
        for (var k in doJogo) {
            if (Object.prototype.hasOwnProperty.call(atual, k)) atual[k] = doJogo[k];
        }
    }

    return {
        PADRAO: PADRAO,
        PELE: PELE, ROSTO: ROSTO, CABECA: CABECA,
        get: get,
        mudar: mudar,
        mudarPele: mudarPele,
        mudarRosto: mudarRosto,
        mudarCabeca: mudarCabeca,
        resetar: resetar,
        aplicar: aplicar
    };
})();

/* Cada controle se registra aqui pela chave do traço que edita. */
AXL.controles = {};
