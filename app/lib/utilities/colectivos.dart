import 'package:agenda/widgets/timeinputs.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agenda/database/app_database.dart';

import 'package:agenda/widgets/searchBar.dart';
import 'package:agenda/widgets/cards.dart';
import 'package:agenda/widgets/text.dart';

import 'package:agenda/utilities/syncService.dart';


Future<void> updateColectivo(BuildContext context,Colectivo bus)async{
  final db=Provider.of<AppDatabase>(context,listen:false);
  try{
    await db.update(db.colectivos).replace(
      bus.copyWith(isSynced:false)
    );
    SyncService.pushUnsyncedData(db);
  }catch(e){
    return;
  }
}


Future<bool> showCreateModifiColectivo(BuildContext context,{Colectivo? bus,required Color mainColor})async{
  final result=await showModalBottomSheet<ColectivosCompanion?>(
    context:context,
    isScrollControlled:true,
    builder:(BuildContext context)=>_CreateColectivoSheet(bus: bus,mainColor:mainColor),
  );
  if(result==null)return false;
  final db=Provider.of<AppDatabase>(context,listen:false);
  try{
    await db.into(db.colectivos).insertOnConflictUpdate(result);
    SyncService.pushUnsyncedData(db);
    return true;
  }catch(e){
    print("Error guardando colectivo en Drift: $e");
    return false;
  }
}

class _CreateColectivoSheet extends StatefulWidget {
  final Colectivo? bus;
  final Color mainColor;

  const _CreateColectivoSheet({
    Key? key,
    this.bus,
    required this.mainColor,
  }) : super(key: key);

  @override
  State<_CreateColectivoSheet> createState() => _CreateColectivoSheetState();
}

class _CreateColectivoSheetState extends State<_CreateColectivoSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController nameC;
  late final TextEditingController plateC;
  late final TextEditingController internC;
  late final TextEditingController capacityC;

  bool get _isEditing => widget.bus != null;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.bus?.name ?? "");
    plateC = TextEditingController(text: widget.bus?.plate ?? "");
    internC = TextEditingController(text: widget.bus?.number?.toString() ?? "");
    capacityC = TextEditingController(text: widget.bus?.capacity.toString() ?? "");
  }

  @override
  void dispose() {
    nameC.dispose();
    plateC.dispose();
    internC.dispose();
    capacityC.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final nuevo = ColectivosCompanion(
        id: drift.Value(widget.bus?.id ?? const Uuid().v4()),
        name: drift.Value(nameC.text.trim()),
        plate: drift.Value(plateC.text.trim().toUpperCase()),
        number: drift.Value(int.tryParse(internC.text.trim())),
        capacity: drift.Value(int.tryParse(capacityC.text.trim()) ?? 0),
        fuelAmount: drift.Value(widget.bus?.fuelAmount ?? "0"),
        fuelDate: drift.Value(widget.bus?.fuelDate ?? DateTime.now()),
        oilDate: drift.Value(widget.bus?.oilDate ?? DateTime.now()),
        isSynced: const drift.Value(false),
      );
      Navigator.pop(context, nuevo);
    }
  }

  InputDecoration _customDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: widget.mainColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.mainColor, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: widget.mainColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? "Editar Colectivo" : "Nuevo Colectivo",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Campo: Nombre
                TextFormField(
                  controller: nameC,
                  textCapitalization: TextCapitalization.words,
                  decoration: _customDecoration("Nombre (Opcional)", "", Icons.directions_bus_outlined),
                ),
                const SizedBox(height: 16),
                
                //Patente
                TextFormField(
                  controller: plateC,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _customDecoration("Patente", "Ej: AAA-000", Icons.pin_invoke_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La patente es obligatoria';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                //Interno y Capacidad
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: internC,
                        keyboardType: TextInputType.number,
                        decoration: _customDecoration("Interno", "Ej: 15", Icons.numbers),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: capacityC,
                        keyboardType: TextInputType.number,
                        decoration: _customDecoration("Capacidad", "Ej: 32", Icons.airline_seat_recline_normal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                //Guardar
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      "Guardar",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.mainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _save,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> editColectivoFuel(BuildContext context,Colectivo col)async{
  String? val=await quickChangeDialog(context,"Nivel de Gasoil",def:col.fuelAmount);
  if(val!=null&&val.isNotEmpty&&context.mounted){
    await updateColectivo(context,col.copyWith(
      fuelAmount:val,fuelDate:DateTime.now(),
    ));
  }
}

Future<void> editColectivoOil(BuildContext context,Colectivo col)async{
  DateTime? picked=await getDate(context,col.oilDate);
  if(picked!=null&&context.mounted){
    await updateColectivo(context,col.copyWith(
      oilDate:picked,
    ));
  }
}

Future<void> editColectivoVtv(BuildContext context,Colectivo col)async{
  DateTime? picked=await getDate(context,col.vtv);
  if(picked!=null&&context.mounted){
    await updateColectivo(context,col.copyWith(
      vtv:picked,
    ));
  }
}


Future<void> removeColectivoDialog(BuildContext context,Colectivo bus,bool restaurar)async{
  return showDialog<void>(
    context: context,
    builder:(BuildContext context){
      return AlertDialog(
        title:Text("${restaurar?"Restaurar":"Eliminar"} Colectivo?"),
        content: Text("¿Seguro que queres ${restaurar?"restaurar":"eliminar"} '${bus.name==""?bus.plate:bus.name}'?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed:()=> Navigator.pop(context),
          ),
          TextButton(
            child:Text(restaurar?"Restaurar":"Eliminar",style:TextStyle(color: Colors.red)),
            onPressed:()async{
              Navigator.pop(context);
              await updateColectivo(context,bus.copyWith(is_active:restaurar));
              if(context.mounted){
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:Text("'${bus.name==""?bus.plate:bus.name}' ${restaurar?"Restaurado":"Eliminado"}"),
                  backgroundColor:restaurar?Colors.green:Colors.red,
                ));
              }
            },
          ),
        ],
      );
    },
  );
}

