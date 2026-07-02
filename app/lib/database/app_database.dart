import 'dart:io';

import 'dart:developer';
import 'package:agenda/utilities/choferes.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;
import 'tables/users.dart';
import 'tables/events.dart';
import 'tables/recorridos.dart';
import 'tables/debt.dart';

import 'package:uuid/uuid.dart';
export 'tables/events.dart';

import 'package:agenda/constants.dart';

part 'app_database.g.dart';


class EventWithStops{
  final Event event;
  final List<Stop> stops;
  EventWithStops({required this.event, required this.stops});
}
class ColectivoWithEvents{
  final Colectivo col;
  final List<EventWithStops> eves;
  ColectivoWithEvents({required this.col,required this.eves});
}

class PassengerWithDebts{
  final Passenger passenger;
  final List<Debt> debts;
  PassengerWithDebts({required this.passenger,required this.debts});
}
class ChoferesWithDebts{
  final Chofer chofer;
  final List<Debt> debts;
  ChoferesWithDebts({required this.chofer,required this.debts});
}
class EventWithDebts{
  final Event event;
  final List<Debt> debts;
  EventWithDebts({required this.event,required this.debts});
}

enum ViewFilter{all,trips,school}

@DriftDatabase(tables:[
  Choferes,
  Colectivos,
  Events,
  Stops,
  EventChoferes,
  EventColectivos,
  Recorridos,
  Passengers,
  Debts

])
class AppDatabase extends _$AppDatabase{
  AppDatabase():super(_openConnection());

  @override
  int get schemaVersion=>9;

  @override
  MigrationStrategy get migration{
    return MigrationStrategy(
      onCreate:(Migrator m)async{
        await m.createAll();
      },
      onUpgrade:(Migrator m,int from,int to)async{
        if(from<2){
          await customStatement('ALTER TABLE recorrido_shifts ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0;');
        }if(from<3){
          await m.alterTable(TableMigration(
            events,
            newColumns:[events.shiftId],
          ));
        }if(from<4){
          await customStatement('DROP TABLE IF EXISTS shift_choferes;');
          await customStatement('DROP TABLE IF EXISTS shift_colectivos;');
          await customStatement('DROP TABLE IF EXISTS recorrido_shifts;');

          await m.alterTable(TableMigration(
            events,
            newColumns: [events.recorridoId], 
          ));
        }if(from<5){
          await customStatement('ALTER TABLE events ADD COLUMN price INTEGER NOT NULL DEFAULT 0;');
          await m.addColumn(events,events.data);
          await m.addColumn(colectivos,colectivos.vtv);
        }if(from<6){
          await customStatement('DROP TABLE IF EXISTS recorrido_subscriptions;');
          await customStatement('DROP TABLE IF EXISTS encargados;');

          await m.createTable(passengers);
          await m.createTable(debts);
        }if(from<7){
          await m.alterTable(TableMigration(debts,newColumns:[debts.eventId]));

          final oldEvents=await customSelect('SELECT id, price, start_date_time, name FROM events').get();

          for(final row in oldEvents){
            final dateObj=row.read<DateTime>('start_date_time');

            await into(debts).insert(DebtsCompanion(
              id:drift.Value(const Uuid().v4()),
              eventId:drift.Value(row.read<String>('id')),
              date:drift.Value(dateObj),
              description:drift.Value('Precio del evento: ${row.read<String>('name')}'),
              totalAmount:drift.Value(row.read<int>('price')),
              paidAmount:const drift.Value(0),
              isSettled:const drift.Value(false),
              isSynced:const drift.Value(false),
            ));
          }
          await m.alterTable(TableMigration(events,newColumns:[events.busAmount]));
        }if(from==7){
          await m.addColumn(events,events.busAmount);
        }if(from<9){
          await m.addColumn(colectivos,colectivos.data);
        }
      },
      beforeOpen:(details)async{
        await customStatement('PRAGMA foreign_keys=ON');
      },
    );
  }

  Future<void> nukeDatabase()async{
    await transaction(()async{
      for(final table in allTables)await delete(table).go();
    });
  }

  Future<void> markAllAsUnsynced()async{
    await transaction(()async{
      await update(choferes).write(const ChoferesCompanion(isSynced:Value(false)));
      await update(colectivos).write(const ColectivosCompanion(isSynced:Value(false)));
      await update(recorridos).write(const RecorridosCompanion(isSynced:Value(false)));
      await update(passengers).write(const PassengersCompanion(isSynced:Value(false)));
      await update(debts).write(const DebtsCompanion(isSynced:Value(false)));
      await update(events).write(const EventsCompanion(isSynced:Value(false)));
    });
  }

