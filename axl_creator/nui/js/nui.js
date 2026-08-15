/* AXL Creator — ponte da NUI com o client.lua.
   Envia com AXL.nui.send() e recebe com AXL.nui.onMessage(). */

window.AXL = window.AXL || {};

AXL.nui = (function () {
    // Fora do jogo (navegador) os envios só caem no console.
    var NO_JOGO = typeof window.GetParentResourceName === 'function';
    var RES = NO_JOGO ? window.GetParentResourceName() : 'axl_creator';

    // Manda um callback pro client.lua e devolve a resposta.
    // Resposta que não for JSON volta como objeto vazio.
    function send(nome, dados) {
        if (!NO_JOGO) {
            console.log('[AXL nui] ->', nome, dados || {});
            return Promise.resolve({});
        }
        return fetch('https://' + RES + '/' + nome, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(dados || {})
        })
        .then(function (r) { return r.text(); })
        .then(function (txt) {
            try { return JSON.parse(txt); } catch (e) { return {}; }
        })
        .catch(function () { return {}; });
    }

    var ouvintes = [];

    // Registra um ouvinte das mensagens vindas do jogo.
    function onMessage(fn) {
        if (typeof fn === 'function') ouvintes.push(fn);
    }

    window.addEventListener('message', function (ev) {
        var d = ev.data;
        if (!d || typeof d !== 'object') return;
        for (var i = 0; i < ouvintes.length; i++) {
            try { ouvintes[i](d); }
            catch (e) { console.error('[AXL nui] erro tratando mensagem', d, e); }
        }
    });

    return { send: send, onMessage: onMessage, noJogo: NO_JOGO, resource: RES };
})();

/* Simula no navegador as mensagens que o client.lua mandaria.
   Só pra teste de layout; nada aqui roda sozinho. */
AXL.debug = {
    send: function (msg) { window.postMessage(msg, '*'); },
    abrir: function () {
        this.send({ action: 'unlock' });
        this.send({ screen: 'face', userId: 1 });
    }
};
