package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"slices"
	"strconv"
	"strings"
	"time"

  "github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/manuelsanta06/agenda/models"
)

var DB *pgxpool.Pool


func parseWeekDays(daysStr string)[]time.Weekday{
	if daysStr==""{return nil}
	
	strDays:=strings.Split(strings.TrimSpace(daysStr)," ")
	var weekdays []time.Weekday
	
	for _,s:=range strDays{
		num,err:=strconv.Atoi(s)
		if err!=nil{continue}
		
		switch num{
      case 1:weekdays=append(weekdays,time.Monday)
      case 2:weekdays=append(weekdays,time.Tuesday)
      case 3:weekdays=append(weekdays,time.Wednesday)
      case 4:weekdays=append(weekdays,time.Thursday)
      case 5:weekdays=append(weekdays,time.Friday)
      case 6:weekdays=append(weekdays,time.Saturday)
      case 7:weekdays=append(weekdays,time.Sunday)
		}
	}
	return weekdays
}

func containsWeekday(days []time.Weekday,target time.Weekday)bool{
  return slices.Contains(days,target)
}


func Connect(){
  err:=godotenv.Load()
  if err!=nil{
    log.Println("Aviso: No se encontró archivo .env, usando variables del sistema")
  }

  connString:=os.Getenv("DATABASE_URL")
  if connString==""{
    log.Fatal("Error: La variable DATABASE_URL está vacía")
  }

  DB, err = pgxpool.New(context.Background(),connString)
  if err!=nil{
    log.Fatalf("No se pudo conectar a la base de datos: %v\n",err)
  }

  err=DB.Ping(context.Background())
  if err!=nil{
    log.Fatalf("La base de datos no responde el Ping: %v\n", err)
  }

  fmt.Println("¡Conexión exitosa a PostgreSQL local!")
}

