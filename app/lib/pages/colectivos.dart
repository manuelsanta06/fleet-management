import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agenda/database/app_database.dart';

import 'package:agenda/utilities/colectivos.dart';
import 'package:agenda/utilities/settings.dart';

import 'package:agenda/widgets/responsiveWrap.dart';
import 'package:agenda/widgets/errorWidgets.dart';
import 'package:agenda/widgets/searchBar.dart';

import 'package:agenda/pages/colectivoInfo.dart';


class colectivosPage extends StatefulWidget{
  final int? ordering;
  const colectivosPage({super.key,this.ordering});
  static const Color mainColor=Color.fromARGB(255, 252, 102, 1);

  @override
  State<colectivosPage> createState()=> _colectivosPageState();
}

class _colectivosPageState extends State<colectivosPage>{
  String searchQuery="";
  bool showInactives=false;

  @override
  Widget build(BuildContext context){
    final settings=context.watch<SettingsProvider>();
    final int order=((widget.ordering??-1)==-1)?settings.getValue("colectivos_order"):widget.ordering!;
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      body:SafeArea(child:Column(
          children: [
            Row(children:[
              Expanded(child:mySearchBar(onChanged:(value){setState((){searchQuery=value;});})),
              PopupMenuButton(
                icon:const Icon(Icons.filter_list),
                onSelected:(String result)async{ switch (result){
                  case 'nombre':
                    settings.setValue("colectivos_order",2);
                    break;
                  case 'interno':
                    settings.setValue("colectivos_order",0);
                    break;
                  case 'vtv':
                    settings.setValue("colectivos_order",1);
                    break;
                  default:
                    return;
                }},
                itemBuilder:(BuildContext Context)=><PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value:'nombre',
                    child:Row(children:[
                      Icon(Icons.abc),
                      SizedBox(width:8),
                      Text('Nombre/Patente')
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value:'interno',
                    child:Row(children:[
                      Icon(Icons.numbers),
                      SizedBox(width:8),
                      Text('Interno')
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value:'vtv',
                    child:Row(children:[
                      Icon(Icons.shield), 
                      SizedBox(width: 8), 
                      Text('VTV'),
                    ]),
                  ),
                ]
              ),
            ]),

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
                  activeTrackColor:colectivosPage.mainColor,
                  onChanged:(bool value){
                    setState((){showInactives=value;});
                  }
                )
              ])
            ),

            Expanded(
              child: StreamBuilder<List<Colectivo>>(
                stream:(db.select(db.colectivos)..orderBy(
                    [(c)=>drift.OrderingTerm(expression:switch(order){
                      0=>c.number,
                      1=>c.vtv,
                      2=>((c.name.toString()).isEmpty)?c.plate:c.name,
                      _=>((c.name.toString()).isEmpty)?c.plate:c.name
                    })]
                )).watch(), 
                builder:(context, snapshot){
                  if(snapshot.hasError)return ManuErrorWidget(snapshot:snapshot);
                  if(!snapshot.hasData)return const Center(child: CircularProgressIndicator());

                  final listaColectivos=snapshot.data!.where((tbl)=>showInactives?!tbl.is_active:tbl.is_active).toList();

                  // Aplicar filtro de búsqueda
                  final filtered = searchQuery.isEmpty
                    ? listaColectivos
                    : listaColectivos.where((c){
                      return(c.name?.toLowerCase().contains(searchQuery.toLowerCase())??false) ||
                        c.plate.toLowerCase().contains(searchQuery.toLowerCase())||
                       (c.number?.toString().contains(searchQuery)?? false);
                        }).toList();
                  if(filtered.isEmpty)return const Center(child:Text("???"));

                  return SingleChildScrollView(
                    padding:const EdgeInsets.symmetric(horizontal:5,vertical:10),
                    child:ResponsiveWrap(minItemWidth:350.0,children:filtered.map((item){
                      return colectivoToCard(
                        context,item,colectivosPage.mainColor,
                        onPressed:()=>Navigator.of(context).push(
                           MaterialPageRoute(builder:(context)=>colectivoInfo(
                             initialCol:item,mainColor:colectivosPage.mainColor
                            ))
                         ),
                        onLongPress:null,
                      );
                    }).toList()),
                  );
                },
              ),
            ),
          ],
      ),),
      floatingActionButton: FloatingActionButton(
        onPressed:()async{
          final success=await showCreateModifiColectivo(context,mainColor:colectivosPage.mainColor);
          if(success&&context.mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text("Colectivo actualizado"),backgroundColor:Colors.green),
            );
          }
        },
        backgroundColor: colectivosPage.mainColor,
        child:Icon(Icons.add),
      ),
    );
  }
}
