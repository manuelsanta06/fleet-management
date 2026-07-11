import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:agenda/pages/recorridos.dart';

import 'package:agenda/database/app_database.dart';

import 'package:agenda/widgets/responsiveWrap.dart';
import 'package:agenda/widgets/errorWidgets.dart';
import 'package:agenda/widgets/searchBar.dart';
import 'package:agenda/widgets/cards.dart';
import 'package:agenda/widgets/text.dart';

import 'package:agenda/utilities/passegers.dart';
import 'package:agenda/utilities/parsers.dart';
import 'package:agenda/utilities/events.dart';
import 'package:agenda/utilities/debts.dart';


class recorridoInfo extends StatefulWidget{
  final Recorrido reco;
  final Color maincolor;
  
  const recorridoInfo({
    super.key,
    required this.reco,
    required this.maincolor,
  });

  @override
  State<recorridoInfo> createState()=>_recorridoInfoState();
}


class _recorridoInfoState extends State<recorridoInfo>{
  String searchQuery="";

  void snack(BuildContext context,bool succes){
    if(succes){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor:Colors.green,duration:Duration(seconds:2),content: Text('Agregado')),
      );
    }else{
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor:Colors.red,duration:Duration(seconds:2),content: Text('Cancelado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child:DefaultTabController(
      length:3,
      initialIndex:1,
      child:Scaffold(
        appBar:AppBar(
          backgroundColor:Theme.of(context).cardColor,
          elevation:0,
          leading:const BackButton(),
          
          //TITULO
          title:Row(
            children:[
              Expanded(
                child:Text(
                  widget.reco.name,
                  style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18),
                  overflow:TextOverflow.ellipsis,
                ),
              ),
              pillText("\$${numberParser(widget.reco.basePrice)}",widget.maincolor),
            ],
          ),

          //BOTONES
          bottom: TabBar(
            labelColor:widget.maincolor,
            unselectedLabelColor: Colors.grey,
            indicatorColor:widget.maincolor,
            indicatorWeight:3,
            tabs:const[
              Tab(text:"Horarios", icon:Icon(Icons.access_time),),
              Tab(text:"Info",     icon:Icon(Icons.info_outline),),
              Tab(text:"Pasajeros",icon:Icon(Icons.groups),),
            ],
          ),
        ),

        //las paginas
        body: TabBarView(
          children: [
            _buildHorariosTab(context),
            _buildInfoTab(context),
            _buildPasajerosTab(context),
          ],
        ),
      ),
    ));
  }


  Widget _buildHorariosTab(BuildContext context){
    final db = Provider.of<AppDatabase>(context);
    return StreamBuilder<List<EventWithStops>>(
      stream:db.watchShiftsWithStops(widget.reco.id),
      builder:(context,snapshot){
        if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
        if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());
        final shifts=snapshot.data!;
        //if(shifts.isEmpty)return const Center(child:Text("..."));
        return ListView(
          padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),
          children:[
            ResponsiveWrap(
              minItemWidth:350.0,
              children:shifts.map((s)=>EventCard(eve:s.event,sto:s.stops,maincolor:widget.maincolor)).toList()
            ),
            SizedBox(height:20),
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:const BorderSide(color:Color(0xFF94A3B8),width:2,),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:()async=>snack(context,(await showCreateTripSheet(context,
                  mainColor:widget.maincolor,
                  isTrip:false,
                  isShift:true,
                  recoId:widget.reco.id,
                  startDate: DateTime(2000,1,1),
                ))),
                child: Container(
                  width:double.infinity,
                  padding:const EdgeInsets.symmetric(vertical:7,horizontal:5),
                  alignment:Alignment.center,
                  child:const Text( "Agregar",
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    final db=Provider.of<AppDatabase>(context, listen: false);

    return ListView(
      padding:const EdgeInsets.all(16),
      children:[

        subtitleLine("General",widget.maincolor),
        BasicCard(
          child:ListTile(
            title:const Text("Nombre"),
            subtitle:Text(widget.reco.name),
            trailing:Icon(Icons.edit, color: widget.maincolor),
          ),
          onPressed:()async{
            final newVal=await quickChangeDialog(context,'nombre',def:widget.reco.name);
            if(newVal==null)return;
            await (db.update(db.recorridos)
              ..where((t)=>t.id.equals(widget.reco.id)))
              .write(RecorridosCompanion(
                name:drift.Value(newVal),
                isSynced:drift.Value(false),
              ));
          },
        ),
        const SizedBox(height: 8),
        BasicCard(
          child:ListTile(
            title:const Text("Precio Base"),
            subtitle:Text("\$ ${numberParser(widget.reco.basePrice)}"),
            trailing:Icon(Icons.attach_money, color: widget.maincolor),
          ),
          onPressed: () async {
            final newVal=await quickChangeDialog(context,'precio',def:widget.reco.basePrice.toString());
            if(newVal == null) return;
            final parsed = int.tryParse(newVal);
            if(parsed==null) return;
            await (db.update(db.recorridos)
              ..where((t)=>t.id.equals(widget.reco.id)))
              .write(RecorridosCompanion(
                basePrice:drift.Value(parsed),
                isSynced:drift.Value(false),
              ));
          },
        ),
        const SizedBox(height:20),
        subtitleLine("Estado",widget.maincolor),
        BasicCard(
          child:SwitchListTile(
            title:const Text("Recorrido activo"),
            subtitle:Text(widget.reco.isActive ? "Visible y operativo" : "Oculto / pausado"),
            value:widget.reco.isActive,
            activeThumbColor:widget.maincolor,
            onChanged:(val)async{
              await (db.update(db.recorridos)
                ..where((t)=>t.id.equals(widget.reco.id)))
                .write(RecorridosCompanion(
                  isActive:drift.Value(val),
                  isSynced:drift.Value(false),
                ));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasajerosTab(BuildContext context){
    final db=Provider.of<AppDatabase>(context);
    return Scaffold(
      body:Column(children:[
        SizedBox(height:6),
        mySearchBar(onChanged:(value)=>setState((){searchQuery=value.toLowerCase();})),
        Expanded(child:StreamBuilder<List<PassengerWithDebts>>(
          stream:db.watchPassengersWithDebts(widget.reco.id),
          builder:(context,snapshot){
            if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
            if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());
            final List<PassengerWithDebts> allData=snapshot.data!;
            final filtered=allData.where((s){
              return s.passenger.name.toLowerCase().contains(searchQuery)||
                (s.passenger.managerPhone.toLowerCase().contains(searchQuery))||
                (s.passenger.managerName.toLowerCase().contains(searchQuery));
            }).toList();
            return ListView(
              padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),
              children:[
                if(filtered.isNotEmpty)
                ResponsiveWrap(
                  minItemWidth:350.0,
                  children:filtered.map((item){
                    return passengerToCard(
                      context,
                      recorridosPage.mainColor,
                      item.passenger,
                      widget.reco.id,
                      debts: item.debts,
                    );
                  }).toList(),
                ),
                SizedBox(height:20),
                Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:const BorderSide(color:Color(0xFF94A3B8),width:2,),
                  ),
                  child:InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:()async=>
                      snack(context,(await showCreateModifiPassenger(context,
                        widget.maincolor,
                        recoId:widget.reco.id,
                        nameDef:phoneParser(searchQuery).length<5?searchQuery:null,
                        phoneDef:phoneParser(searchQuery).length<5?null:phoneParser(searchQuery),
                      ))),
                    child: Container(
                      width:double.infinity,
                      padding:const EdgeInsets.symmetric(vertical:7,horizontal:5),
                      alignment:Alignment.center,
                      child:const Text( "Agregar",
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ))
      ]),
    );
  }
}
