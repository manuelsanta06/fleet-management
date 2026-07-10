import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agenda/database/app_database.dart';

import 'package:agenda/pages/recorridoInfo.dart';

import 'package:agenda/utilities/recorridos.dart';

import 'package:agenda/widgets/responsiveWrap.dart';
import 'package:agenda/widgets/errorWidgets.dart';
import 'package:agenda/widgets/searchBar.dart';


class recorridosPage extends StatefulWidget {
  const recorridosPage({super.key});
  static const Color mainColor=Colors.green;

  @override
  State<recorridosPage> createState() => _recorridosPage();
}
class _recorridosPage extends State<recorridosPage>{
  String searchQuery = "";


  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final deafDb=Provider.of<AppDatabase>(context, listen: false);

    return Scaffold(
      body:SafeArea(child:Column(children:[
        mySearchBar(onChanged:(value){setState((){searchQuery = value;});}),
        Expanded(child:StreamBuilder<List<Recorrido>>(
          stream: db.select(db.recorridos).watch(),
          builder:(context, snapshot){
            if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
            if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());
            var recorridos=snapshot.data!;
            if(searchQuery.isNotEmpty){
              recorridos=recorridos.where((r)=> 
                r.name.toLowerCase().contains(searchQuery.toLowerCase())
              ).toList();
            }
            recorridos.sort((a,b){
              if(a.pinned&&!b.pinned)return -1;
              if(!a.pinned && b.pinned)return 1;
              return a.name.compareTo(b.name);
            });

            final activos=recorridos.where((r)=>r.isActive).toList();
            final inactivos=recorridos.where((r)=>!r.isActive).toList();

            return ListView(
              padding:const EdgeInsets.only(bottom:80),
              children:[
                ResponsiveWrap(
                  minItemWidth:350.0,
                  children:activos.map((s)=>recorridoToCard(context,recorridosPage.mainColor,s,(){
                    Navigator.of(context).push(MaterialPageRoute(
                      builder:(Context)=>recorridoInfo(reco:s,maincolor:recorridosPage.mainColor)
                    ));
                  })).toList(),
                ),

                if(inactivos.isNotEmpty)...[
                  const SizedBox(height: 30),
                  const Center(child: Text("Inactivos / Finalizados",
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  )),
                  const SizedBox(height: 15),
                  
                  ResponsiveWrap(
                    minItemWidth: 350.0,
                    children:inactivos.map((s)=>recorridoToCard(context,recorridosPage.mainColor,s,(){
                    })).toList(),
                  ),
                ],
              ]
            );
          }
        )),
      ])),
      floatingActionButton:FloatingActionButton(
        onPressed:()async{
          final newRecorrido=await showCreateRecorridoSheet(context,recorridosPage.mainColor);
          if(newRecorrido==null)return;
          await deafDb.into(deafDb.recorridos).insertOnConflictUpdate(newRecorrido);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor:Colors.green,content: Text("Recorrido '${newRecorrido.name.value}' creado")),
          );
        },
        //()=>generateMockRecorridos(deafDb),
        backgroundColor: recorridosPage.mainColor,
        child:Icon(Icons.add),
      )
    );
  }
}
