package osm

import (
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// Zone mirrors Flutter's BlockZone JSON shape.
type Zone struct {
	ID       string   `json:"id"`
	Vertices []LatLng `json:"vertices"`
	Centroid LatLng   `json:"centroid"`
	Owner    string   `json:"owner"`
}

type LatLng struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// ── Overpass ──────────────────────────────────────────────────────────────────

const overpassURL = "https://overpass-api.de/api/interpreter"

// Расширенная зона центра Якутска
const bbox = "62.005,129.670,62.060,129.800"

const query = `[out:json][timeout:60];
(
  way[landuse~"residential|commercial|retail|industrial|civic|mixed"](` + bbox + `);
  way[leisure~"park|garden|pitch|playground|sports_centre"](` + bbox + `);
  way[natural~"wood|grassland"](` + bbox + `);
);
out geom;
`

type overpassResponse struct {
	Elements []struct {
		Type     string `json:"type"`
		ID       int64  `json:"id"`
		Geometry []struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		} `json:"geometry"`
	} `json:"elements"`
}

// LoadZones пробует Overpass, при неудаче — OSM API напрямую.
func LoadZones() ([]Zone, error) {
	zones, err := loadFromOverpass()
	if err != nil || len(zones) == 0 {
		log.Printf("Overpass не сработал (%v), пробуем OSM API...", err)
		return loadFromOsmAPI()
	}
	return zones, nil
}

func loadFromOverpass() ([]Zone, error) {
	log.Println("Запрос к Overpass API...")
	client := &http.Client{Timeout: 70 * time.Second}

	form := url.Values{}
	form.Set("data", query)
	req, err := http.NewRequest("POST", overpassURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", "KVARTAL/1.0 (yakutsk running app)")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("overpass: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("overpass HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read: %w", err)
	}
	if strings.Contains(string(body[:min(200, len(body))]), "<html") {
		return nil, fmt.Errorf("overpass вернул HTML (сервер занят)")
	}

	var result overpassResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("parse: %w", err)
	}

	var raw []Zone
	for _, el := range result.Elements {
		if el.Type != "way" || len(el.Geometry) == 0 {
			continue
		}
		var verts []LatLng
		for _, g := range el.Geometry {
			verts = append(verts, LatLng{Lat: g.Lat, Lng: g.Lon})
		}
		if !validBlock(verts) {
			continue
		}
		id := fmt.Sprintf("%d", el.ID)
		raw = append(raw, Zone{
			ID:       id,
			Vertices: verts,
			Centroid: centroid(verts),
			Owner:    mockOwner(id),
		})
	}

	zones := removeContainers(raw)
	log.Printf("Overpass: %d кварталов из %d элементов", len(zones), len(result.Elements))
	return zones, nil
}

// ── OSM API XML (резервный источник) ─────────────────────────────────────────

const osmAPIURL = "https://api.openstreetmap.org/api/0.6/map"

// bbox для OSM API: left,bottom,right,top
const osmBbox = "129.700,62.015,129.760,62.045"

var landuseTags = map[string]bool{
	"residential": true, "commercial": true, "retail": true,
	"industrial": true, "civic": true, "mixed": true,
}
var leisureTags = map[string]bool{
	"park": true, "garden": true, "pitch": true,
	"playground": true, "sports_centre": true,
}
var naturalTags = map[string]bool{"wood": true, "grassland": true}

type osmXML struct {
	Nodes []struct {
		ID  string  `xml:"id,attr"`
		Lat float64 `xml:"lat,attr"`
		Lon float64 `xml:"lon,attr"`
	} `xml:"node"`
	Ways []struct {
		ID  string `xml:"id,attr"`
		Nds []struct {
			Ref string `xml:"ref,attr"`
		} `xml:"nd"`
		Tags []struct {
			K string `xml:"k,attr"`
			V string `xml:"v,attr"`
		} `xml:"tag"`
	} `xml:"way"`
}