  Future<bool> markAsSynced(Map<String, dynamic> sentPayload)async{
    try{
      await transaction(()async{
        //Choferes
        final choferIds=(sentPayload['choferes'] as List).map((e) => e['id'] as String).toList();
        if (choferIds.isNotEmpty){
          await (update(choferes)..where((t) => t.id.isIn(choferIds)))
              .write(const ChoferesCompanion(isSynced:Value(true)));
        }

        //Colectivos
        final colectivoIds=(sentPayload['colectivos'] as List).map((e) => e['id'] as String).toList();
        if (colectivoIds.isNotEmpty){
          await (update(colectivos)..where((t) => t.id.isIn(colectivoIds)))
              .write(const ColectivosCompanion(isSynced:Value(true)));
        }

        //Recorridos
        final recorridoIds=(sentPayload['recorridos'] as List).map((e) => e['id'] as String).toList();
        if (recorridoIds.isNotEmpty){
          await (update(recorridos)..where((t) => t.id.isIn(recorridoIds)))
              .write(const RecorridosCompanion(isSynced:Value(true)));
        }

        //Passengers
        final passengersIds=(sentPayload['passengers'] as List).map((e)=>e['id'] as String).toList();
        if(passengersIds.isNotEmpty){
          await (update(passengers)..where((t)=>t.id.isIn(passengersIds)))
              .write(const PassengersCompanion(isSynced:Value(true)));
        }

        //Debts
        final debtsIds=(sentPayload['debts'] as List).map((e)=>e['id'] as String).toList();
        if(debtsIds.isNotEmpty){
          await (update(debts)..where((t)=>t.id.isIn(debtsIds)))
              .write(const DebtsCompanion(isSynced:Value(true)));
        }

        //Events
        final eventIds=(sentPayload['events'] as List).map((e)=>e['id'] as String).toList();
        if(eventIds.isNotEmpty){
          await (update(events)..where((t)=>t.id.isIn(eventIds)))
              .write(const EventsCompanion(isSynced:Value(true)));
        }
      });
      return true;
    }catch(e){
      log("Error marcando como sincronizado: $e");
      return false;
    }
  }

  Stream<(int, int)> watchVtvStatus(){
    final hoy=DateTime.now();
    final limite=hoy.add(const Duration(days:vtvAlert));

    return (select(colectivos)..where((t)=>t.is_active)).watch().map((lista){
      return(
        lista.where((c)=>!c.vtv.isAfter(hoy)).length,
        lista.where((c)=>c.vtv.isAfter(hoy)&&!c.vtv.isAfter(limite)).length
      );
    });
  }

