import 'package:flutter/material.dart';
import 'package:agenda/database/app_database.dart';
import 'package:agenda/constants.dart' as constants;
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:agenda/widgets/searchBar.dart';
import 'package:agenda/widgets/buttons.dart';
import 'package:agenda/widgets/responsiveWrap.dart';
import 'package:agenda/widgets/errorWidgets.dart';

import 'package:agenda/utilities/events.dart';



class calendarPage extends StatefulWidget {
  const calendarPage({super.key});
  static const Color mainColor=Colors.cyan;

  void errorSnackBar(BuildContext context){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:Text('Algo salio mal. Viaje borrado'),
        duration: Duration(seconds: 5),
        backgroundColor:Colors.red,
      ),
    );
  }

  @override
  State<calendarPage> createState() => _calendarPageState();
}


class _calendarPageState extends State<calendarPage>{
  String searchQuery="";
  ViewFilter eventsFilter=ViewFilter.all;

  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();
  DateTime _focusedDay = DateTime.now(), _selectedDay=DateTime.now();
  CalendarFormat _calendarFormat=CalendarFormat.week;

  @override
  void initState(){
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final db=Provider.of<AppDatabase>(context);
    final deafDb=Provider.of<AppDatabase>(context,listen:false);

    return Scaffold(
      body:Stack(
        fit:StackFit.expand,
        children:[
          // main page
          SafeArea(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            mySearchBar(onChanged:(value){setState((){searchQuery=value;});}),
            EventFilter(
              currentFilter:eventsFilter,
              mainColor:calendarPage.mainColor,
              onChanged:(ViewFilter newFilter){
                setState((){eventsFilter=newFilter;});
              },
            ),
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: constants.firstDate,
              lastDay: constants.lastDay,
              locale: 'es_ES',
              daysOfWeekHeight: 20,
              availableCalendarFormats:{CalendarFormat.month:'Month',CalendarFormat.week:'Week'},
              
              //styling
              calendarFormat: _calendarFormat,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false, 
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: calendarPage.mainColor, 
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: calendarPage.mainColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),

              //functionality
              onFormatChanged:(format){
                setState((){_calendarFormat=format;});
              },
              selectedDayPredicate:(day){
                return isSameDay(_selectedDay,day);
              },

              onDaySelected: (selectedDay, focusedDay) {
                setState((){
                  _selectedDay=selectedDay;
                  _focusedDay=focusedDay;
                });
                // filtrar lista de viajes aca?
                // _cargarViajesDelDia(selectedDay);
              },

              onPageChanged:(focusedDay){_focusedDay=focusedDay;},
            ),

            const SizedBox(height: 8.0),

            Expanded(child:StreamBuilder<List<EventWithStops>>(
              stream: db.watchEventsWithStops(_selectedDay,eventsFilter),
              builder:(context,snapshot){
                if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
                if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());
                final fullList=snapshot.data??List<EventWithStops>.empty();
                final filtered=searchQuery.isEmpty
                  ?fullList
                  :fullList.where((c){
                    return (c.event.name.toLowerCase().contains(searchQuery.toLowerCase()));
                  }).toList();
                if(filtered.isEmpty)return const Center(child:Text("Nada por aca"));

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom:80),
                  child:ResponsiveWrap(spacing:0,runSpacing:0,minItemWidth:350.0,children:filtered.map((item){
                    return EventCard(
                      eve:item.event,
                      sto:item.stops,
                      maincolor:calendarPage.mainColor,
                    );
                  }).toList()),
                );

              },
            )),
          ])),

          // Floatting buttons
          Positioned.fill(
            bottom:16.0,
            right:16.0,
            child:ExpandableFab(
              key:_fabKey,
              mainColor: calendarPage.mainColor,
              children: [
                buildMiniFab(calendarPage.mainColor,
                  icon: Icons.directions_bus,
                  label: "Viaje",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    final success=await showCreateTripSheet(
                      context,mainColor:calendarPage.mainColor,isTrip:true,startDate:_selectedDay
                    );

                    if(success&&context.mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:Text("Viaje guardado correctamente"),
                          backgroundColor:Colors.green,
                        ),
                      );
                    }
                  },
                ),
                buildMiniFab(calendarPage.mainColor,
                  icon: Icons.task_alt,
                  label: "Recordatorio",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    final success=await showCreateTripSheet(
                      context,mainColor:calendarPage.mainColor,isTrip:false,startDate:_selectedDay
                    );

                    if(success&&context.mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:Text("Viaje guardado correctamente"),
                          backgroundColor:Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