func loadFromOsmAPI() ([]Zone, error) {
	log.Printf("Запрос к OSM API (bbox %s)...", osmBbox)
	client := &http.Client{Timeout: 60 * time.Second}

	req, _ := http.NewRequest("GET",
		fmt.Sprintf("%s?bbox=%s", osmAPIURL, osmBbox), nil)
	req.Header.Set("User-Agent", "KVARTAL/1.0 (yakutsk running app)")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("osm api: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("osm api HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read osm: %w", err)
	}

	var osm osmXML
	if err := xml.Unmarshal(body, &osm); err != nil {
		return nil, fmt.Errorf("parse xml: %w", err)
	}

	// Build node id → coords map
	nodeMap := make(map[string][2]float64, len(osm.Nodes))
	for _, n := range osm.Nodes {
		nodeMap[n.ID] = [2]float64{n.Lat, n.Lon}
	}

	var raw []Zone
	for _, w := range osm.Ways {
		// Check if way has a relevant tag
		matched := false
		for _, t := range w.Tags {
			if (t.K == "landuse" && landuseTags[t.V]) ||
				(t.K == "leisure" && leisureTags[t.V]) ||
				(t.K == "natural" && naturalTags[t.V]) {
				matched = true
				break
			}
		}
		if !matched {
			continue
		}

		var verts []LatLng
		for _, nd := range w.Nds {
			if c, ok := nodeMap[nd.Ref]; ok {
				verts = append(verts, LatLng{Lat: c[0], Lng: c[1]})
			}
		}
		if !validBlock(verts) {
			continue
		}
		id := w.ID
		raw = append(raw, Zone{
			ID:       id,
			Vertices: verts,
			Centroid: centroid(verts),
			Owner:    mockOwner(id),
		})
	}

	zones := removeContainers(raw)
	log.Printf("OSM API: %d кварталов из %d way-элементов", len(zones), len(osm.Ways))
	return zones, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// ── Файловый кэш ─────────────────────────────────────────────────────────────

const cacheFile = "zones_cache.json"
const cacheTTL = 12 * time.Hour

type cacheEnvelope struct {
	SavedAt time.Time `json:"saved_at"`
	Zones   []Zone    `json:"zones"`
}

const staticFile = "yakutsk_zones.json"

// LoadZonesCached: статик-файл → runtime-кэш → Overpass/OSM API.
func LoadZonesCached() ([]Zone, error) {
	// 1. Статический файл с предобработанными данными (всегда свежий)
	if zones, ok := readStaticFile(); ok {
		return zones, nil
	}
	// 2. Runtime-кэш (сохранённый предыдущим сеансом)
	if zones, ok := readCache(); ok {
		return zones, nil
	}
	// 3. Живой запрос к API
	zones, err := LoadZones()
	if err != nil {
		return nil, err
	}
	writeCache(zones)
	return zones, nil
}

func readStaticFile() ([]Zone, bool) {
	data, err := os.ReadFile(staticFile)
	if err != nil {
		return nil, false
	}
	var env struct {
		Zones []Zone `json:"zones"`
	}
	if err := json.Unmarshal(data, &env); err != nil || len(env.Zones) == 0 {
		return nil, false
	}
	log.Printf("Статический файл: %d кварталов", len(env.Zones))
	return env.Zones, true
}

// RefreshCache принудительно обновляет кэш с Overpass.
func RefreshCache() ([]Zone, error) {
	zones, err := LoadZones()
	if err != nil {
		return nil, err
	}
	writeCache(zones)
	return zones, nil
}

func readCache() ([]Zone, bool) {
	data, err := os.ReadFile(cacheFile)
	if err != nil {
		return nil, false
	}
	var env cacheEnvelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil, false
	}
	if time.Since(env.SavedAt) > cacheTTL {
		log.Println("Кэш устарел, нужно обновление")
		return nil, false
	}
	log.Printf("Кэш загружен (%d кварталов, сохранён %s назад)", len(env.Zones),
		time.Since(env.SavedAt).Round(time.Minute))
	return env.Zones, true
}

func writeCache(zones []Zone) {
	env := cacheEnvelope{SavedAt: time.Now(), Zones: zones}
	data, err := json.Marshal(env)
	if err != nil {
		log.Printf("Ошибка сериализации кэша: %v", err)
		return
	}
	if err := os.WriteFile(cacheFile, data, 0644); err != nil {
		log.Printf("Ошибка записи кэша: %v", err)
		return
	}
	log.Printf("Кэш сохранён: %d кварталов", len(zones))
}

// ── Geometry helpers ──────────────────────────────────────────────────────────

func validBlock(pts []LatLng) bool {
	if len(pts) < 4 {
		return false
	}
	minLat, maxLat := pts[0].Lat, pts[0].Lat
	minLng, maxLng := pts[0].Lng, pts[0].Lng
	for _, v := range pts {
		if v.Lat < minLat {
			minLat = v.Lat
		}
		if v.Lat > maxLat {
			maxLat = v.Lat
		}
		if v.Lng < minLng {
			minLng = v.Lng
		}
		if v.Lng > maxLng {
			maxLng = v.Lng
		}
	}
	dLat := maxLat - minLat
	dLng := maxLng - minLng
	// Блок от ~50м до ~600м
	return dLat > 0.0003 && dLat < 0.007 && dLng > 0.0005 && dLng < 0.015
}

func centroid(pts []LatLng) LatLng {
	var lat, lng float64
	for _, p := range pts {
		lat += p.Lat
		lng += p.Lng
	}
	n := float64(len(pts))
	return LatLng{Lat: lat / n, Lng: lng / n}
}

func pointInPolygon(p LatLng, poly []LatLng) bool {
	inside := false
	j := len(poly) - 1
	for i := 0; i < len(poly); i++ {
		xi, yi := poly[i].Lng, poly[i].Lat
		xj, yj := poly[j].Lng, poly[j].Lat
		if ((yi > p.Lat) != (yj > p.Lat)) &&
			(p.Lng < (xj-xi)*(p.Lat-yi)/(yj-yi)+xi) {
			inside = !inside
		}
		j = i
	}
	return inside
}

func removeContainers(zones []Zone) []Zone {
	isContainer := make([]bool, len(zones))
	for i := range zones {
		if isContainer[i] {
			continue
		}
		for j := range zones {
			if i == j || isContainer[j] {
				continue
			}
			if pointInPolygon(zones[j].Centroid, zones[i].Vertices) {
				isContainer[i] = true
				break
			}
		}
	}
	var out []Zone
	for i, z := range zones {
		if !isContainer[i] {
			out = append(out, z)
		}
	}
	return out
}

func mockOwner(id string) string {
	h := 0
	for _, ch := range id {
		h = h*31 + int(ch)
	}
	if h < 0 {
		h = -h
	}
	h = h % 12
	switch {
	case h < 2:
		return "mine"
	case h < 5:
		return "club"
	case h < 8:
		return "enemy"
	default:
		return "free"
	}
}

func DistMeters(a, b LatLng) float64 {
	dLat := (b.Lat - a.Lat) * 111320.0
	dLng := (b.Lng - a.Lng) * 52250.0
	return math.Sqrt(dLat*dLat + dLng*dLng)
}
