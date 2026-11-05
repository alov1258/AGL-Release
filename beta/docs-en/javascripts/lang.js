// lang.js  --  REVISION 2026-11-05 r4  (r4: a link in the page to another language's site (the home page's Languages line) saves that language as the choice, so the start-up check does not send the reader back; r3: the online site also shows the Translate banner when the hub's ?lang= language is not published; r2: ?lang=xx in the address (the hub opening the online site) picks that language for this tab when it is published, otherwise stays in English, and does not change the saved choice; r1: the first visit opens the published language that matches the browser's languages, a language chosen in the header selector is remembered, the selector gets a tick, an Automatic line and a note about the browser's Translate; the hub's local copy (served by utils.DocServer) shows how to translate when the hub's language is not published)
// One copy per site (docs-en/javascripts and docs-it/javascripts must be identical). The published languages and their addresses are read from the
// header selector itself (Zensical's extra.alternate), so adding a language to the toml needs no change here.
(function () {
	"use strict";
	var KEY = "agl-doc-lang";
	var BANNER_KEY = "agl-doc-banner";
	var TEXT = {
		en: { published: "Published translations", auto: "Automatic (browser language)", other: "Other languages: use your browser's Translate function to view this documentation in another language." },
		it: { published: "Traduzioni pubblicate", auto: "Automatico (lingua del browser)", other: "Altre lingue: usa la funzione Traduci del browser per leggere questa documentazione in un'altra lingua." }
	};
	// Shown only in the hub's local copy (the hub tells the page its language in window.aglHubLang) when that language has no published pages.
	var HUB = {
		en: "This page is in English. To read it in your language, use your browser's Translate option: the translate icon in the address bar, or right-click the page.",
		it: "Questa pagina è in inglese. Per leggerla nella tua lingua, usa la funzione Traduci del browser: l'icona di traduzione nella barra degli indirizzi, oppure clic destro sulla pagina.",
		es: "Esta página está en inglés. Para leerla en su idioma, use la opción Traducir del navegador: el icono de traducción en la barra de direcciones, o clic derecho en la página.",
		fr: "Cette page est en anglais. Pour la lire dans votre langue, utilisez la fonction Traduire du navigateur : l'icône de traduction dans la barre d'adresse, ou un clic droit sur la page.",
		nl: "Deze pagina is in het Engels. Om haar in uw taal te lezen, gebruikt u de functie Vertalen van de browser: het vertaalpictogram in de adresbalk, of klik met de rechtermuisknop op de pagina.",
		pt: "Esta página está em inglês. Para a ler no seu idioma, use a opção Traduzir do navegador: o ícone de tradução na barra de endereço, ou clique com o botão direito na página.",
		sv: "Den här sidan är på engelska. Om du vill läsa den på ditt språk använder du webbläsarens översättningsfunktion: översättningsikonen i adressfältet, eller högerklicka på sidan."
	};

	function base(code) { return String(code || "").toLowerCase().split(/[-_]/)[0]; }
	function store(fn) { try { return fn(); } catch (e) { return null; } }   // storage can be blocked
	function getPref() { return store(function () { return localStorage.getItem(KEY); }); }
	function setPref(v) { store(function () { localStorage.setItem(KEY, v); }); }
	function clearPref() { store(function () { localStorage.removeItem(KEY); }); }

	/** The published languages: [{lang, root, a}], read from the header selector. root is the path of the language's site, ending in "/". */
	function roots() {
		var out = [], links = document.querySelectorAll(".md-select__link[hreflang]");
		for (var i = 0; i < links.length; i++) {
			var p = new URL(links[i].getAttribute("href"), location.href).pathname;
			if (p.charAt(p.length - 1) !== "/") p += "/";
			out.push({ lang: base(links[i].getAttribute("hreflang")), root: p, a: links[i] });
		}
		return out;
	}
	/** The language site this page is in: the longest root that starts the page's path, or null (the hub's local copy is served at the root of its own server). */
	function here(rs) {
		var best = null;
		for (var i = 0; i < rs.length; i++)
			if (location.pathname.indexOf(rs[i].root) === 0 && (!best || rs[i].root.length > best.root.length)) best = rs[i];
		return best;
	}
	function find(rs, lang) {
		for (var i = 0; i < rs.length; i++) if (rs[i].lang === lang) return rs[i];
		return null;
	}
	/** The first of the browser's languages that is published; English (or the first published) when none is. */
	function detect(rs) {
		var prefs = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
		for (var i = 0; i < prefs.length; i++) {
			var b = base(prefs[i]);
			if (find(rs, b)) return b;
		}
		return find(rs, "en") ? "en" : rs[0].lang;
	}
	/** The hub's language for this tab (?lang=xx when it opened the page, kept for the tab's other pages), or null. Published: that language; not published: English. */
	var hubRaw = null;   // the hub's language as given, published or not
	function hubChoice(rs) {
		var m = /[?&]lang=([a-zA-Z]{2,3})/.exec(location.search), v = m ? base(m[1]) : null;
		if (v) store(function () { sessionStorage.setItem("agl-doc-hub-lang", v); }); else v = store(function () { return sessionStorage.getItem("agl-doc-hub-lang"); });
		hubRaw = v || null;
		if (!v) return null;
		return find(rs, v) ? v : "en";
	}
	/** The language to show: the hub's for this tab, else the saved choice, else the browser's. */
	function wanted(rs) {
		var hc = hubChoice(rs);
		if (hc) return hc;
		var p = getPref();
		return p && find(rs, p) ? p : detect(rs);
	}
	/** Opens the same page in that language, or its home page when that page is not there. */
	function go(rs, lang, replace) {
		var h = here(rs), r = find(rs, lang);
		if (!h || !r) return;
		var home = r.root;
		var q = location.search.replace(/^\?lang=[a-zA-Z]{2,3}&?/, "?").replace(/[?&]lang=[a-zA-Z]{2,3}/, "");   // the hub's ?lang= is kept for the tab (sessionStorage), not in the address
		if (q === "?") q = "";
		var page = home + location.pathname.substring(h.root.length) + q + location.hash;
		function open(u) { if (replace) location.replace(u); else location.assign(u); }
		if (typeof fetch !== "function") { open(page); return; }
		fetch(page.split("#")[0], { method: "HEAD", cache: "no-store" }).then(
			function (x) { open(x.ok ? page : home); },
			function () { open(page); });
	}

	function css() {
		if (document.getElementById("agl-lang-css")) return;
		var s = document.createElement("style");
		s.id = "agl-lang-css";
		s.textContent =
			".md-select__item.agl-head{padding:.4rem 1rem .1rem;font-size:.6rem;font-weight:700;text-transform:uppercase;opacity:.7;white-space:nowrap}" +
			".md-select__item.agl-note{padding:.5rem 1rem;font-size:.62rem;line-height:1.35;white-space:normal;width:14rem;opacity:.8;border-top:.05rem solid var(--md-default-fg-color--lightest)}" +
			".agl-tick{margin-left:.5rem;font-weight:700}" +
			"#agl-banner{position:fixed;left:0;right:0;bottom:0;z-index:5;display:flex;gap:.8rem;align-items:center;padding:.6rem 1rem;font-size:.7rem;background:var(--md-default-bg-color);color:var(--md-default-fg-color);border-top:.1rem solid var(--md-accent-fg-color,#448aff);box-shadow:0 -.1rem .4rem rgba(0,0,0,.2)}" +
			"#agl-banner span{flex:1}#agl-banner button{border:0;background:none;color:inherit;font-size:1rem;cursor:pointer}";
		document.head.appendChild(s);
	}
	function li(cls, child) {
		var e = document.createElement("li");
		e.className = "md-select__item " + cls;
		if (child) e.appendChild(child);
		return e;
	}
	function ticks() {
		var rs = roots(), h = here(rs);
		if (!h) return;
		var auto = document.querySelector(".md-select__link[data-agl=auto]");
		var set = function (a, on) {
			var t = a.querySelector(".agl-tick");
			if (!t) { t = document.createElement("span"); t.className = "agl-tick"; t.setAttribute("aria-hidden", "true"); a.appendChild(t); }
			t.textContent = on ? "✓" : "";
		};
		for (var i = 0; i < rs.length; i++) set(rs[i].a, rs[i] === h);
		if (auto) set(auto, !getPref());
	}
	/** Adds the heading, the Automatic line and the note to the header selector (once per list; the theme may replace the header on navigation). */
	function decorate() {
		var rs = roots(), h = here(rs), ul = document.querySelector(".md-select__list");
		if (!ul || !h || ul.getAttribute("data-agl")) return;
		ul.setAttribute("data-agl", "1");
		css();
		var T = TEXT[h.lang] || TEXT.en;
		var head = li("agl-head"); head.textContent = T.published;
		ul.insertBefore(head, ul.firstChild);
		var a = document.createElement("a");
		a.className = "md-select__link"; a.href = "#"; a.setAttribute("data-agl", "auto"); a.textContent = T.auto;
		ul.appendChild(li("", a));
		var note = li("agl-note"); note.textContent = T.other;
		ul.appendChild(note);
		ticks();
	}

	document.addEventListener("click", function (e) {
		var a = e.target && e.target.closest ? e.target.closest(".md-select__link") : null;
		if (!a || e.button || e.ctrlKey || e.metaKey || e.shiftKey) return;
		var rs = roots(), h = here(rs);
		if (!h) return;
		e.preventDefault();
		e.stopImmediatePropagation();   // a full page load: the other language is a different site, not a page of this one
		var lang;
		store(function () { sessionStorage.removeItem("agl-doc-hub-lang"); });   // a choice made here beats the hub's for this tab
		if (a.getAttribute("data-agl") === "auto") { clearPref(); lang = detect(rs); }
		else { lang = base(a.getAttribute("hreflang")); setPref(lang); }
		ticks();
		if (lang !== h.lang) go(rs, lang, false);
	}, true);

	/** A link in the page (not the header selector) that leads into another language's site, such as the Languages line of the home page: it is a choice of language too, so it is saved; otherwise start() sends the reader back to the saved language. */
	document.addEventListener("click", function (e) {
		var a = e.target && e.target.closest ? e.target.closest("a[href]") : null;
		if (!a || a.closest(".md-select__link") || e.button || e.ctrlKey || e.metaKey || e.shiftKey) return;
		var rs = roots(), h = here(rs);
		if (!h) return;
		var p;
		try { p = new URL(a.getAttribute("href"), location.href); } catch (x) { return; }
		if (p.origin !== location.origin) return;
		var t = null;
		for (var i = 0; i < rs.length; i++)
			if (p.pathname.indexOf(rs[i].root) === 0 && (!t || rs[i].root.length > t.root.length)) t = rs[i];
		if (!t || t.lang === h.lang) return;
		store(function () { sessionStorage.removeItem("agl-doc-hub-lang"); });
		setPref(t.lang);
		ticks();
	}, true);

	/** The hub's local copy: the hub has already chosen the language folder; tell the person how to translate when that language is not published. */
	function hubBanner() {
		var o = document.querySelector(".md-header__option");
		if (o) o.style.display = "none";   // the selector points at the web site; the hub chooses the language here
		showBanner(base(window.aglHubLang));
	}
	/** The bar telling how to use the browser's Translate, in that language (English when there is no text for it). */
	function showBanner(hub) {
		if (!hub || hub === base(document.documentElement.lang) || document.getElementById("agl-banner")) return;
		if (store(function () { return sessionStorage.getItem(BANNER_KEY); })) return;
		css();
		var b = document.createElement("div"), s = document.createElement("span"), x = document.createElement("button");
		b.id = "agl-banner";
		s.textContent = HUB[hub] || HUB.en;
		x.type = "button"; x.textContent = "×"; x.setAttribute("aria-label", "Close");
		x.onclick = function () { store(function () { sessionStorage.setItem(BANNER_KEY, "1"); }); b.remove(); };
		b.appendChild(s); b.appendChild(x);
		document.body.appendChild(b);
	}

	function start() {
		var rs = roots(), h = here(rs);
		if (!h) { hubBanner(); return; }
		var want = wanted(rs);
		if (want !== h.lang) { go(rs, want, true); return; }   // first load only: a later page of the same site is already in the right language
		decorate();
		if (hubRaw && !find(rs, hubRaw)) showBanner(hubRaw);   // the hub is in a language with no published pages: say how to translate
		var queued = false;
		new MutationObserver(function () {
			if (queued) return;
			queued = true;
			requestAnimationFrame(function () { queued = false; decorate(); });
		}).observe(document.body, { childList: true, subtree: true });
	}
	if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
