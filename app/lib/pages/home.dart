import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:agenda/widgets/buttons.dart';
import 'package:agenda/widgets/cards.dart';
import 'package:agenda/widgets/text.dart';
import 'package:agenda/widgets/errorWidgets.dart';
import 'package:agenda/widgets/weather.dart';

import 'package:agenda/utilities/settings.dart';
import 'package:agenda/utilities/events.dart';
import 'package:agenda/utilities/colectivos.dart';
import 'package:agenda/utilities/choferes.dart';
import 'package:agenda/utilities/recorridos.dart';


import 'package:provider/provider.dart';
import 'package:agenda/database/app_database.dart';
import 'setting.dart';

class homePage extends StatefulWidget {
  final void Function(int index,int dato)? onVtvCheck;
  const homePage({super.key,this.onVtvCheck});
  static const Color mainColor=Colors.blueGrey;

  @override
  State<homePage> createState() => _homePageState();
}
class _homePageState extends State<homePage>{
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();
  ViewFilter eventsFilter=ViewFilter.all;
  bool _showSettings=false;


  @override
  Widget build(BuildContext context){
    //final settings=context.watch<SettingsProvider>();
    DateTime today=DateTime.now();

    final deafDb=Provider.of<AppDatabase>(context, listen: false);
    return Scaffold(
      body:Stack(
        children:[
          SafeArea(top:false,child:ListView(padding:EdgeInsets.zero,children:[
            //TOP CARD
            BasicCard(
              padding: const EdgeInsets.symmetric(vertical:24),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const SizedBox(height:10),
                Row(children:[
                  const SizedBox(width:15),
                  Expanded(child:Text(DateFormat('EEEE, d MMM').format(today))),
                  GestureDetector(
                    onHorizontalDragEnd:(details){
                      if(details.primaryVelocity!<0){
                        setState((){_showSettings=true;});
                      }else if(details.primaryVelocity!>0){
                        setState((){_showSettings=false;});
                      }
                    },
                    child:WeatherWidget(),
                  ),
                  AnimatedContainer(
                    duration:const Duration(milliseconds:200),
                    width:_showSettings?30.0:0.0,
                    child:_showSettings?IconButton(icon:Icon(Icons.settings),onPressed:(){
                      Navigator.of(context).push(MaterialPageRoute(builder:(context)=>PantallaAjustes()));
                    }):null,
                  ),
                  const SizedBox(width:5),
                ]),
                const SizedBox(height:10),
                SingleChildScrollView(scrollDirection:Axis.horizontal,child: StreamBuilder<(int,int)>(
                  stream:deafDb.watchVtvStatus(),
                  builder:(context,snapshot){
                    //return const SizedBox.shrink();
                    final (vencidas,porVencer)=snapshot.data??(0,0);
                    if (vencidas+porVencer==0)return const SizedBox.shrink();
                    return Row(children:[
                      const SizedBox(width:10),
                      if(vencidas>0)
                      pillText("$vencidas VTV${vencidas>1?"s venceiron":"vencida"}",Colors.red,onTap:(){
                        if(widget.onVtvCheck!=null)widget.onVtvCheck!(4,1);
                      }),
                      if(porVencer>0&&vencidas>0)
                      const SizedBox(width:10),
                      if(porVencer>0)
                      pillText("$porVencer VTV${porVencer>1?"s":""} próxima${porVencer>1?"s":""} a vencer",
                        Colors.orange,onTap:(){
                          if(widget.onVtvCheck!=null)widget.onVtvCheck!(4,1);
                        }),
                      const SizedBox(width:10),
                    ]);
                  }
                )),
              ])
            ),
            const SizedBox(height:20),
            subtitleLine("Viajes hoy",homePage.mainColor),
            EventFilter(
              currentFilter:eventsFilter,
              mainColor:homePage.mainColor,
              onChanged:(ViewFilter newFilter){
                setState((){eventsFilter=newFilter;});
              },
            ),
            StreamBuilder<List<EventWithStops>>(
              stream:deafDb.watchEventsWithStops(DateTime.now(),eventsFilter),
              builder:(context,snapshot){
                if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
                if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());
                final fullList=snapshot.data??[];
                if(fullList.isEmpty)return const Center(child:Text("Nada por aca"));
                return BasicCard(
                  padding:EdgeInsetsGeometry.symmetric(vertical:8,horizontal:0),
                  child:Column(children:[
                    ...fullList.map((e){
                      return EventCard(
                        eve:e.event,sto:e.stops,
                        maincolor:homePage.mainColor,
                      );
                    })
                  ])
                );
              },
            ),
          ])),
          Positioned.fill(
            bottom:16.0,
            right:16.0,
            child:ExpandableFab(
            key:_fabKey,
              mainColor:homePage.mainColor,
              children:[
                buildMiniFab(homePage.mainColor,
                  icon: Icons.school,
                  label: "Recorrido",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    final newRecorrido=await showCreateRecorridoSheet(context,homePage.mainColor);
                    if(newRecorrido==null)return;
                    await deafDb.into(deafDb.recorridos).insertOnConflictUpdate(newRecorrido);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor:Colors.green,content:Text("Recorrido guardado")),
                    );
                  },
                ),
                buildMiniFab(homePage.mainColor,
                  icon: Icons.schedule,
                  label: "Viaje",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    final success=await showCreateTripSheet(
                      context,mainColor:homePage.mainColor,isTrip:true,startDate:DateTime.now()
                    );

                    if(success&&context.mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content:Text("Viaje guardado"),backgroundColor:Colors.green,)
                      );
                    }
                  },
                ),
                buildMiniFab(homePage.mainColor,
                  icon: Icons.directions_bus,
                  label: "Colectivo",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    if((await showCreateModifiColectivo(context,mainColor:homePage.mainColor))&&context.mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content:Text("Colectivo guardado"),backgroundColor:Colors.green),
                      );
                    }
                  },
                ),
                buildMiniFab(homePage.mainColor,
                  icon: Icons.person,
                  label: "Chofer",
                  onPressed:()async{
                    _fabKey.currentState?.toggleMenu();
                    if((await showCreateModifiChofer(context,homePage.mainColor))&&context.mounted){
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Chofer guardado"), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),
              ]
            )
          )
        ],
      )
    );
  }
}