func FullSync(payload models.SyncPayload)error{
  ctx:=context.Background()
  tx,err:=DB.Begin(ctx)
  if err!=nil{
	  return fmt.Errorf("error al iniciar la transacción: %v",err)
	}
  defer tx.Rollback(ctx)

	//TABLAS PRINCIPALES

	//Choferes
	for _, c := range payload.Choferes {
		_, err := tx.Exec(ctx, `
			INSERT INTO choferes (id, dni, name, surname, alias, mobile_number, picture_path, balance, is_active)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
			ON CONFLICT (id) DO UPDATE SET
				dni = EXCLUDED.dni,
				name = EXCLUDED.name,
				surname = EXCLUDED.surname,
				alias = EXCLUDED.alias,
				mobile_number = EXCLUDED.mobile_number,
				picture_path = EXCLUDED.picture_path,
				balance = EXCLUDED.balance,
				is_active = EXCLUDED.is_active,
				updated_at = CURRENT_TIMESTAMP;
		`, c.ID, c.Dni, c.Name, c.Surname, c.Alias, c.MobileNumber, c.PicturePath, c.Balance, c.IsActive)
		if err != nil {
			return fmt.Errorf("error guardando chofer %s: %v", c.ID, err)
		}
	}

	//Colectivos
	for _, col := range payload.Colectivos {
		_, err := tx.Exec(ctx, `
			INSERT INTO colectivos (id,plate,vtv,name,number,capacity,fuel_amount,fuel_date,oil_date,is_active,data)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
			ON CONFLICT (id) DO UPDATE SET
				plate = EXCLUDED.plate,
				vtv = EXCLUDED.vtv,
				name = EXCLUDED.name,
				number = EXCLUDED.number,
				capacity = EXCLUDED.capacity,
				fuel_amount = EXCLUDED.fuel_amount,
				fuel_date = EXCLUDED.fuel_date,
				oil_date = EXCLUDED.oil_date,
				is_active = EXCLUDED.is_active,
        data = EXCLUDED.data,
				updated_at = CURRENT_TIMESTAMP;
		`, col.ID, col.Plate, col.Vtv, col.Name, col.Number, col.Capacity, col.FuelAmount, col.FuelDate, col.OilDate, col.IsActive,col.Data)
		if err != nil {
			return fmt.Errorf("error guardando colectivo %s: %v", col.ID, err)
		}
	}

	//Recorridos
	for _, r := range payload.Recorridos {
		_, err := tx.Exec(ctx, `
			INSERT INTO recorridos (id, name, base_price, is_active)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (id) DO UPDATE SET
				name = EXCLUDED.name,
				base_price = EXCLUDED.base_price,
				is_active = EXCLUDED.is_active,
				updated_at = CURRENT_TIMESTAMP;
		`, r.ID, r.Name, r.BasePrice, r.IsActive)
		if err != nil {
			return fmt.Errorf("error guardando recorrido %s: %v", r.ID, err)
		}
	}


	//TABLAS CON DEPENDENCIAS

  //Passengers
	for _, p := range payload.Passengers {
		_, err := tx.Exec(ctx, `
			INSERT INTO passengers (id, name, manager_name, manager_phone, custom_price, recorrido_id, is_active)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (id) DO UPDATE SET
				name = EXCLUDED.name,
				manager_name = EXCLUDED.manager_name,
				manager_phone = EXCLUDED.manager_phone,
				custom_price = EXCLUDED.custom_price,
				recorrido_id = EXCLUDED.recorrido_id,
				is_active = EXCLUDED.is_active,
				updated_at = CURRENT_TIMESTAMP;
		`, p.ID, p.Name, p.ManagerName, p.ManagerPhone, p.CustomPrice, p.RecorridoID, p.IsActive)
		if err != nil {
			return fmt.Errorf("error guardando passenger %s: %v", p.ID, err)
		}
	}

	//Events
	for _, e := range payload.Events {
		_, err := tx.Exec(ctx, `
			INSERT INTO events (id, name, data, bus_amount, contact_name, contact, repeat, days, start_date_time, end_date_time, stop_repeating_date_time, state, type, is_trip, shift_id, recorrido_id)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
			ON CONFLICT (id) DO UPDATE SET
				name = EXCLUDED.name,
				data = EXCLUDED.data,
        bus_amount = EXCLUDED.bus_amount,
				contact_name = EXCLUDED.contact_name,
				contact = EXCLUDED.contact,
				repeat = EXCLUDED.repeat,
				days = EXCLUDED.days,
				start_date_time = EXCLUDED.start_date_time,
				end_date_time = EXCLUDED.end_date_time,
				stop_repeating_date_time = EXCLUDED.stop_repeating_date_time,
				state = EXCLUDED.state,
				type = EXCLUDED.type,
				is_trip = EXCLUDED.is_trip,
				shift_id = EXCLUDED.shift_id,
        recorrido_id = EXCLUDED.recorrido_id,
				updated_at = CURRENT_TIMESTAMP;
		`, e.ID, e.Name, e.Data, e.BusAmount, e.ContactName, e.Contact, e.Repeat, e.Days, e.StartDateTime, e.EndDateTime, e.StopRepeatingDateTime, e.State, e.Type, e.IsTrip, e.ShiftID, e.RecorridoID)
		if err != nil {
			return fmt.Errorf("error guardando event %s: %v", e.ID, err)
		}
	}

	//Debts
	for _, d := range payload.Debts {
		_, err := tx.Exec(ctx, `
			INSERT INTO debts (id, passenger_id, chofer_id, event_id, date, description, total_amount, paid_amount, is_settled)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
			ON CONFLICT (id) DO UPDATE SET
				passenger_id = EXCLUDED.passenger_id,
				chofer_id = EXCLUDED.chofer_id,
        event_id = EXCLUDED.event_id,
				date = EXCLUDED.date,
				description = EXCLUDED.description,
				total_amount = EXCLUDED.total_amount,
				paid_amount = EXCLUDED.paid_amount,
				is_settled = EXCLUDED.is_settled,
				updated_at = CURRENT_TIMESTAMP;
		`,d.ID,d.PassengerID,d.ChoferID,d.EventID,d.Date,d.Description,d.TotalAmount,d.PaidAmount,d.IsSettled)
		if err!=nil{
			return fmt.Errorf("error guardando debt %s: %v", d.ID, err)
		}
	}

	//LIMPIEZA DE TABLAS INTERMEDIAS Y DEPENDIENTES

  // Limpiar Stops (Dueño: Event)
	for _, e := range payload.Events {
		_, err := tx.Exec(ctx, `DELETE FROM stops WHERE event_id = $1`, e.ID)
		if err != nil {
			return fmt.Errorf("error limpiando stops del event %s: %v", e.ID, err)
		}
	}

	// Limpiar EventChoferes y EventColectivos (Dueño: Event)
	for _, e := range payload.Events {
		_, err := tx.Exec(ctx, `DELETE FROM event_choferes WHERE event_id = $1`, e.ID)
		if err != nil {
			return fmt.Errorf("error limpiando choferes del event %s: %v", e.ID, err)
		}
		_, err = tx.Exec(ctx, `DELETE FROM event_colectivos WHERE event_id = $1`, e.ID)
		if err != nil {
			return fmt.Errorf("error limpiando colectivos del event %s: %v", e.ID, err)
		}
	}

	//INSERCIÓN DE TABLAS INTERMEDIAS Y DEPENDIENTES

  // Limpiar Stops (Dueño: Event)
  for _, s := range payload.Stops {
		_, err := tx.Exec(ctx, `
			INSERT INTO stops (id, name, start, event_id, order_index)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (id) DO NOTHING;
		`, s.ID, s.Name, s.Start, s.EventID, s.OrderIndex)
		if err != nil {
			return fmt.Errorf("error guardando stop %s: %v", s.ID, err)
		}
	}

	//EventChoferes (Dueño: Event)
	for _, ec := range payload.EventChoferes {
		_, err := tx.Exec(ctx, `
			INSERT INTO event_choferes (event_id, chofer_id)
			VALUES ($1, $2)
			ON CONFLICT (event_id, chofer_id) DO NOTHING;
		`, ec.EventID, ec.ChoferID)
		if err != nil {
			return fmt.Errorf("error relacionando event %s con chofer %s: %v", ec.EventID, ec.ChoferID, err)
		}

		// Marcar al Evento como sucio
		_, err = tx.Exec(ctx, `UPDATE events SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`, ec.EventID)
		if err != nil {
			return fmt.Errorf("error marcando evento como sucio: %v", err)
		}
	}

	//EventColectivos (Dueño: Event)
	for _, ecol := range payload.EventColectivos {
		_, err := tx.Exec(ctx, `
			INSERT INTO event_colectivos (event_id, colectivo_id)
			VALUES ($1, $2)
			ON CONFLICT (event_id, colectivo_id) DO NOTHING;
		`, ecol.EventID, ecol.ColectivoID)
		if err != nil {
			return fmt.Errorf("error relacionando event %s con colectivo %s: %v", ecol.EventID, ecol.ColectivoID, err)
		}

		// Marcar al Evento como sucio
		_, err = tx.Exec(ctx, `UPDATE events SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`, ecol.EventID)
		if err != nil {
			return fmt.Errorf("error marcando evento como sucio: %v", err)
		}
	}

	// Confirmar Transacción
	err = tx.Commit(ctx)
	if err != nil {
		return fmt.Errorf("error al hacer commit de la transacción: %v", err)
	}

	return nil
}

