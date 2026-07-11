import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agenda/database/app_database.dart';

import 'package:agenda/utilities/choferes.dart';

import 'package:agenda/widgets/responsiveWrap.dart';
import 'package:agenda/widgets/searchBar.dart';
import 'package:agenda/widgets/errorWidgets.dart';

typedef Chofer=Chofere;


class peoplePage extends StatefulWidget {
  const peoplePage({super.key});
  static const Color mainColor=Colors.purple;

  @override
  State<peoplePage> createState() => _peoplePageState();
}

class _peoplePageState extends State<peoplePage>{
  String searchQuery = "";
  bool showInactives=false;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      body:SafeArea(child: Column(
        children: [
          mySearchBar(onChanged:(value){setState((){searchQuery = value;});}),

          Container(
            margin:const EdgeInsets.symmetric(horizontal: 10),
            child:Row(children: [
              Expanded(child: Text(
                "Mostrar inactivos",
                style:TextStyle(fontSize:16, fontWeight:showInactives?FontWeight.bold:FontWeight.normal),
              )),
              Switch(
                value: showInactives,
                activeThumbColor: Colors.white,
                activeTrackColor:peoplePage.mainColor,
                onChanged:(bool value){
                  setState((){showInactives=value;});
                }
              )
            ])
          ),

          Expanded(
            child: StreamBuilder<List<ChoferesWithDebts>>(
              stream: db.watchChoferesWithDebts(), 
              builder:(context, snapshot){
                if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
                if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());

                final listaChoferes=snapshot.data!.where((tbl)=>
                  showInactives?!tbl.chofer.is_active:tbl.chofer.is_active)
                .toList();

                // Aplicar filtro de búsqueda
                final filtered = searchQuery.isEmpty
                  ? listaChoferes
                  : listaChoferes.where((c){
                    return (c.chofer.name?.toLowerCase().contains(searchQuery.toLowerCase())??false) ||
                      (c.chofer.dni?.toLowerCase().contains(searchQuery.toLowerCase())??false) ||
                      (c.chofer.surname?.toLowerCase().contains(searchQuery.toLowerCase())??false) ||
                      (c.chofer.mobileNumber?.toString().contains(searchQuery)??false);
                  }).toList();
                if(filtered.isEmpty)return const Center(child:Text("???"));

                return SingleChildScrollView(
                  padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),
                  child:ResponsiveWrap(minItemWidth:350.0,children:filtered.map((item){
                    return choferToCard(
                      context,item.chofer,peoplePage.mainColor,
                      debts:item.debts,
                      onPressed:()=>{},
                      onLongPress:(item.chofer.is_active)?
                        ()=>removeChoferDialog(context,item.chofer,false):
                        ()=>removeChoferDialog(context,item.chofer,true)
                    );
                  }).toList()),
                );
              },
            ),
          ),
        ],
      ),),
      floatingActionButton: FloatingActionButton(
        onPressed:() async {
          final success = await showCreateModifiChofer(context,peoplePage.mainColor);
          if(success&&context.mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Chofer actualizado"), backgroundColor: Colors.green),
            );
          }
        },
        backgroundColor: peoplePage.mainColor,
        child:Icon(Icons.add),
      ),
    );
  }
}