String colectivoPrettyName(Colectivo cole){
  return (cole.name??"").isEmpty?cole.plate:cole.name!;
}




Widget colectivoToCard(
  BuildContext context,
  Colectivo bus,
  Color mainColor,{
  bool busy=false,
  bool hideOptions=false,
  bool fullInfo=true,
  VoidCallback? onPressed,
  VoidCallback? onLongPress,
}){
  return Container(
    margin:const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    child:BasicCard(
      padding:const EdgeInsets.all(14),
      actionIcon:hideOptions?null:PopupMenuButton(
        icon:const Icon(Icons.more_vert),
        onSelected:(String result)async{
          switch(result){
            case 'edit':
              final success=await showCreateModifiColectivo(context,bus:bus,mainColor:mainColor);
              if(success&&context.mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content:Text("Colectivo actualizado"),backgroundColor:Colors.green),
                );
              }
              break;

            case 'fuel':
              await editColectivoFuel(context,bus);
              break;
            case 'oil':
              await editColectivoOil(context,bus);
              break;
            case 'vtv':
              await editColectivoVtv(context,bus);
              break;

            case 'delete':
              removeColectivoDialog(context,bus,!(bus.is_active));
              break;

            default:
              return;
          }
        },
        itemBuilder:(BuildContext Context)=><PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value:'edit',
            child:Row(children:[
              Icon(Icons.edit),
              SizedBox(width:8),
              Text('Editar')
            ]),
          ),
          PopupMenuItem<String>(
            value:'fuel',
            child:Row(children:[
              Icon(Icons.ev_station),
              SizedBox(width:8),
              Text('Gasoil')
            ]),
          ),
          PopupMenuItem<String>(
            value:'oil',
            child:Row(children:[
              Icon(Icons.water_drop),
              SizedBox(width:8),
              Text('Aceite')
            ]),
          ),
          PopupMenuItem<String>(
            value:'vtv',
            child:Row(children:[
              Icon(Icons.shield),
              SizedBox(width:8),
              Text('VTV')
            ]),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children:bus.is_active? ([
                Icon(Icons.delete, color: Colors.red), 
                SizedBox(width: 8), 
                Text('Borrar',style:TextStyle(color:Colors.red)),
              ]):([
                Icon(Icons.restore_from_trash,color: Colors.green),
                SizedBox(width: 8), 
                Text('Restaurar',style:TextStyle(color:Colors.green))
              ]),
            ),
          )
        ],
      ),
      onPressed:onPressed,
      onLongPressed:onLongPress,
      tonality:bus.is_active&&!busy?null:Colors.red,
      child:Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Row(children:[
            Expanded(child:Text((bus.name??"").isEmpty?bus.plate:bus.name!,
              style: TextStyle(
                fontSize:16,fontWeight:FontWeight.w600,
                color:bus.vtv.isBefore(DateTime.now())?Colors.red:null,
              ))),
            pillText(bus.plate,mainColor),
            if(!hideOptions)
              SizedBox(width:20)
          ]),
          //dataLine("Patente: ${bus.plate}",mainColor),
          if(fullInfo&&bus.is_active)
            DataLine(text:"Gasoil: ${relativeDate(bus.fuelDate)} -> ${bus.fuelAmount}",mainColor:mainColor),
          if(bus.is_active)
            DataLine(text:"VTV: ${bus.vtv.day}-${bus.vtv.month}-${bus.vtv.year}",
              mainColor:mainColor,
              textColor:bus.vtv.isBefore(DateTime.now())?Colors.red:null
            ),
          if(fullInfo&&bus.is_active)
            DataLine(text:"Aceite: ${relativeDate(bus.oilDate,montlhy:true)}",mainColor:mainColor),
          DataLine(text:"Capacidad: ${bus.capacity}",mainColor:mainColor),
          if(bus.number!=null)
            DataLine(text:"Interno: ${bus.number}",mainColor:mainColor),
        ],
      ),
    )
  );
}

Future<Colectivo?> colectivoCardSelectionList(BuildContext context,List<(Colectivo,bool)> buses,Color maincolor)async{
  String searchQuery="";
  return await showModalBottomSheet<Colectivo>(
    context:context,
    isScrollControlled: true,
    constraints:BoxConstraints(maxHeight:MediaQuery.of(context).size.height*0.8),
    builder:(BuildContext context){
      return StatefulBuilder(builder:(BuildContext context,StateSetter setStateModal){
        final filtered=buses.where((s){
          return (s.$1.name?.toUpperCase().contains(searchQuery.toUpperCase())??false)
            ||s.$1.plate.toUpperCase().contains(searchQuery.toUpperCase());
        }).toList();
        return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),child:Column(
          mainAxisSize:MainAxisSize.min,
          children:[
            const SizedBox(height:10),
            mySearchBar(onChanged:(value)=>setStateModal((){searchQuery=value;})),
            const SizedBox(height:10),
            Flexible(child:ListView.builder(
              shrinkWrap: true,
              itemCount:filtered.length,
              itemBuilder:(context,index){
                return Container(
                  margin: EdgeInsets.symmetric(horizontal:15),
                  child:colectivoToCard(
                    context,filtered[index].$1,maincolor,
                    busy:filtered[index].$2,
                    fullInfo:false,
                    hideOptions:true,
                    onPressed:()=>Navigator.of(context).pop(filtered[index].$1),
                  )
                );
              },
            ))
          ]
        ));
      });
    },
  );
}