func FetchCatalogSince(lastSyncStr string) (models.SyncPayload, error){
	ctx := context.Background()
	var payload models.SyncPayload

	payload.Choferes   = []models.Chofer{}
	payload.Colectivos = []models.Colectivo{}
	payload.Recorridos = []models.Recorrido{}
  payload.Passengers = []models.Passenger{}
	payload.Debts      = []models.Debt{}

	//CHOFERES
	rowsChoferes, err := DB.Query(ctx, `
		SELECT id, dni, name, surname, alias, mobile_number, picture_path, balance, is_active, created_at, updated_at 
		FROM choferes 
		WHERE updated_at > $1
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando choferes: %v", err)
	}
	defer rowsChoferes.Close()

	for rowsChoferes.Next() {
		var c models.Chofer
		err := rowsChoferes.Scan(&c.ID, &c.Dni, &c.Name, &c.Surname, &c.Alias, &c.MobileNumber, &c.PicturePath, &c.Balance, &c.IsActive, &c.CreatedAt, &c.UpdatedAt)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de chofer: %v", err)
		}
		payload.Choferes = append(payload.Choferes, c)
	}

	//COLECTIVOS
	rowsColectivos, err := DB.Query(ctx, `
		SELECT id, plate, vtv, name, number, capacity, fuel_amount, fuel_date, oil_date, is_active, data, created_at, updated_at 
		FROM colectivos 
		WHERE updated_at > $1
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando colectivos: %v", err)
	}
	defer rowsColectivos.Close()

	for rowsColectivos.Next() {
		var col models.Colectivo
		err := rowsColectivos.Scan(&col.ID, &col.Plate, &col.Vtv, &col.Name, &col.Number, &col.Capacity, &col.FuelAmount, &col.FuelDate, &col.OilDate, &col.IsActive, &col.Data, &col.CreatedAt, &col.UpdatedAt)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de colectivo: %v", err)
		}
		payload.Colectivos = append(payload.Colectivos, col)
	}

	//RECORRIDOS
	rowsRecorridos, err := DB.Query(ctx, `
		SELECT id, name, base_price, is_active, created_at, updated_at 
		FROM recorridos 
		WHERE updated_at > $1
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando recorridos: %v", err)
	}
	defer rowsRecorridos.Close()

	for rowsRecorridos.Next() {
		var r models.Recorrido
		err := rowsRecorridos.Scan(&r.ID, &r.Name, &r.BasePrice, &r.IsActive, &r.CreatedAt, &r.UpdatedAt)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de recorrido: %v", err)
		}
		payload.Recorridos = append(payload.Recorridos, r)
	}

    //PASSENGERS
	rowsPassengers, err := DB.Query(ctx, `
		SELECT id, name, manager_name, manager_phone, custom_price, recorrido_id, is_active, created_at, updated_at 
		FROM passengers 
		WHERE updated_at > $1
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando passengers: %v", err)
	}
	defer rowsPassengers.Close()

	for rowsPassengers.Next() {
		var p models.Passenger
		err := rowsPassengers.Scan(&p.ID, &p.Name, &p.ManagerName, &p.ManagerPhone, &p.CustomPrice, &p.RecorridoID, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de passenger: %v", err)
		}
		payload.Passengers = append(payload.Passengers, p)
	}

	//DEBTS
	rowsDebts,err:=DB.Query(ctx,`
		SELECT d.id, d.passenger_id, d.chofer_id, d.event_id, d.date, d.description, d.total_amount, d.paid_amount, d.is_settled, d.created_at, d.updated_at
		FROM debts d
		LEFT JOIN events e ON d.event_id = e.id
		WHERE d.updated_at > $1
		AND (
			d.event_id IS NULL 
			OR e.start_date_time >= NOW() - INTERVAL '30 days' 
			OR e.type = 4
		)
	`,lastSyncStr)
	if err!=nil{
		return payload,fmt.Errorf("error consultando debts: %v",err)
	}
	defer rowsDebts.Close()

	for rowsDebts.Next(){
		var d models.Debt
		err:=rowsDebts.Scan(&d.ID,&d.PassengerID,&d.ChoferID,&d.EventID,&d.Date,&d.Description,&d.TotalAmount,&d.PaidAmount,&d.IsSettled,&d.CreatedAt,&d.UpdatedAt)
		if err!=nil{
			return payload,fmt.Errorf("error leyendo fila de debt: %v",err)
		}
		payload.Debts=append(payload.Debts,d)
	}


	return payload, nil
}

