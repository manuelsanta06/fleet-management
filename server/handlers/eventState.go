package handlers

import (
	"net/http"
	"time"
	"os"

	"github.com/manuelsanta06/agenda/database"
)

func UpdateEventStatesHandler(w http.ResponseWriter,r *http.Request){
	apiSecret:=os.Getenv("API_SECRET")
	authHeader:=r.Header.Get("Authorization")
	if authHeader!="Bearer "+apiSecret{
		http.Error(w,"Acceso no autorizado",http.StatusUnauthorized)
		return
	}

	targetDate:=time.Now().UTC()
	dateParam:=r.URL.Query().Get("date")
	if dateParam!=""{
		parsedDate,err:=time.Parse("2006-01-02",dateParam)
		if err==nil{
			targetDate=parsedDate
		}
	}

	err:=database.UpdateEventStatesRoutine(targetDate)
	if err!=nil{
		http.Error(w,err.Error(),http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "ok", "mensaje": "estados de eventos recalculados y actualizados"}`))
}
