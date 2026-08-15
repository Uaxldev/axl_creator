/* =====================================================================
   AXL Creator — estado, roteador e entrada das mensagens do jogo
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.app = (function () {

    var S = {
        travada:     true,   // interface escondida (estado inicial)
        travadaSempre: false,// 'block' — só volta recarregando a interface
        tela:        'hidden',
        userId:      0,
        personagem:  null,   // { name, surname, age } — usado na whitelist
        sexo:        1
    };

    // Preenchido por screens.js. Cada tela expõe { montar, desmontar }.
    var TELAS = {};

    function registrarTela(nome, api) { TELAS[nome] = api; }

    function travar(permanente) {
        if (permanente) S.travadaSempre = true;
        S.travada = true;
        document.body.classList.add('bloqueada');
    }

    function destravar() {
        // Depois de um 'block' o jogo não volta atrás: ignora o unlock.
        if (S.travadaSempre) return;
        S.travada = false;
        document.body.classList.remove('bloqueada');
    }

    /* -----------------------------------------------------------------
       Troca de tela — desmontar() solta listeners, timers e rAF da tela antiga.
       ----------------------------------------------------------------- */
    function irPara(nova) {
        if (!nova || nova === S.tela) return;

        var antiga = TELAS[S.tela];
        if (antiga && antiga.desmontar) {
            try { antiga.desmontar(); }
            catch (e) { console.error('[AXL] erro ao sair de ' + S.tela, e); }
        }

        S.tela = nova;

        var todas = document.querySelectorAll('[data-tela]');
        for (var i = 0; i < todas.length; i++) {
            todas[i].hidden = (todas[i].getAttribute('data-tela') !== nova);
        }

        var atual = TELAS[nova];
        if (atual && atual.montar) {
            try { atual.montar(); }
            catch (e) { console.error('[AXL] erro ao abrir ' + nova, e); }
        }

        atualizarMoldura();
    }

    /** Sidebar e controles de câmera só fazem sentido durante a criação. */
    function atualizarMoldura() {
        var criando = (S.tela === 'face' || S.tela === 'head' || S.tela === 'confirm');
        document.body.classList.toggle('em-criacao', criando);

        // Moldura dos cantos: aparece em qualquer tela menos a 'hidden'.
        document.body.classList.toggle('creator-aberto', S.tela !== 'hidden');

        if (AXL.chrome && AXL.chrome.sincronizar) AXL.chrome.sincronizar();
    }

    /* -----------------------------------------------------------------
       Mensagens vindas do client.lua
       ----------------------------------------------------------------- */
    function tratar(d) {
        if (d.action === 'unlock')  { destravar(); return; }
        if (d.action === 'lock')    { travar(false); return; }
        if (d.action === 'block')   { travar(true);  return; }

        if (d.action === 'resetCharacter') {
            AXL.character.resetar();
            S.personagem = null;
            sincronizarControles();
            return;
        }

        if (d.action === 'syncCharacter') {
            // Não devolve nada pro Lua aqui: evita loop de sincronização.
            AXL.character.aplicar(d.character);
            sincronizarControles();
            return;
        }

        // Aviso: aparece mesmo com a interface travada.
        if (d.toast) {
            if (AXL.chrome && AXL.chrome.aviso) AXL.chrome.aviso(d.toast);
            return;
        }

        // Bags de configuração — podem vir juntas ou separadas.
        var patch = {};
        var CHAVES = ['branding','starterCars','limits','idade','texts',
                      'theme','creatorCamera','mode','skipWL','slot','characters',
                      'whitelistFundo'];
        var temConfig = false;
        for (var i = 0; i < CHAVES.length; i++) {
            var k = CHAVES[i];
            if (d[k] !== undefined) { patch[k] = d[k]; temConfig = true; }
        }
        if (temConfig) {
            AXL.config.aplicar(patch);
            if (patch.theme) AXL.theme.aplicar(patch.theme);
            if (AXL.chrome && AXL.chrome.reconstruir) AXL.chrome.reconstruir();
        }

        if (typeof d.userId === 'number') S.userId = d.userId;
        if (d.characterData) S.personagem = d.characterData;

        // Por último: a tela monta com config, tema e dados já aplicados.
        if (d.screen) irPara(d.screen);
    }

    function sincronizarControles() {
        var reg = AXL.controles || {};
        for (var k in reg) {
            if (!Object.prototype.hasOwnProperty.call(reg, k)) continue;
            var c = reg[k];
            if (c && typeof c.set === 'function') {
                c.set(AXL.character.get(k), true); // true = silencioso
            }
        }
    }

    function iniciar() {
        AXL.config.get();                 // garante os padrões
        AXL.theme.aplicar({});            // deixa as vars do CSS valendo
        travar(false);                    // nasce escondida: quem abre é o jogo
        AXL.nui.onMessage(tratar);

        if (AXL.chrome && AXL.chrome.iniciar) AXL.chrome.iniciar();
        if (AXL.screens && AXL.screens.registrar) AXL.screens.registrar(registrarTela);

        irPara('hidden');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }

    return {
        S: S,
        irPara: irPara,
        registrarTela: registrarTela,
        sincronizarControles: sincronizarControles,
        travar: travar,
        destravar: destravar
    };
})();
