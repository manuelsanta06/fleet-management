import 'package:agenda/database/app_database.dart';
import 'package:intl/intl.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift; 
import 'dart:io';

import 'package:agenda/utilities/parsers.dart';
import 'package:agenda/utilities/syncService.dart';
import 'package:agenda/utilities/debts.dart';

import 'package:agenda/widgets/imageImput.dart';
import 'package:agenda/widgets/searchBar.dart';
import 'package:agenda/widgets/cards.dart';
import 'package:agenda/widgets/text.dart';

typedef Chofer=Chofere;

Color rotateColor(Color ete,int rotation){
  return HSLColor.fromAHSL(1.0,(HSLColor.fromColor(ete).hue+rotation)%360,1.0,0.5).toColor();
}

Widget initialsImage(Chofer chofe, Color mainColor){
  String letters;
  if(chofe.alias?.isNotEmpty??false)letters=chofe.alias!.substring(0,2).toUpperCase();
  else letters=((chofe.name?.isNotEmpty??false)?chofe.name![0]:"")+
        ((chofe.surname?.isNotEmpty??false)?chofe.surname![0].toLowerCase():"");

  return Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        colors: [mainColor,rotateColor(mainColor,60)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      letters,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
    ),
  );
}

//TODO: usar "cachedNetworkImage" cuando haya servidor
Widget buildAvatar(Chofer chofe, Color mainColor){
  if(chofe.picturePath?.isNotEmpty??false){
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(chofe.picturePath!),
        //loadingBuilder:(BuildContext c){return const Center(child: CircularProgressIndicator())},
        height: 72,
      ),
    );
  }
  return initialsImage(chofe, mainColor);
}

Future<void> removeChoferDialog(BuildContext context, Chofer chofe,bool restaurar)async{
  return showDialog<void>(
    context: context,
    builder:(BuildContext context){
      return AlertDialog(
        title: Text("${restaurar?"Restaurar":"Eliminar"} chofer?"),
        content:Text("¿Seguro que queres ${restaurar?"restaurar":"eliminar"} '${chofe.alias?.isNotEmpty??false?chofe.alias:chofe.name}'?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed:()=> Navigator.pop(context),
          ),
          TextButton(
            child:Text(restaurar?"Restaurar":"Eliminar", style: TextStyle(color: Colors.red)),
            onPressed:()async{
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:Text(restaurar?"Restaurado":"Eliminado"),
                backgroundColor:Colors.red,
              ));
              final db=Provider.of<AppDatabase>(context, listen: false);
              await (db.update(db.choferes)
                ..where((tbl)=>tbl.id.equals(chofe.id)))
                .write(ChoferesCompanion(
                  is_active: drift.Value(restaurar)
                ));
            },
          ),
        ],
      );
    },
  );
}

String choferPrettyName(Chofer chofe){
  return (chofe.alias?.isNotEmpty??false)?
    chofe.alias!
    :'${chofe.name?.split(" ").first??""} ${chofe.surname?.split(" ").first??""}';
}
String choferShortName(Chofer chofe){
  if((chofe.alias??"").isNotEmpty)return chofe.alias!;
  if((chofe.name??"").isNotEmpty)return chofe.name!;
  return chofe.surname!;
}

Widget choferToCard(
  BuildContext context,
  Chofer chofe,
  Color mainColor, {
  List<Debt>? debts,
  bool busy=false,
  bool hideOptions=false,
  VoidCallback? onPressed,
  VoidCallback? onLongPress,
}){
  return  Container(
    child:BasicCard(
      padding:const EdgeInsets.all(14),
      tonality:chofe.is_active&&!busy?null:Colors.red,
      onPressed:onPressed,
      onLongPressed:onLongPress,
      actionIcon:hideOptions?
        IconButton(icon:Icon(Icons.phone),
          onPressed:()=>launchUrl(Uri.parse("https://wa.me/${chofe.mobileNumber}"),mode:LaunchMode.externalApplication),
        ):
        PopupMenuButton(
          icon:const Icon(Icons.more_vert),
          onSelected:(String result)async{
            switch (result){
              case 'edit':
                final success = await showCreateModifiChofer(context, mainColor, chofe: chofe);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Chofer actualizado"), backgroundColor: Colors.green),
                  );
                }
                break;

              case 'chat':
                await launchUrl(Uri.parse("https://wa.me/${chofe.mobileNumber}"),mode:LaunchMode.externalApplication);
                break;

              case 'smartPay':
                showSmartPay(context,mainColor,choferId:chofe.id);
                break;
              case 'debt':
                if((await showCreateDebtSheet(context,mainColor,choferId:chofe.id))&&context.mounted){
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content:Text("Deuda actualizada"),backgroundColor:Colors.green)
                  );
                }
                break;

              case 'delete':
                removeChoferDialog(context,chofe,!chofe.is_active);
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
              child:Row(children:chofe.is_active? ([
                Icon(Icons.delete, color: Colors.red), 
                SizedBox(width: 8), 
                Text('Borrar',style:TextStyle(color:Colors.red)),
              ]):([
                Icon(Icons.restore_from_trash,color: Colors.green),
                SizedBox(width: 8), 
                Text('Restaurar',style:TextStyle(color:Colors.green))
              ])),
            ),
          ]
        ),

      child:Column(children:[
        Row(children:[
          buildAvatar(chofe, mainColor),
          const SizedBox(width: 14),
          Expanded(child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Text(
                choferPrettyName(chofe),
                style: const TextStyle(fontSize: 16,fontWeight: FontWeight.w600,),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataLine(text:"DNI: ${chofe.dni}",mainColor:mainColor),
                  DataLine(text:"Tel: ${chofe.mobileNumber}",mainColor:mainColor),
                ],
              ),
            ],
          )),
        ]),
        if(debts!=null&&debts.isNotEmpty)
        Padding(padding:EdgeInsetsGeometry.only(top:10),child:horizontalDebts(debts:debts)),
      ])
    ),
  );
}