  Future<Map<String,dynamic>> getUnsyncedPayload()async{
    final unsyncedChoferes  =await(select(choferes)..where((t)=>t.isSynced.equals(false))).get();
    final unsyncedColectivos=await(select(colectivos)..where((t)=>t.isSynced.equals(false))).get();
    final unsyncedRecorridos=await(select(recorridos)..where((t)=>t.isSynced.equals(false))).get();
    final unsyncedPassengers=await(select(passengers)..where((t)=>t.isSynced.equals(false))).get();
    final unsyncedDebts     =await(select(debts)..where((t)=>t.isSynced.equals(false))).get();
    final unsyncedEvents    =await(select(events)..where((t)=>t.isSynced.equals(false))).get();

    //look fordependant tables
    
    //events dependencies
    final eventIds=unsyncedEvents.map((e)=>e.id).toList();
    final eventStops=eventIds.isEmpty?<Stop>[]:
        await (select(stops)..where((t)=>t.eventId.isIn(eventIds))).get();
    final eventChoferesList=eventIds.isEmpty?<EventChofere>[]:
        await (select(eventChoferes)..where((t)=>t.eventId.isIn(eventIds))).get();
    final eventColectivosList=eventIds.isEmpty?<EventColectivo>[]:
        await (select(eventColectivos)..where((t)=>t.eventId.isIn(eventIds))).get();


    return{
      "choferes": unsyncedChoferes.map((c)=>{
        "id": c.id,
        "dni": c.dni,
        "name": c.name,
        "surname": c.surname,
        "alias": c.alias,
        "mobile_number": c.mobileNumber,
        "picture_path": c.picturePath,
        "balance": c.balance,
        "is_active": c.is_active,
      }).toList(),

      "colectivos": unsyncedColectivos.map((c)=>{
        "id": c.id,
        "plate": c.plate,
        "vtv": c.vtv.toUtc().toIso8601String(),
        "name": c.name,
        "data": c.data,
        "number": c.number,
        "capacity": c.capacity,
        "fuel_amount": c.fuelAmount,
        "fuel_date": c.fuelDate.toUtc().toIso8601String(),
        "oil_date": c.oilDate.toUtc().toIso8601String(),
        "is_active": c.is_active,
      }).toList(),

      "recorridos": unsyncedRecorridos.map((r)=>{
        "id": r.id,
        "name": r.name,
        "base_price": r.basePrice,
        "is_active": r.isActive,
      }).toList(),

      "passengers":unsyncedPassengers.map((p)=>{
        "id":p.id,
        "name":p.name,
        "manager_name":p.managerName,
        "manager_phone":p.managerPhone,
        "custom_price":p.customPrice,
        "recorrido_id":p.recorridoId,
        "is_active":p.isActive,
      }).toList(),
      
      "debts":unsyncedDebts.map((d)=>{
        "id":d.id,
        "passenger_id":d.passengerId,
        "chofer_id":d.choferId,
        "event_id":d.eventId,
        "date":d.date.toUtc().toIso8601String(),
        "description":d.description,
        "total_amount":d.totalAmount,
        "paid_amount":d.paidAmount,
        "is_settled":d.isSettled,
      }).toList(),

      "events": unsyncedEvents.map((e)=>{
        "id": e.id,
        "name": e.name,
        "data":e.data,
        "bus_amount":e.busAmount,
        "contact_name": e.contactName,
        "contact": e.contact,
        "repeat": e.repeat,
        "days": const WeekDaysConverter().toSql(e.days??[]), 
        "start_date_time": e.startDateTime.toUtc().toIso8601String(),
        "end_date_time": e.endDateTime.toUtc().toIso8601String(),
        "stop_repeating_date_time": e.stopRepeatingDateTime?.toUtc().toIso8601String(),
        "state": e.state.index,
        "type": e.type.index,
        "is_trip": e.isTrip,
        "shift_id": e.shiftId,
        "recorrido_id": e.recorridoId,
      }).toList(),

      "stops": eventStops.map((s)=>{
        "id": s.id,
        "name": s.name,
        "start": s.start?.toUtc().toIso8601String(),
        "event_id": s.eventId,
        "order_index": s.orderIndex,
      }).toList(),

      "event_choferes": eventChoferesList.map((ec)=>{
        "event_id": ec.eventId,
        "chofer_id": ec.choferId,
      }).toList(),

      "event_colectivos": eventColectivosList.map((ec)=>{
        "event_id": ec.eventId,
        "colectivo_id": ec.colectivoId,
      }).toList(),
    };
  }

