/*
 * BDS Radar — points map (issue #28).
 *
 * A static Leaflet client (ADR-0003) that renders live RealEstate inventory.
 * - Base tiles: OpenStreetMap raster, with the mandatory "© OpenStreetMap
 *   contributors" attribution always visible.
 * - On load and on every pan/zoom (moveend) it derives the viewport bbox and
 *   queries GET /real_estates with the bbox ransack params, dropping one marker
 *   per result. Default status=active is respected (we never send q[status_eq]).
 * - The index caps per_page at 100; we page through up to MAX_PAGES and, if the
 *   viewport still holds more listings than we drew, show a visible cap note so
 *   data is never silently dropped.
 */
(function () {
  "use strict";

  // Leaflet ships default marker icons by relative path; point them at the
  // locally-vendored images so nothing is fetched from a CDN.
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: "/map/vendor/leaflet/images/marker-icon-2x.png",
    iconUrl: "/map/vendor/leaflet/images/marker-icon.png",
    shadowUrl: "/map/vendor/leaflet/images/marker-shadow.png",
  });

  // --- Config --------------------------------------------------------------
  var DEFAULT_CENTER = [10.7769, 106.7009]; // Ho Chi Minh City
  var DEFAULT_ZOOM = 12;
  var PER_PAGE = 100; // index hard cap
  var MAX_PAGES = 5; // => up to 500 markers per viewport before we cap + note
  var DEBOUNCE_MS = 300;

  // --- Map ------------------------------------------------------------------
  var map = L.map("map").setView(DEFAULT_CENTER, DEFAULT_ZOOM);

  // OSM raster tiles. Attribution is mandatory (ADR-0003) and stays visible.
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);

  // Layer that holds the listing markers; cleared and refilled on each fetch.
  var markersLayer = L.layerGroup().addTo(map);

  var statusEl = document.getElementById("status");
  var capNoteEl = document.getElementById("cap-note");

  function showStatus(text) {
    statusEl.textContent = text;
    statusEl.hidden = false;
  }
  function hideStatus() {
    statusEl.hidden = true;
  }
  function showCapNote(shown, total) {
    capNoteEl.textContent =
      "Showing " +
      shown +
      " of " +
      total +
      " listings in view — zoom in to see the rest.";
    capNoteEl.hidden = false;
  }
  function hideCapNote() {
    capNoteEl.hidden = true;
  }

  // --- Querying -------------------------------------------------------------

  // Build the ransack bbox query for the current viewport. Extra params (used by
  // later slices for filters) are merged in. We never set q[status_eq], so the
  // API default of status=active applies.
  function bboxParams(extra) {
    var b = map.getBounds();
    var params = new URLSearchParams();
    params.set("q[latitude_gteq]", b.getSouth());
    params.set("q[latitude_lteq]", b.getNorth());
    params.set("q[longitude_gteq]", b.getWest());
    params.set("q[longitude_lteq]", b.getEast());
    params.set("per_page", String(PER_PAGE));
    if (extra) {
      Object.keys(extra).forEach(function (k) {
        params.set(k, extra[k]);
      });
    }
    return params;
  }

  // Fetch real estates in the viewport, paging up to MAX_PAGES.
  // Returns { records: [...], total: <total_count> }.
  function fetchRealEstates() {
    var collected = [];
    var total = 0;

    function fetchPage(page) {
      var params = bboxParams();
      params.set("page", String(page));
      return fetch("/real_estates?" + params.toString(), {
        headers: { Accept: "application/json" },
      })
        .then(function (res) {
          if (!res.ok) throw new Error("HTTP " + res.status);
          return res.json();
        })
        .then(function (data) {
          var items = data.real_estates || [];
          collected = collected.concat(items);
          var pg = data.pagination || {};
          total = pg.total_count != null ? pg.total_count : collected.length;
          var totalPages = pg.total_pages != null ? pg.total_pages : 1;
          if (page < totalPages && page < MAX_PAGES) {
            return fetchPage(page + 1);
          }
          return { records: collected, total: total };
        });
    }

    return fetchPage(1);
  }

  function renderMarkers(records) {
    markersLayer.clearLayers();
    records.forEach(function (re) {
      if (re.latitude == null || re.longitude == null) return;
      L.marker([re.latitude, re.longitude]).addTo(markersLayer);
    });
  }

  function refresh() {
    showStatus("Loading listings…");
    fetchRealEstates()
      .then(function (result) {
        renderMarkers(result.records);
        var shown = result.records.length;
        if (result.total > shown) {
          showCapNote(shown, result.total);
        } else {
          hideCapNote();
        }
        hideStatus();
      })
      .catch(function (err) {
        showStatus("Failed to load listings: " + err.message);
      });
  }

  // Debounce moveend so a drag-with-inertia fires one request, not many.
  var debounceTimer = null;
  function scheduleRefresh() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(refresh, DEBOUNCE_MS);
  }

  map.on("moveend", scheduleRefresh);
  refresh();
})();