Future<Chofer?> choferCardSelectionList(BuildContext context,List<(Chofer, bool)> chofes,Color maincolor)async{
  String searchQuery="";
  return await showModalBottomSheet<Chofer>(
    context:context,
    isScrollControlled: true,
    constraints:BoxConstraints(maxHeight:MediaQuery.of(context).size.height*0.8),
    builder:(BuildContext context){
      return StatefulBuilder(builder:(BuildContext context,StateSetter setStateModal){
        final filtered=chofes.where((s){
          return (s.$1.name?.toUpperCase().contains(searchQuery.toUpperCase())??false)
            ||(s.$1.surname?.toUpperCase().contains(searchQuery.toUpperCase())??false)
            ||(s.$1.alias?.toUpperCase().contains(searchQuery.toUpperCase())??false);
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
                  child:choferToCard(
                    context,filtered[index].$1,maincolor,
                    busy:filtered[index].$2,
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


Future<bool> showCreateModifiChofer(BuildContext context, Color mainColor, {Chofer? chofe}) async {
  final result=await showModalBottomSheet<ChoferesCompanion?>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _CreateChoferSheet(mainColor: mainColor, chofe: chofe),
  );
  if(result==null)return false;
  final db=Provider.of<AppDatabase>(context, listen: false);

  try{
    await db.into(db.choferes).insertOnConflictUpdate(
      result,
    );
    SyncService.pushUnsyncedData(db);
    return true;
  }catch(e){
    print("Error guardando chofer en Drift: $e");
    return false;
  }
}

class _CreateChoferSheet extends StatefulWidget {
  final Color mainColor;
  final Chofer? chofe;
  
  const _CreateChoferSheet({required this.mainColor, this.chofe});

  @override
  State<_CreateChoferSheet> createState() => _CreateChoferSheetState();
}

class _CreateChoferSheetState extends State<_CreateChoferSheet> {
  late final TextEditingController nameC;
  late final TextEditingController surNameC;
  late final TextEditingController aliasC;
  late final TextEditingController dniC;
  late final TextEditingController mobileNumberC;
  late String pictureD;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.chofe?.name ?? "");
    surNameC = TextEditingController(text: widget.chofe?.surname ?? "");
    aliasC = TextEditingController(text: widget.chofe?.alias ?? "");
    dniC = TextEditingController(text: widget.chofe?.dni ?? "");
    mobileNumberC = TextEditingController(text: widget.chofe?.mobileNumber ?? "");
    pictureD = widget.chofe?.picturePath ?? "";
  }

  @override
  void dispose() {
    nameC.dispose();
    surNameC.dispose();
    aliasC.dispose();
    dniC.dispose();
    mobileNumberC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          left: 15, right: 15, top: 15,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: aliasC,
                    decoration: const InputDecoration(
                      labelText: "Apodo",
                      fillColor: Colors.transparent,
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameC.text.isEmpty && surNameC.text.isEmpty && aliasC.text.isEmpty) return;
                    
                    final nuevo = ChoferesCompanion(
                      id: drift.Value(widget.chofe?.id ?? const Uuid().v4()),
                      name: drift.Value(nameC.text),
                      surname: drift.Value(surNameC.text),
                      alias: drift.Value(aliasC.text),
                      dni: drift.Value(dniC.text),
                      mobileNumber: drift.Value(phoneParser(mobileNumberC.text)),
                      picturePath: drift.Value(pictureD),
                      is_active: const drift.Value(true),
                      isSynced: const drift.Value(false),
                    );
                    Navigator.pop(context, nuevo);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.mainColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Guardar"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child:Text("Nombre completo")),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: "Nombres/s"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: surNameC,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: "Apellido/s"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child:Text("DNI")),
            TextField(
              controller: dniC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "12345678"),
            ),
            const SizedBox(height: 8),
            const Center(child:Text("Telefono")),
            TextField(
              controller: mobileNumberC,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: "1234567890"),
            ),
            const SizedBox(height: 8),
            const Center(child:Text("Imagen")),
            GestureDetector(
              onTap: () async {
                final tmp = await saveImageLocally(await pickImage(context, [CropAspectRatioPreset.square]));
                if (tmp == null) return;
                setState(() { pictureD = tmp; });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: pictureD.isEmpty ? const Color(0xFF94A3B8) : Colors.green,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  "Subir foto",
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}