func FetchEventsSince(lastSyncStr string) (models.SyncPayload, error){
	ctx := context.Background()
	var payload models.SyncPayload

	payload.Events = []models.Event{}
	payload.Stops = []models.Stop{}
	payload.EventChoferes = []models.EventChofer{}
	payload.EventColectivos = []models.EventColectivo{}

	//EVENTOS
	rowsEvents, err := DB.Query(ctx, `
		SELECT id, name, data, bus_amount, contact_name, contact, repeat, days, start_date_time, end_date_time, stop_repeating_date_time, state, type, is_trip, shift_id, recorrido_id, created_at, updated_at
		FROM events
		WHERE updated_at > $1 
		AND (start_date_time >= NOW() - INTERVAL '30 days' OR type = 4)
    ORDER BY CASE WHEN type = 4 THEN 0 ELSE 1 END, start_date_time ASC
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando events: %v", err)
	}
	defer rowsEvents.Close()

	for rowsEvents.Next() {
		var e models.Event
		err := rowsEvents.Scan(&e.ID, &e.Name, &e.Data,&e.BusAmount, &e.ContactName, &e.Contact, &e.Repeat, &e.Days, &e.StartDateTime, &e.EndDateTime, &e.StopRepeatingDateTime, &e.State, &e.Type, &e.IsTrip, &e.ShiftID, &e.RecorridoID, &e.CreatedAt, &e.UpdatedAt)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de event: %v", err)
		}
		payload.Events = append(payload.Events, e)
	}

	//STOPS
	rowsStops, err := DB.Query(ctx, `
		SELECT s.id, s.name, s.start, s.event_id, s.order_index
		FROM stops s
		JOIN events e ON s.event_id = e.id
		WHERE e.updated_at > $1 
		AND (e.start_date_time >= NOW() - INTERVAL '30 days' OR e.type = 4)
	`, lastSyncStr)
	if err!=nil {
		return payload,fmt.Errorf("error consultando stops: %v",err)
	}
	defer rowsStops.Close()

	for rowsStops.Next() {
		var s models.Stop
		err := rowsStops.Scan(&s.ID, &s.Name, &s.Start, &s.EventID, &s.OrderIndex)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de stop: %v", err)
		}
		payload.Stops = append(payload.Stops, s)
	}

	//EVENT CHOFERES (Dependientes de Events)
	rowsEventChoferes, err := DB.Query(ctx, `
		SELECT ec.event_id, ec.chofer_id
		FROM event_choferes ec
		JOIN events e ON ec.event_id = e.id
		WHERE e.updated_at > $1 
		AND (e.start_date_time >= NOW() - INTERVAL '30 days' OR e.type = 4)
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando event_choferes: %v", err)
	}
	defer rowsEventChoferes.Close()

	for rowsEventChoferes.Next() {
		var ec models.EventChofer
		err := rowsEventChoferes.Scan(&ec.EventID, &ec.ChoferID)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de event_choferes: %v", err)
		}
		payload.EventChoferes = append(payload.EventChoferes, ec)
	}

	//EVENT COLECTIVOS (Dependientes de Events)
	rowsEventColectivos, err := DB.Query(ctx, `
		SELECT ecol.event_id, ecol.colectivo_id
		FROM event_colectivos ecol
		JOIN events e ON ecol.event_id = e.id
		WHERE e.updated_at > $1 
		AND (e.start_date_time >= NOW() - INTERVAL '30 days' OR e.type = 4)
	`, lastSyncStr)
	if err != nil {
		return payload, fmt.Errorf("error consultando event_colectivos: %v", err)
	}
	defer rowsEventColectivos.Close()

	for rowsEventColectivos.Next() {
		var ecol models.EventColectivo
		err := rowsEventColectivos.Scan(&ecol.EventID, &ecol.ColectivoID)
		if err != nil {
			return payload, fmt.Errorf("error leyendo fila de event_colectivos: %v", err)
		}
		payload.EventColectivos = append(payload.EventColectivos, ecol)
	}

	return payload, nil
}


