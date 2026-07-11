import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'package:agenda/database/app_database.dart';

import 'package:agenda/widgets/cards.dart';
import 'package:agenda/widgets/text.dart';

import 'package:agenda/utilities/parsers.dart';
import 'package:agenda/utilities/debts.dart';


Widget passengerToCard(BuildContext context,
  Color mainColor,
  Passenger passa,
  String recoId,{
  List<Debt>? debts,
  VoidCallback? onPressed,
  VoidCallback? onLongPressed
}){
  onPressed??=()=>showSmartPay(context,mainColor,passengerId:passa.id);
  return BasicCard(
    actionIcon:PopupMenuButton(
      icon:const Icon(Icons.more_vert),
      onSelected:(String result)async{
        switch (result) {
          case 'edit':
            await showCreateModifiPassenger(context,mainColor,passenger:passa);
            break;

          case 'chat':
            await launchUrl(Uri.parse("https://wa.me/${passa.managerPhone}"),mode:LaunchMode.externalApplication);
            break;

          case 'smartPay':
              showSmartPay(context,mainColor,passengerId:passa.id);
              break;
          case 'debt':
            if((await showCreateDebtSheet(context,mainColor,passengerId:passa.id))&&context.mounted){
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content:Text("Deuda actualizada"),backgroundColor:Colors.green)
              );
            }
            break;

          case 'delete':
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
        if(passa.managerPhone?.isNotEmpty??false)
        PopupMenuItem<String>(
          value:'chat',
          child:Row(children:[
            Icon(Icons.phone),
            SizedBox(width:8),
            Text('Chat')
          ]),
        ),
        PopupMenuItem<String>(
          value:'smartPay',
          child:Row(children:[
            Icon(Icons.attach_money,color:Colors.green),
            SizedBox(width:8),
            Text('Añadir pago')
          ]),
        ),
        PopupMenuItem<String>(
          value:'debt',
          child:Row(children:[
            Icon(Icons.attach_money,color:Colors.red),
            SizedBox(width:8),
            Text('Añadir deuda')
          ]),
        ),
        PopupMenuItem<String>(
          value:'delete',
          child:Row(children:[
            Icon(Icons.delete,color:Colors.red),
            SizedBox(width:8),
            Text('Eliminar',style:TextStyle(color:Colors.red))
          ]),
        ),
      ]
    ),
    onPressed:onPressed,
    onLongPressed:onLongPressed,
    child:Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
      Text(passa.name),
      Text(
        "${passa.managerName} - ${passa.managerPhone}",
        style:TextStyle(color:Colors.grey,fontSize:12),
      ),
      if(debts!=null&&debts.isNotEmpty)
      horizontalDebts(debts:debts),
    ])
  );
}

// Wrapper to handle the modal logic and database insertion
Future<bool> showCreateModifiPassenger(
  BuildContext context,
  Color mainColor,{
  Passenger? passenger,
  String? nameDef,
  String? phoneDef,
  String? recoId
})async{
  final result=await showModalBottomSheet<PassengersCompanion>(
    context:context,
    isScrollControlled:true,
    builder:(context)=>_CreatePassengerSheet(
      mainColor:mainColor,
      passenger:passenger,
      initialRecorridoId:recoId,
      nameDef:nameDef,
      phoneDef:phoneDef,
    ),
  );

  if(result==null)return false;
  final db=Provider.of<AppDatabase>(context,listen:false);

  try{
    await db.into(db.passengers).insertOnConflictUpdate(result);
    return true;
  }catch(e){
    print("Error saving passenger: $e");
    return false;
  }
}

class _CreatePassengerSheet extends StatefulWidget{
  final Color mainColor;
  final Passenger? passenger;
  final String? initialRecorridoId;
  final String? nameDef;
  final String? phoneDef;
  const _CreatePassengerSheet({required this.mainColor,this.passenger,this.initialRecorridoId,this.phoneDef,this.nameDef});

  @override
  State<_CreatePassengerSheet> createState()=>_CreatePassengerSheetState();
}

class _CreatePassengerSheetState extends State<_CreatePassengerSheet>{
  final _formKey=GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _managerC;
  late final TextEditingController _phoneC;
  late final TextEditingController _priceC;
  String? _selectedRecorridoId;