  Future<void> processFullSync(Map<String, dynamic> json) async {
    await customStatement('PRAGMA defer_foreign_keys = ON;');

    await transaction(() async {
      // CHOFERES
      final choferesList = json['choferes'] as List<dynamic>? ?? [];
      for(var c in choferesList){
        await into(choferes).insertOnConflictUpdate(
          ChoferesCompanion(
            id: drift.Value(c['id']),
            dni: drift.Value(c['dni']),
            name: drift.Value(c['name']),
            surname: drift.Value(c['surname']),
            alias: drift.Value(c['alias']),
            mobileNumber: drift.Value(c['mobile_number']),
            picturePath: drift.Value(c['picture_path']),
            balance: drift.Value((c['balance'] as num?)?.toDouble() ?? 0.0),
            is_active: drift.Value(c['is_active'] ?? true),
            isSynced: const drift.Value(true),
          ),
        );
      }

      // COLECTIVOS
      final colectivosList = json['colectivos'] as List<dynamic>? ?? [];
      for(var c in colectivosList) {
        await into(colectivos).insertOnConflictUpdate(
          ColectivosCompanion(
            id: drift.Value(c['id']),
            plate: drift.Value(c['plate']),
            vtv: drift.Value(DateTime.parse(c['vtv']).toLocal()),
            name: drift.Value(c['name']),
            number: drift.Value(c['number']),
            data: drift.Value(c['data']),
            capacity: drift.Value(c['capacity'] ?? 0),
            fuelAmount: drift.Value(c['fuel_amount'] ?? ''),
            fuelDate: drift.Value(DateTime.parse(c['fuel_date']).toLocal()),
            oilDate: drift.Value(DateTime.parse(c['oil_date']).toLocal()),
            is_active: drift.Value(c['is_active'] ?? true),
            isSynced: const drift.Value(true),
          ),
        );
      }

      // RECORRIDOS
      final recorridosList = json['recorridos'] as List<dynamic>? ?? [];
      for(var r in recorridosList) {
        await into(recorridos).insertOnConflictUpdate(
          RecorridosCompanion(
            id: drift.Value(r['id']),
            name: drift.Value(r['name']),
            basePrice: drift.Value(r['base_price'] ?? 0),
            isActive: drift.Value(r['is_active'] ?? true),
            isSynced: const drift.Value(true),
          ),
        );
      }

      // DEPENDENCIAS
      
      // PASSENGERS
      final passengersList=json['passengers'] as List<dynamic>? ?? [];
      for(var p in passengersList){
        await into(passengers).insertOnConflictUpdate(
          PassengersCompanion(
            id:drift.Value(p['id']),
            name:drift.Value(p['name']),
            managerName:drift.Value(p['manager_name']),
            managerPhone:drift.Value(p['manager_phone']),
            customPrice:drift.Value(p['custom_price']??0),
            recorridoId:drift.Value(p['recorrido_id']),
            isActive:drift.Value(p['is_active']??true),
            isSynced:const drift.Value(true),
          ),
        );
      }

      // EVENTS
      final eventsList = json['events'] as List<dynamic>? ?? [];
      final List<String> updatedEventIds = [];

      for (var e in eventsList) {
        updatedEventIds.add(e['id']);
        await into(events).insertOnConflictUpdate(
          EventsCompanion(
            id: drift.Value(e['id']),
            name: drift.Value(e['name']),
            data: drift.Value(e['data']),
            busAmount: drift.Value(e['bus_amount']??0),
            contactName: drift.Value(e['contact_name'] as String?),
            contact: drift.Value(e['contact'] as String?),
            repeat: drift.Value(e['repeat'] ?? false),
            days: drift.Value(e['days']!=null&&e['days'].toString().isNotEmpty 
              ? const WeekDaysConverter().fromSql(e['days'] as String) 
              : null
            ),
            startDateTime: drift.Value(DateTime.parse(e['start_date_time']).toLocal()),
            endDateTime: drift.Value(DateTime.parse(e['end_date_time']).toLocal()),
            stopRepeatingDateTime: drift.Value(e['stop_repeating_date_time'] != null 
              ? DateTime.parse(e['stop_repeating_date_time']).toLocal()
              : null),
            state: drift.Value(EventStates.values[(e['state'] as num).toInt()]), 
            type: drift.Value(EventTypes.values[(e['type'] as num).toInt()]),    
            isTrip: drift.Value(e['is_trip'] ?? false),
            shiftId: drift.Value(e['shift_id']),
            recorridoId: drift.Value(e['recorrido_id']),
            isSynced: const drift.Value(true),
          ),
        );
      }

      //HIJOS FINALES
      
      // DEBTS
      final debtsList=json['debts'] as List<dynamic>? ?? [];
      for(var d in debtsList){
        await into(debts).insertOnConflictUpdate(
          DebtsCompanion(
            id:drift.Value(d['id']),
            passengerId:drift.Value(d['passenger_id']),
            choferId:drift.Value(d['chofer_id']),
            eventId:drift.Value(d['event_id']),
            date:drift.Value(DateTime.parse(d['date']).toLocal()),
            description:drift.Value(d['description']??""),
            totalAmount:drift.Value(d['total_amount']),
            paidAmount:drift.Value(d['paid_amount']??0),
            isSettled:drift.Value(d['is_settled']??false),
            isSynced:const drift.Value(true),
          ),
        );
      }

      // SUBTABLAS DE EVENTOS
      if (updatedEventIds.isNotEmpty) {
        await (delete(stops)..where((t) => t.eventId.isIn(updatedEventIds))).go();
        await (delete(eventChoferes)..where((t) => t.eventId.isIn(updatedEventIds))).go();
        await (delete(eventColectivos)..where((t) => t.eventId.isIn(updatedEventIds))).go();

        final stopsList = json['stops'] as List<dynamic>? ?? [];
        for (var s in stopsList) {
          await into(stops).insertOnConflictUpdate(
            StopsCompanion(
              id: drift.Value(s['id']),
              name: drift.Value(s['name']),
              start: drift.Value(s['start'] != null ? DateTime.parse(s['start']).toLocal():null),
              eventId: drift.Value(s['event_id']),
              orderIndex: drift.Value(s['order_index']),
            ),
          );
        }

        final eventChoferesList = json['event_choferes'] as List<dynamic>? ?? [];
        for (var ec in eventChoferesList) {
          await into(eventChoferes).insertOnConflictUpdate(
            EventChoferesCompanion(
              eventId: drift.Value(ec['event_id']),
              choferId: drift.Value(ec['chofer_id']),
            ),
          );
        }

        final eventColectivosList = json['event_colectivos'] as List<dynamic>? ?? [];
        for (var ec in eventColectivosList) {
          await into(eventColectivos).insertOnConflictUpdate(
            EventColectivosCompanion(
              eventId: drift.Value(ec['event_id']),
              colectivoId: drift.Value(ec['colectivo_id']),
            ),
          );
        }
      }
    });
  }