type activeTemplate struct {
	ID            string
	Name          string
	Days          string
	StartTime     time.Time
	EndTime       time.Time
	RecorridoName string
  RecorridoID   string
	Data          string
  BusAmount     int
  State         int
}

func RecorridoShiftPopulationRoutine()error{
	ctx := context.Background()
	queryTemplates:=`
		SELECT e.id,e.days,e.start_date_time,e.end_date_time,e.name,r.name,e.recorrido_id,e.data,e.bus_amount,e.state
		FROM events e
		JOIN recorridos r ON e.recorrido_id = r.id
		WHERE e.type = 4 AND e.state != 1 AND r.is_active = TRUE
	`
	rows, err := DB.Query(ctx, queryTemplates)
	if err!=nil{
		return fmt.Errorf("error obteniendo templates: %w", err)
	}
	defer rows.Close()

	var templates []activeTemplate
	for rows.Next(){
		var t activeTemplate
		var daysPtr *string
		if err:=rows.Scan(&t.ID,&daysPtr,&t.StartTime,&t.EndTime,&t.Name,&t.RecorridoName,&t.RecorridoID,&t.Data,&t.BusAmount,&t.State);err!=nil{
			return fmt.Errorf("error leyendo template: %w",err)
		}
		if daysPtr!=nil{
			t.Days=*daysPtr
		}else{
			t.Days=""
		}
		templates=append(templates,t)
	}
	if err:=rows.Err();err!=nil{return err}

	now:=time.Now().UTC()
	startDate:=time.Date(now.Year(),now.Month(),now.Day(),0,0,0,0,time.UTC)

	//transaction
	tx, err := DB.Begin(ctx)
	if err != nil {
		return fmt.Errorf("error iniciando transacción: %w", err)
	}
	defer tx.Rollback(ctx)

	//days loop
	for i := range 16 {
		targetDate := startDate.AddDate(0, 0, i)
		targetWeekday := targetDate.Weekday()

		for _, template := range templates {
			//day check
			if template.Days==""{continue}
			templateDays := parseWeekDays(template.Days)
			if !containsWeekday(templateDays,targetWeekday){continue}

			//duplicate check
			var existingID string
			checkQuery := `SELECT id FROM events WHERE shift_id = $1 AND start_date_time::date = $2::date LIMIT 1`
			err = tx.QueryRow(ctx, checkQuery, template.ID, targetDate).Scan(&existingID)

			if err==nil{
				continue
			}else if err!=pgx.ErrNoRows{
				return fmt.Errorf("error comprobando idempotencia: %w", err)
			}

			eventID:=uuid.New().String()

			startDT:=time.Date(targetDate.Year(), targetDate.Month(), targetDate.Day(),
				template.StartTime.Hour(),template.StartTime.Minute(),template.StartTime.Second(),0,time.UTC)

			endDT:=time.Date(targetDate.Year(),targetDate.Month(),targetDate.Day(),
				template.EndTime.Hour(),template.EndTime.Minute(),template.EndTime.Second(), 0,time.UTC)

      insertEventQuery:=`
				INSERT INTO events (id, name, data, bus_amount, start_date_time, end_date_time, state, type, is_trip, shift_id, recorrido_id)
				VALUES ($1, $2, $3, $4, $5, $6, $7, 3, true, $8, $9)
			`
			_,err=tx.Exec(ctx,insertEventQuery,eventID,template.RecorridoName+" - "+template.Name,template.Data,template.BusAmount,startDT,endDT,template.State,template.ID,template.RecorridoID)
			if err!=nil{
				return fmt.Errorf("error insertando evento base: %w", err)
			}

			//Choferes
			copyChoferesQuery := `
				INSERT INTO event_choferes (event_id, chofer_id)
				SELECT $1, chofer_id FROM event_choferes WHERE event_id = $2
			`
			_, err = tx.Exec(ctx, copyChoferesQuery, eventID, template.ID)
			if err != nil {
				return fmt.Errorf("error copiando choferes: %w", err)
			}

			//Colectivos
      copyColectivosQuery:=`
				INSERT INTO event_colectivos (event_id, colectivo_id)
				SELECT $1, colectivo_id FROM event_colectivos WHERE event_id = $2
			`
			_, err = tx.Exec(ctx, copyColectivosQuery, eventID, template.ID)
			if err != nil {
				return fmt.Errorf("error copiando colectivos: %w", err)
			}

			//Stops
      copyStopsQuery := `
        INSERT INTO stops (id, name, start, event_id, order_index)
        SELECT gen_random_uuid()::text, name, $3::date + start::time, $1, order_index 
        FROM stops WHERE event_id = $2
      `
      _, err = tx.Exec(ctx, copyStopsQuery, eventID, template.ID, targetDate)
      if err!=nil{
        return fmt.Errorf("error copiando paradas: %w",err)
      }
    }
	}

	if err:=tx.Commit(ctx);err!=nil{
		return fmt.Errorf("error en el commit: %w", err)
	}

	fmt.Println("Populador ejecutado con éxito. Ventana de 16 días sincronizada.")
	return nil
}


