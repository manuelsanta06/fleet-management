package main

import (
	// "encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/manuelsanta06/agenda/database"
	"github.com/manuelsanta06/agenda/handlers"
	"github.com/manuelsanta06/agenda/scheduler"
)

func main() {
	database.Connect()

  scheduler.Start()

	mux:=http.NewServeMux()
	mux.HandleFunc("GET /ping",handlers.PingHandler)

	mux.HandleFunc("POST /sync",handlers.SyncAllHandler)
  mux.HandleFunc("GET /sync/catalog",handlers.SyncCatalogHandler)
  mux.HandleFunc("GET /sync/events",handlers.SyncEventsHandler)

	mux.HandleFunc("POST /populate/recorridos",handlers.RecorridoShiftPopulationHandler)
	mux.HandleFunc("POST /populate/recorridosdebts",handlers.RecorridosDebtsPopulationHandler)

  mux.HandleFunc("POST /scheduler/toggle/shifts",handlers.ToggleShiftsSchedulerHandler)
	mux.HandleFunc("POST /scheduler/toggle/debts",handlers.ToggleDebtsSchedulerHandler)

  mux.HandleFunc("POST /maintenance/checkstates",handlers.UpdateEventStatesHandler)

	fmt.Println("Servidor corriendo en http://localhost:8080 ...")
	log.Fatal(http.ListenAndServe("127.0.0.1:8080",mux))
}