  Stream<ColectivoWithEvents> watchColectivoWithEventsStops({required String colId,DateTime? after,bool school=false}){
    after??=DateTime.now();

    final query=select(colectivos).join([
      leftOuterJoin(eventColectivos,eventColectivos.colectivoId.equalsExp(colectivos.id)),
      
      leftOuterJoin(
        events,
        events.id.equalsExp(eventColectivos.eventId)&
        events.endDateTime.isBiggerThanValue(after)&
        (school?events.type.equalsValue(EventTypes.SCHOOL):events.type.equalsValue(EventTypes.SCHOOL).not())
      ),
      leftOuterJoin(stops,stops.eventId.equalsExp(events.id)),
    ]);

    query.where(colectivos.id.equals(colId));
    query.orderBy([
      OrderingTerm.asc(events.startDateTime),
      OrderingTerm.asc(stops.orderIndex),
    ]);

    return query.watch().map((rows){
      if(rows.isEmpty)throw Exception('Colectivo no encontrado');
      
      final groupedEvents=<String,EventWithStops>{};

      for(final row in rows){
        final eve=row.readTableOrNull(events);
        final stop=row.readTableOrNull(stops);

        if(eve!=null){
          final item=groupedEvents.putIfAbsent(
            eve.id,
            ()=>EventWithStops(event:eve,stops:[]),
          );
          if(stop!=null)item.stops.add(stop);
        }
      }

      return ColectivoWithEvents(col:rows.first.readTable(colectivos),eves:groupedEvents.values.toList());
    });
  }


  Stream<List<ChoferesWithDebts>> watchChoferesWithDebts(){
    final query=select(choferes).join([
      leftOuterJoin(debts,debts.choferId.equalsExp(choferes.id)),
    ]);
    query.orderBy([
      OrderingTerm.asc(debts.isSettled),
      OrderingTerm.desc(debts.date)
    ]);

    return query.watch().map((rows){
      final groupedData=<String,ChoferesWithDebts>{};

      for(final row in rows){
        final choferess=row.readTable(choferes);
        final debt=row.readTableOrNull(debts);

        final item=groupedData.putIfAbsent(
          choferess.id, 
          ()=>ChoferesWithDebts(chofer:choferess,debts:[])
        );

        if(debt!=null)item.debts.add(debt);
      }
      final resultList=groupedData.values.toList();

      resultList.sort((a,b){
        final unpaidA=a.debts.where((d)=>!d.isSettled).length;
        final unpaidB=b.debts.where((d)=>!d.isSettled).length;

        if(unpaidA!=unpaidB)return unpaidB.compareTo(unpaidA); 
        return (a.chofer.alias??a.chofer.name??a.chofer.surname)!.toLowerCase().compareTo(
               (b.chofer.alias??b.chofer.name??b.chofer.surname)!.toLowerCase()
        );
      });

      return resultList;
    });
  }