type activePassenger struct {
	ID          string
	CustomPrice int
	BasePrice   int
}

func MonthlyDebtPopulationRoutine() error {
	ctx := context.Background()

	now := time.Now().UTC()
	firstDayOfMonth := time.Date(now.Year(), now.Month(), 1, 12, 30, 0, 0, time.UTC)

	queryPassengers := `
		SELECT p.id, p.custom_price, r.base_price
		FROM passengers p
		JOIN recorridos r ON p.recorrido_id = r.id
		WHERE p.is_active = TRUE AND r.is_active = TRUE
	`
	rows, err := DB.Query(ctx, queryPassengers)
	if err != nil {
		return fmt.Errorf("error obteniendo pasajeros activos: %w", err)
	}
	defer rows.Close()

	var passengers []activePassenger
	for rows.Next() {
		var p activePassenger
		if err := rows.Scan(&p.ID, &p.CustomPrice, &p.BasePrice); err != nil {
			return fmt.Errorf("error leyendo pasajero: %w", err)
		}
		passengers = append(passengers, p)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	tx, err := DB.Begin(ctx)
	if(err!=nil){
		return fmt.Errorf("error iniciando transacción: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, p := range passengers {
		// duplications check
		var existingID string
		checkQuery := `
			SELECT id FROM debts 
			WHERE passenger_id = $1 
			  AND date::date = $2::date 
			  AND description = 'Cuota' 
			LIMIT 1
		`
		err = tx.QueryRow(ctx, checkQuery, p.ID, firstDayOfMonth).Scan(&existingID)

		if(err==nil){
			continue
		} else if err != pgx.ErrNoRows {
			return fmt.Errorf("error comprobando idempotencia de deudas: %w", err)
		}

		//amount determination
		totalAmount := p.BasePrice
		if(p.CustomPrice!=-1){
			totalAmount = p.CustomPrice
		}

		debtID := uuid.New().String()
		insertDebtQuery:=`
			INSERT INTO debts (id, passenger_id, chofer_id, date, description, total_amount, paid_amount, is_settled)
			VALUES ($1, $2, NULL, $3, 'Cuota', $4, 0, FALSE)
		`
		_, err=tx.Exec(ctx, insertDebtQuery, debtID, p.ID, firstDayOfMonth, totalAmount)
		if(err!=nil){
			return fmt.Errorf("error insertando deuda mensual: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("error en el commit de facturación: %w", err)
	}

	fmt.Println("Facturación mensual ejecutada con éxito.")
	return nil
}

func FixFutureEventsStateRoutine(startDate time.Time)error{
	ctx:=context.Background()
	
	query:=`
		UPDATE events e
		SET state = parent.state, updated_at = CURRENT_TIMESTAMP
		FROM events parent
		WHERE e.shift_id = parent.id 
		  AND e.type = 3 
		  AND e.start_date_time >= $1
		  AND e.state != parent.state;
	`
	
	cmdTag,err:=DB.Exec(ctx,query,startDate)
	if err!=nil{
		return fmt.Errorf("error actualizando estados de eventos hijos: %w",err)
	}
	
	fmt.Printf("Mantenimiento: %d viajes actualizados desde %v.\n",cmdTag.RowsAffected(),startDate.Format("2006-01-02"))
	return nil
}