  @override
  void initState(){
    super.initState();
    _nameC=TextEditingController(text:widget.passenger?.name??widget.nameDef??"");
    _managerC=TextEditingController(text:widget.passenger?.managerName??"");
    _phoneC=TextEditingController(text:widget.passenger?.managerPhone??widget.phoneDef??"");
    
    // If customPrice is -1, we show an empty string in the UI
    final int currentPrice=widget.passenger?.customPrice??-1;
    _priceC=TextEditingController(text:currentPrice==-1?"":currentPrice.toString());
    
    // Priority: existing passenger data > passed initial ID
    _selectedRecorridoId=widget.passenger?.recorridoId??widget.initialRecorridoId;
  }

  @override
  void dispose(){
    _nameC.dispose();
    _managerC.dispose();
    _phoneC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final db=Provider.of<AppDatabase>(context,listen:false);

    return SafeArea(child:Padding(
      padding:EdgeInsets.only(
        left:20,right:20,top:20,
        bottom:MediaQuery.of(context).viewInsets.bottom+20,
      ),
      child:Form(
        key:_formKey,
        child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Row(
              mainAxisAlignment:MainAxisAlignment.spaceBetween,
              children:[
                Text(widget.passenger==null?"Nuevo Pasajero":"Editar Pasajero",
                  style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:widget.mainColor)),
                ElevatedButton(
                  onPressed:(){
                    if(_formKey.currentState!.validate()){
                      // If price field is empty, we save -1 (default)
                      final int finalPrice=int.tryParse(_priceC.text)??-1;
                      
                      final p=PassengersCompanion(
                        id:drift.Value(widget.passenger?.id??const Uuid().v4()),
                        name:drift.Value(_nameC.text),
                        managerName:drift.Value(_managerC.text),
                        managerPhone:drift.Value(phoneParser(_phoneC.text)),
                        recorridoId:drift.Value(_selectedRecorridoId!),
                        customPrice:drift.Value(finalPrice),
                        isActive:drift.Value(widget.passenger?.isActive??true),
                        isSynced:const drift.Value(false),
                      );
                      Navigator.pop(context,p);
                    }
                  },
                  style:ElevatedButton.styleFrom(backgroundColor:widget.mainColor,foregroundColor:Colors.white),
                  child:const Text("Guardar"),
                ),
              ],
            ),
            const SizedBox(height:20),
            TextFormField(
              controller:_nameC,
              decoration:const InputDecoration(labelText:"Nombre",prefixIcon:Icon(Icons.person_outline)),
              validator:(v)=>v==null||v.isEmpty?"Por favor ingresa un nombre":null,
            ),
            const SizedBox(height:15),
            TextFormField(
              controller:_managerC,
              decoration:const InputDecoration(labelText:"Nombre del padre",prefixIcon:Icon(Icons.supervisor_account)),
            ),
            const SizedBox(height:15),
            TextFormField(
              controller:_phoneC,
              keyboardType:TextInputType.phone,
              decoration:const InputDecoration(labelText:"Teléfono de contacto",prefixIcon:Icon(Icons.phone_android)),
            ),
            const SizedBox(height:15),
            TextFormField(
              controller:_priceC,
              keyboardType:TextInputType.number,
              decoration:const InputDecoration(
                labelText:"Precio personalizado",
                hintText:"Vacío para usar precio general",
                prefixIcon:Icon(Icons.sell_outlined)
              ),
            ),
            const SizedBox(height:15),
            // Recorrido Selector - Only active recorridos
            FutureBuilder<List<Recorrido>>(
              future:(db.select(db.recorridos)..where((t)=>t.isActive.equals(true))).get(),
              builder:(context,snapshot){
                if(!snapshot.hasData)return const LinearProgressIndicator();
                final items=snapshot.data!;
                return DropdownButtonFormField<String>(
                  value:_selectedRecorridoId,
                  decoration:const InputDecoration(labelText:"Asignar Recorrido",prefixIcon:Icon(Icons.route)),
                  items:items.map((r)=>DropdownMenuItem(value:r.id,child:Text(r.name))).toList(),
                  onChanged:(val)=>setState(()=>_selectedRecorridoId=val),
                  validator:(v)=>v==null?"Por favor selecciona un recorrido":null,
                );
              },
            ),
          ],
        ),
      ),
    ));
  }
}