  Stream<List<PassengerWithDebts>> watchPassengersWithDebts(String recorridoId){
    final query=select(passengers).join([
      leftOuterJoin(debts,debts.passengerId.equalsExp(passengers.id)),
    ]);

    query.where(passengers.recorridoId.equals(recorridoId));

    query.orderBy([
      OrderingTerm.asc(debts.isSettled),
      OrderingTerm.desc(debts.date)
    ]);

    return query.watch().map((rows){
      final groupedData=<String,PassengerWithDebts>{};

      for(final row in rows){
        final passenger=row.readTable(passengers);
        final debt=row.readTableOrNull(debts);

        final item=groupedData.putIfAbsent(
          passenger.id, 
          ()=>PassengerWithDebts(passenger:passenger,debts:[])
        );

        if(debt!=null)item.debts.add(debt);
      }
      return groupedData.values.toList();
    });
  }

  Stream<EventWithDebts> watchEventWithDebts(String eventId){
    final query=select(events).join([
      leftOuterJoin(debts,debts.eventId.equalsExp(events.id)),
    ]);
    query.where(events.id.equals(eventId));
    return query.watch().map((rows){
      if(rows.isEmpty){
        throw Exception('Event not found');
      }
      final debtList=<Debt>[];
      for(final row in rows){
        final debt=row.readTableOrNull(debts);
        if(debt!=null)debtList.add(debt);
      }

      return EventWithDebts(event:rows.first.readTable(events),debts:debtList);
    });
  }


  Future<List<(Colectivo, bool)>> getColectivosWithAvailability(
    DateTime start, 
    DateTime end, 
    String? excludedEventId,
    {String? onlyForEventId}
  )async{
    final busyQuery=select(eventColectivos).join([
      innerJoin(events, events.id.equalsExp(eventColectivos.eventId))
    ]);
    busyQuery.where(
      events.startDateTime.isSmallerThanValue(end) &
      events.endDateTime.isBiggerThanValue(start) &
      (excludedEventId != null?events.id.equals(excludedEventId).not():const Constant(true))
    );
    final busyIds=await busyQuery
        .map((row)=>row.readTable(eventColectivos).colectivoId)
        .get();
    final busySet=busyIds.toSet();

    List<Colectivo> targetColectivos;

    if (onlyForEventId != null) {
      final query=select(colectivos).join([
        innerJoin(eventColectivos, eventColectivos.colectivoId.equalsExp(colectivos.id))
      ]);
      query.where(eventColectivos.eventId.equals(onlyForEventId));
      targetColectivos=await query.map((row)=>row.readTable(colectivos)).get();
    } else {
      targetColectivos=await (select(colectivos)
        ..where((u)=>u.is_active.equals(true))
        ..orderBy([(t)=>OrderingTerm(expression: ((t.name.toString()).isEmpty)?t.plate:t.name)])
      ).get();
    }

    final List<(Colectivo, bool)> result=targetColectivos.map((c) {
      return (c, busySet.contains(c.id));
    }).toList();

    result.sort((a, b) {
      if (a.$2 == b.$2) return 0;
      return a.$2?1:-1;
    });
    
    return result;
  }
  Stream<List<(Colectivo, bool)>> watchColectivosAvailability(
    DateTime start, 
    DateTime end, 
    String? excludedEventId,
    {String? onlyForEventId}) {
    final triggerQuery=select(eventColectivos).join([
      innerJoin(events, events.id.equalsExp(eventColectivos.eventId)),
      innerJoin(colectivos, colectivos.id.equalsExp(eventColectivos.colectivoId))
    ]);
    return triggerQuery.watch().asyncMap((_) async {
      return await getColectivosWithAvailability(
        start,end,excludedEventId,onlyForEventId:onlyForEventId
      );
    });
  }

