/* =====================================================================
   AXL Creator — ícones
   =====================================================================
   SVG escrito à mão, sem biblioteca. Use assim:

       elemento.innerHTML = AXL.icons.get('check');

   Pra adicionar um ícone novo, basta pôr o conteúdo interno do <svg>
   (os path/circle) no mapa abaixo — o invólucro é montado aqui.
   ===================================================================== */

window.AXL = window.AXL || {};

AXL.icons = (function () {

    var TRACOS = {
        check:      '<path d="M20 6 9 17l-5-5"/>',
        setaEsq:    '<path d="m15 18-6-6 6-6"/>',
        setaDir:    '<path d="m9 18 6-6-6-6"/>',
        dado:       '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8.5" cy="8.5" r="1.1"/><circle cx="15.5" cy="15.5" r="1.1"/><circle cx="15.5" cy="8.5" r="1.1"/><circle cx="8.5" cy="15.5" r="1.1"/>',
        escudo:     '<path d="M12 3 5 6v5c0 4.4 2.9 8.5 7 10 4.1-1.5 7-5.6 7-10V6z"/>',
        carro:      '<path d="M5 13h14l-1.5-4.5A2 2 0 0 0 15.6 7H8.4a2 2 0 0 0-1.9 1.5z"/><path d="M4 13h16v4H4z"/><circle cx="7.5" cy="17.5" r="1.5"/><circle cx="16.5" cy="17.5" r="1.5"/>'
    };

    /**
     * Devolve o SVG pronto. `tam` aceita qualquer unidade CSS.
     * A espessura do traço vem separada porque os ícones grandes ficam
     * pesados demais com a espessura padrão.
     */
    function get(nome, tam, espessura) {
        var d = TRACOS[nome];
        if (!d) return '';
        return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
               'stroke-width="' + (espessura || 1.8) + '" ' +
               'stroke-linecap="round" stroke-linejoin="round"' +
               (tam ? ' style="width:' + tam + ';height:' + tam + '"' : '') +
               '>' + d + '</svg>';
    }

    return { get: get, TRACOS: TRACOS };
})();
