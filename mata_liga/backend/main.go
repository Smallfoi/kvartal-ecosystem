package main

import (
	"log"
	"os"
	"sync"
	"time"

	"kvartal/backend/osm"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func main() {
	log.Println("КВАРТАЛ API стартует...")

	var (
		zones []osm.Zone
		mu    sync.RWMutex
		ready = make(chan struct{})
	)

	// Загружаем данные асинхронно — сервер стартует сразу
	go func() {
		for attempt := 1; ; attempt++ {
			log.Printf("Попытка %d: загружаем кварталы из OSM...", attempt)
			z, err := osm.LoadZonesCached()
			if err != nil {
				log.Printf("Ошибка (попытка %d): %v — повтор через 15с", attempt, err)
				time.Sleep(15 * time.Second)
				continue
			}
			mu.Lock()
			zones = z
			mu.Unlock()
			log.Printf("Загружено %d кварталов", len(z))
			select {
			case <-ready:
			default:
				close(ready)
			}
			// Обновляем каждые 12 часов
			time.Sleep(12 * time.Hour)
		}
	}()

	app := fiber.New(fiber.Config{AppName: "КВАРТАЛ API v1"})

	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format: "[${time}] ${method} ${path} → ${status} (${latency})\n",
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowMethods: "GET,POST,OPTIONS",
		AllowHeaders: "Content-Type",
	}))

	app.Get("/health", func(c *fiber.Ctx) error {
		mu.RLock()
		n := len(zones)
		mu.RUnlock()
		return c.JSON(fiber.Map{"status": "ok", "zones": n})
	})

	app.Get("/api/zones", func(c *fiber.Ctx) error {
		mu.RLock()
		z := zones
		mu.RUnlock()
		if len(z) == 0 {
			return c.Status(503).JSON(fiber.Map{"error": "loading", "zones": []osm.Zone{}})
		}
		return c.JSON(fiber.Map{"zones": z, "count": len(z)})
	})

	app.Post("/api/zones/reload", func(c *fiber.Ctx) error {
		go func() {
			fresh, err := osm.RefreshCache()
			if err != nil {
				log.Printf("Reload error: %v", err)
				return
			}
			mu.Lock()
			zones = fresh
			mu.Unlock()
			log.Printf("Перезагружено %d кварталов", len(fresh))
		}()
		return c.JSON(fiber.Map{"status": "reloading"})
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}
	log.Printf("Сервер слушает на 0.0.0.0:%s", port)
	log.Fatal(app.Listen("0.0.0.0:" + port))
}