  Future<List<(Chofere, bool)>> getChoferesWithAvailability(
    DateTime start, DateTime end, String? excludedEventId,{String? onlyForEventId}) async {
  
    final busyQuery=select(eventChoferes).join([
      innerJoin(events, events.id.equalsExp(eventChoferes.eventId))
    ]);
    busyQuery.where(
      events.startDateTime.isSmallerThanValue(end) &
      events.endDateTime.isBiggerThanValue(start) &
      (excludedEventId != null?events.id.equals(excludedEventId).not():const Constant(true))
    );
    final busyIds=await busyQuery
        .map((row)=>row.readTable(eventChoferes).choferId)
        .get();
    final busySet=busyIds.toSet();

    List<Chofere> targetChoferes;

    if (onlyForEventId != null) {
      final query=select(choferes).join([
        innerJoin(eventChoferes, eventChoferes.choferId.equalsExp(choferes.id))
      ]);
      query.where(eventChoferes.eventId.equals(onlyForEventId));
      targetChoferes=await query.map((row)=>row.readTable(choferes)).get();
    } else {
      targetChoferes=await (select(choferes)
        ..where((u)=>u.is_active.equals(true))
        ..orderBy([(t)=>OrderingTerm(expression: ((t.alias.toString()).isEmpty)?t.name:t.alias)])
      ).get();
    }

    final List<(Chofere, bool)> result=targetChoferes.map((c) {
      return (c, busySet.contains(c.id));
    }).toList();

    //sorting
    result.sort((a, b) {
      if (a.$2 == b.$2) return 0;
      return a.$2?1:-1;
    });
    return result;
  }
  Stream<List<(Chofere, bool)>> watchChoferesAvailability(
    DateTime start, 
    DateTime end, 
    String? excludedEventId, 
    {String? onlyForEventId}) {
    final triggerQuery=select(eventChoferes).join([
      innerJoin(events,events.id.equalsExp(eventChoferes.eventId)),
      innerJoin(choferes,choferes.id.equalsExp(eventChoferes.choferId))
    ]);
    return triggerQuery.watch().asyncMap((_)async{
      return await getChoferesWithAvailability(
        start,end,excludedEventId,onlyForEventId:onlyForEventId
      );
    });
  }

  Stream<List<EventWithStops>> watchEventsWithStops(DateTime day,ViewFilter filter){
    final startOfDay=DateTime(day.year, day.month, day.day);
    final endOfDay=startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final weekdayIndex=day.weekday.toString();

    final query=select(events).join([
      leftOuterJoin(stops, stops.eventId.equalsExp(events.id)),
    ]);

    Expression<bool> typeFilter=const Constant(true);
    if(filter==ViewFilter.school){
      typeFilter=events.type.equalsValue(EventTypes.SCHOOL);
    }else if(filter==ViewFilter.trips){
      typeFilter=events.type.equalsValue(EventTypes.SCHOOL).not();
    }

    query.where(
      typeFilter&
      events.state.equalsValue(EventStates.REMOVED).not()&(
        (events.repeat.equals(false)&events.startDateTime.isBetweenValues(startOfDay,endOfDay))|
        (events.repeat.equals(true)&events.startDateTime.isSmallerOrEqualValue(endOfDay)&events.days.cast<String>().like('%$weekdayIndex%'))
      )
    );

    query.orderBy([
      OrderingTerm.asc(events.startDateTime),
      OrderingTerm.asc(stops.orderIndex),
    ]);

    return query.watch().map((rows) {
      final groupedData=<String, EventWithStops>{};

      for(final row in rows) {
        final event=row.readTable(events);
        final stop=row.readTableOrNull(stops);

        final item=groupedData.putIfAbsent(
          event.id, 
          ()=>EventWithStops(event: event, stops: [])
        );

        if (stop != null) {
          item.stops.add(stop);
        }
      }

      return groupedData.values.toList();
    });
  }
  Stream<List<EventWithStops>> watchShiftsWithStops(String recoId){
    final query=select(events).join([
      leftOuterJoin(stops, stops.eventId.equalsExp(events.id)),
    ]);

    //filtering
    query.where(
      events.type.equalsValue(EventTypes.SHIFT) &
      events.recorridoId.equals(recoId) &
      events.state.equalsValue(EventStates.REMOVED).not()
    );

    //order
    query.orderBy([
      OrderingTerm.asc(events.startDateTime),
      OrderingTerm.asc(stops.orderIndex),
    ]);

    return query.watch().map((rows) {
      final groupedData=<String, EventWithStops>{};

      for(final row in rows){
        final event=row.readTable(events);
        final stop=row.readTableOrNull(stops);

        final item=groupedData.putIfAbsent(
          event.id, 
          ()=>EventWithStops(event:event,stops:[])
        );

        if(stop!=null){item.stops.add(stop);}
      }

      return groupedData.values.toList();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    //looks for the place to put the files
    final dbFolder=await getApplicationDocumentsDirectory();
    final file=File(p.join(dbFolder.path, 'mi_base_de_datos.sqlite'));
    
    //starts the database
    return NativeDatabase.createInBackground(file);
  });
}
