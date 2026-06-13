/*
 * BDS Radar — map client.
 *
 * A static Leaflet client (ADR-0003) that renders live RealEstate inventory.
 * - Base tiles: OpenStreetMap raster, with the mandatory "© OpenStreetMap
 *   contributors" attribution always visible.
 * - Points layer (issue #28): on load and on every pan/zoom (moveend) it derives
 *   the viewport bbox and queries GET /real_estates with the bbox ransack params,
 *   dropping one marker per result. Default status=active is respected.
 * - Price heatmap layer (issue #30): overlays geo-grid aggregation cells from
 *   GET /real_estates/map, colour-graded by price_per_m2, with a visible legend.
 *   Points + heatmap coexist behind a Leaflet layer control.
 */
(function () {
  "use strict";

  // Leaflet ships default marker icons by relative path; point them at the
  // locally-vendored images so nothing is fetched from a CDN.
  // Icon.Default._getIconUrl prepends the auto-detected imagePath to whatever
  // URL we set, which doubles our absolute paths (".../images//map/vendor/...")
  // and 404s every marker. Drop it so our explicit URLs are used verbatim.
  delete L.Icon.Default.prototype._getIconUrl;
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

  var TYPES = ["condo", "house", "land", "commercial", "other"];
  // Price inputs are entered in triệu (millions VND); converted to raw VND for
  // the q[price_*] ransack params, which match the stored VND price.
  var PRICE_UNIT = 1e6;

  // Heatmap colour ramp (cold -> hot). Keep in sync with .legend-bar in app.css.
  var HEAT_GRADIENT = {
    0.0: "#2b83ba",
    0.4: "#abdda4",
    0.6: "#ffffbf",
    0.8: "#fdae61",
    1.0: "#d7191c",
  };

  // --- Map ------------------------------------------------------------------
  var map = L.map("map").setView(DEFAULT_CENTER, DEFAULT_ZOOM);

  // OSM raster tiles. Attribution is mandatory (ADR-0003) and stays visible.
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution:
      '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);

  // Overlay layers. Both are added by default so they coexist; the layer control
  // lets the user toggle either one off so they never obscure each other.
  var markersLayer = L.layerGroup().addTo(map);
  var heatLayer = L.heatLayer([], {
    radius: 40,
    blur: 22,
    // Geo-grid cells are sparse, so max:1.0 leaves even the hottest cell
    // near-transparent (peak alpha ~20%). Cap accumulation lower and floor the
    // opacity so the price/m² ramp actually reads against the basemap.
    max: 0.5,
    minOpacity: 0.4,
    gradient: HEAT_GRADIENT,
  }).addTo(map);

  L.control
    .layers(
      null,
      {
        "Listings (points)": markersLayer,
        "Price heatmap": heatLayer,
      },
      { collapsed: false }
    )
    .addTo(map);

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

  // --- Legend (colour -> price per m²) --------------------------------------
  var legendControl = L.control({ position: "bottomright" });
  legendControl.onAdd = function () {
    var div = L.DomUtil.create("div", "legend");
    div.innerHTML =
      '<div class="legend-title">Price / m²</div>' +
      '<div class="legend-empty">no data in view</div>';
    return div;
  };
  legendControl.addTo(map);

  // --- Filter controls (issue #31) ------------------------------------------
  // Hand-rolled (no third-party UI dep). Controls map to ransack q[...] params
  // and compose: type + price range + area range are all sent together. Clearing
  // resets to the default status=active view (we never send q[status_eq]).
  var filterRefs = {};
  var filterControl = L.control({ position: "topleft" });
  filterControl.onAdd = function () {
    var div = L.DomUtil.create("div", "filters");
    var typeOptions = ['<option value="">All types</option>']
      .concat(
        TYPES.map(function (t) {
          return '<option value="' + t + '">' + t + "</option>";
        })
      )
      .join("");
    div.innerHTML =
      '<div class="filters-title">Filters</div>' +
      '<label><span>Type</span>' +
      '<select id="f-type">' +
      typeOptions +
      "</select></label>" +
      '<label><span>Price (triệu)</span>' +
      '<div class="filters-range">' +
      '<input id="f-price-min" type="number" min="0" step="any" placeholder="min" />' +
      '<input id="f-price-max" type="number" min="0" step="any" placeholder="max" />' +
      "</div></label>" +
      '<label><span>Area (m²)</span>' +
      '<div class="filters-range">' +
      '<input id="f-area-min" type="number" min="0" step="any" placeholder="min" />' +
      '<input id="f-area-max" type="number" min="0" step="any" placeholder="max" />' +
      "</div></label>" +
      '<div class="filters-actions">' +
      '<button type="button" class="apply" id="f-apply">Apply</button>' +
      '<button type="button" class="clear" id="f-clear">Clear</button>' +
      "</div>";

    // Keep clicks/scrolls on the panel from panning/zooming the map underneath.
    L.DomEvent.disableClickPropagation(div);
    L.DomEvent.disableScrollPropagation(div);
    return div;
  };
  filterControl.addTo(map);

  // Cache input references and wire change/click handlers after the control DOM
  // exists. Changing any control re-fetches both layers for the current bbox.
  filterRefs.type = document.getElementById("f-type");
  filterRefs.priceMin = document.getElementById("f-price-min");
  filterRefs.priceMax = document.getElementById("f-price-max");
  filterRefs.areaMin = document.getElementById("f-area-min");
  filterRefs.areaMax = document.getElementById("f-area-max");

  [
    filterRefs.type,
    filterRefs.priceMin,
    filterRefs.priceMax,
    filterRefs.areaMin,
    filterRefs.areaMax,
  ].forEach(function (el) {
    el.addEventListener("change", function () {
      scheduleRefresh();
    });
  });

  document.getElementById("f-apply").addEventListener("click", function () {
    refresh();
  });
  document.getElementById("f-clear").addEventListener("click", function () {
    filterRefs.type.value = "";
    filterRefs.priceMin.value = "";
    filterRefs.priceMax.value = "";
    filterRefs.areaMin.value = "";
    filterRefs.areaMax.value = "";
    refresh();
  });

  // Build the q[...] ransack params from the current filter inputs. Empty inputs
  // are omitted so they don't constrain the query. Price is converted triệu->VND.
  function activeFilters() {
    var f = {};
    if (filterRefs.type && filterRefs.type.value) {
      f["q[type_eq]"] = filterRefs.type.value;
    }
    var pMin = parseFloat(filterRefs.priceMin.value);
    var pMax = parseFloat(filterRefs.priceMax.value);
    var aMin = parseFloat(filterRefs.areaMin.value);
    var aMax = parseFloat(filterRefs.areaMax.value);
    if (!isNaN(pMin)) f["q[price_gteq]"] = String(pMin * PRICE_UNIT);
    if (!isNaN(pMax)) f["q[price_lteq]"] = String(pMax * PRICE_UNIT);
    if (!isNaN(aMin)) f["q[area_gteq]"] = String(aMin);
    if (!isNaN(aMax)) f["q[area_lteq]"] = String(aMax);
    return f;
  }

  // price_per_m2 is assumed to be VND per m² (raw price / area, ADR-0003 grid
  // aggregation). We display it as triệu/m² (millions of VND) for readability.
  function toTrieu(vndPerM2) {
    return (vndPerM2 / 1e6).toFixed(1);
  }

  function updateLegend(minPpm, maxPpm) {
    var container = legendControl.getContainer();
    if (minPpm == null || maxPpm == null) {
      container.innerHTML =
        '<div class="legend-title">Price / m²</div>' +
        '<div class="legend-empty">no data in view</div>';
      return;
    }
    var midPpm = (minPpm + maxPpm) / 2;
    container.innerHTML =
      '<div class="legend-title">Price / m² (triệu/m²)</div>' +
      '<div class="legend-bar"></div>' +
      '<div class="legend-scale">' +
      "<span>" +
      toTrieu(minPpm) +
      "</span>" +
      "<span>" +
      toTrieu(midPpm) +
      "</span>" +
      "<span>" +
      toTrieu(maxPpm) +
      "</span>" +
      "</div>";
  }

  // --- Querying -------------------------------------------------------------

  // Shared bbox ransack params for the current viewport. Extra params (used by
  // later filter slices) are merged in. We never set q[status_eq], so the API
  // default of status=active applies.
  function bboxParams(extra) {
    var b = map.getBounds();
    var params = new URLSearchParams();
    params.set("q[latitude_gteq]", b.getSouth());
    params.set("q[latitude_lteq]", b.getNorth());
    params.set("q[longitude_gteq]", b.getWest());
    params.set("q[longitude_lteq]", b.getEast());
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
      var params = bboxParams(activeFilters());
      params.set("per_page", String(PER_PAGE));
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

  // Fetch geo-grid aggregation cells for the viewport from GET /real_estates/map.
  // The exact response envelope is being finalised on another branch, so we
  // unwrap defensively: a bare array, { cells }, { map_cells }, or { data }.
  // Each cell is expected to look like { lat, lng, count, median_price,
  // price_per_m2 }.
  function fetchMapCells() {
    var params = bboxParams(activeFilters());
    return fetch("/real_estates/map?" + params.toString(), {
      headers: { Accept: "application/json" },
    })
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.json();
      })
      .then(function (data) {
        if (Array.isArray(data)) return data;
        return data.cells || data.map_cells || data.data || [];
      });
  }

  function renderMarkers(records) {
    markersLayer.clearLayers();
    records.forEach(function (re) {
      if (re.latitude == null || re.longitude == null) return;
      L.marker([re.latitude, re.longitude]).addTo(markersLayer);
    });
  }

  function cellLat(c) {
    return c.lat != null ? c.lat : c.latitude;
  }
  function cellLng(c) {
    return c.lng != null ? c.lng : c.longitude;
  }

  function renderHeat(cells) {
    var usable = cells.filter(function (c) {
      return (
        cellLat(c) != null &&
        cellLng(c) != null &&
        c.price_per_m2 != null &&
        c.price_per_m2 > 0
      );
    });

    if (usable.length === 0) {
      heatLayer.setLatLngs([]);
      updateLegend(null, null);
      return;
    }

    var values = usable.map(function (c) {
      return c.price_per_m2;
    });
    var min = Math.min.apply(null, values);
    var max = Math.max.apply(null, values);
    var span = max - min || 1; // avoid divide-by-zero when all cells equal

    // Normalise price_per_m2 to [0,1] intensity so the gradient maps colour ->
    // price/m² (not raw density). A floor of 0.15 keeps the lowest cells visible.
    var points = usable.map(function (c) {
      var norm = (c.price_per_m2 - min) / span;
      var intensity = 0.15 + 0.85 * norm;
      return [cellLat(c), cellLng(c), intensity];
    });

    heatLayer.setLatLngs(points);
    updateLegend(min, max);
  }

  function refresh() {
    showStatus("Loading…");

    var pointsP = fetchRealEstates().then(function (result) {
      renderMarkers(result.records);
      var shown = result.records.length;
      if (result.total > shown) {
        showCapNote(shown, result.total);
      } else {
        hideCapNote();
      }
    });

    var heatP = fetchMapCells()
      .then(function (cells) {
        renderHeat(cells);
      })
      .catch(function () {
        // The /real_estates/map endpoint may not be deployed yet (built on a
        // sibling branch). Degrade gracefully: keep points, clear the heatmap.
        renderHeat([]);
      });

    Promise.all([pointsP, heatP])
      .then(function () {
        hideStatus();
      })
      .catch(function (err) {
        showStatus("Failed to load: " + err.message);
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
