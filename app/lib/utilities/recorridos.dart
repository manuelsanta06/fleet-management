import 'package:agenda/database/tables/recorridos.dart';
import 'package:flutter/material.dart';
import 'package:agenda/widgets/cards.dart';
import 'package:agenda/database/app_database.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../utilities/parsers.dart';
import 'package:url_launcher/url_launcher.dart';


Widget recorridoToCard(BuildContext context,Color mainColor,Recorrido reco,VoidCallback onPressed){
  return BasicCard(
    actionIcon: PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (String result)async{
        if (result=='pin'){
          final deafDb=Provider.of<AppDatabase>(context, listen: false);
          await (deafDb.update(deafDb.recorridos)..where((s)=>s.id.equals(reco.id)))
            .write(RecorridosCompanion(pinned:(drift.Value(!reco.pinned))));
        }else if(result=='delete'){
          final deafDb=Provider.of<AppDatabase>(context, listen: false);
          await (deafDb.update(deafDb.recorridos)..where((s)=>s.id.equals(reco.id)))
            .write(RecorridosCompanion(
              isActive:drift.Value(!reco.isActive),pinned:drift.Value(false),isSynced:drift.Value(false)
            ));
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            children: [Icon(Icons.push_pin), SizedBox(width: 8), Text(reco.pinned?'Unpin':'Pin')],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: reco.isActive? ([
              Icon(Icons.delete, color: Colors.red), 
              SizedBox(width: 8), 
              Text('Borrar',style:TextStyle(color:Colors.red)),
            ]):([
              Icon(Icons.restore_from_trash,color: Colors.green),
              SizedBox(width: 8), 
              Text('Restaurar',style:TextStyle(color:Colors.green))
            ]),
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(24),
    onPressed:onPressed,
    tonality:(!reco.isActive?
      Color(0xffff0000):
      reco.pinned?
      Color(0xffFFD700):
      null),
    borderColor:reco.pinned?Color(0xffFFD700):null,
    child:Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
      Text(reco.name),
      const Text("Valor base",style:TextStyle(color:Colors.grey,fontSize:12)),
      Text("\$${numberParser(reco.basePrice)}",style:TextStyle(color:mainColor))
    ]),
  );
}

Future<RecorridosCompanion?> showCreateRecorridoSheet(BuildContext context, Color mainColor) {
  return showModalBottomSheet<RecorridosCompanion>(
    context: context,
    isScrollControlled: true,
    //backgroundColor: Colors.transparent,
    builder: (context) => _CreateRecorridoForm(mainColor: mainColor),
  );
}

class _CreateRecorridoForm extends StatefulWidget {
  final Color mainColor;
  const _CreateRecorridoForm({required this.mainColor});

  @override
  State<_CreateRecorridoForm> createState() => _CreateRecorridoFormState();
}

class _CreateRecorridoFormState extends State<_CreateRecorridoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  
  final FocusNode _nameFocus = FocusNode(); 

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds:100),(){if(mounted)_nameFocus.requestFocus();});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name=_nameController.text.trim();
      final priceString=_priceController.text.trim();
      
      final newRecorrido = RecorridosCompanion(
        id:drift.Value(Uuid().v4()),
        name:drift.Value(name),
        basePrice:drift.Value(priceString.isEmpty?0:int.parse(priceString)),
        pinned:drift.Value(false),
        isActive:drift.Value(true),
      );

      Navigator.pop(context, newRecorrido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset=MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HANDLE BAR (Estético) ---
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  //color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // --- TÍTULO ---
            Text("Nuevo Recorrido",
              style:TextStyle(fontSize:20,fontWeight:FontWeight.bold),
            ),
            
            const SizedBox(height: 20),

            //NOMBRE
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Nombre del Recorrido",
                hintText: "Ej. Escuela Técnica N°1",
                prefixIcon: Icon(Icons.school,color:widget.mainColor),
                border: OutlineInputBorder(borderRadius:BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color:widget.mainColor,width: 2),
                ),
              ),
              validator:(value){
                if (value==null||value.trim().isEmpty)return'El nombre es obligatorio';
                return null;
              },
            ),

            const SizedBox(height: 16),

            //PRECIO BASE
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Precio Base (Opcional)",
                hintText: "0.00",
                prefixIcon: Icon(Icons.attach_money, color: widget.mainColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.mainColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            //BOTON
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                elevation: 0,
              ),
              child:const Text("CREAR RECORRIDO",
                style:TextStyle(fontSize:16,fontWeight:FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
