import 'package:flutter/material.dart';
import '../../repositories/repair_repository.dart';
import '../../repositories/part_bookmark_repository.dart';
import '../../widgets/bus_card.dart';

class RepairHistoryScreen extends StatefulWidget {
  const RepairHistoryScreen({super.key});
  @override State<RepairHistoryScreen> createState()=>_RepairHistoryScreenState();
}
class _RepairHistoryScreenState extends State<RepairHistoryScreen>{
  final _repo=RepairRepository.instance; List<Map<String,Object?>> _items=const[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final x=await _repo.getAll();if(mounted)setState((){_items=x;_loading=false;});}
  String _date(String s){final d=DateTime.tryParse(s);return d==null?s:'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';}
  Future<void> _edit([Map<String,Object?>? row])async{
    DateTime date=DateTime.tryParse(row?['date']?.toString()??'')??DateTime.now();
    final title=TextEditingController(text:row?['title']?.toString()??'');
    final mileage=TextEditingController(text:row?['mileage']?.toString()??'');
    final part=TextEditingController(text:row?['part_name']?.toString()??'');
    final partCost=TextEditingController(text:row?['part_cost']?.toString()??'');
    final workCost=TextEditingController(text:row?['work_cost']?.toString()??'');
    final vehicle=TextEditingController(text:row?['vehicle_paid']?.toString()??'0');
    final personal=TextEditingController(text:row?['personal_paid']?.toString()??'0');
    final credit=TextEditingController(text:row?['credit_paid']?.toString()??'0');
    final note=TextEditingController(text:row?['note']?.toString()??'');
    bool selfRepair=(row?['self_repair'] as int? ??1)==1;
    String source=row?['part_source']?.toString()??'manual'; int? expenseId=row?['expense_id'] as int?; int? bookmarkId=row?['bookmark_id'] as int?;
    final expenses=await _repo.getExpenses(); final bookmarks=await PartBookmarkRepository.instance.getAll(); if(!mounted)return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(row==null?'Новый ремонт':'Редактировать ремонт'),content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(contentPadding:EdgeInsets.zero,title:const Text('Дата ремонта'),subtitle:Text(_date('${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}')),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await showDatePicker(context:c,initialDate:date,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)setD(()=>date=d);}),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Что ремонтировал / делал *')),
        TextField(controller:mileage,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Пробег (необязательно)')),
        DropdownButtonFormField<String>(value:source,decoration:const InputDecoration(labelText:'Запчасть'),items:const[
          DropdownMenuItem(value:'manual',child:Text('Ввести вручную')),DropdownMenuItem(value:'expense',child:Text('Выбрать из расходов')),DropdownMenuItem(value:'bookmark',child:Text('Выбрать из закладок')),
        ],onChanged:(v)=>setD(()=>source=v!)),
        if(source=='manual')TextField(controller:part,decoration:const InputDecoration(labelText:'Наименование запчасти')),
        if(source=='expense')DropdownButtonFormField<int>(value:expenseId,decoration:const InputDecoration(labelText:'Покупка из расходов'),items:expenses.map((e)=>DropdownMenuItem(value:e['id'] as int,child:Text('${e['date']} • ${e['category']} • ${e['amount']} ₽',overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){final e=expenses.firstWhere((x)=>x['id']==v);setD((){expenseId=v;part.text=(e['description']??e['category']).toString();partCost.text=e['amount'].toString();});}),
        if(source=='bookmark')DropdownButtonFormField<int>(value:bookmarkId,decoration:const InputDecoration(labelText:'Из закладок'),items:bookmarks.map((e)=>DropdownMenuItem(value:e['id'] as int,child:Text(e['name'].toString()))).toList(),onChanged:(v){final e=bookmarks.firstWhere((x)=>x['id']==v);setD((){bookmarkId=v;part.text=e['name'].toString();if(e['price']!=null)partCost.text=e['price'].toString();});}),
        if(source!='expense')TextField(controller:partCost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Стоимость запчасти (необязательно)')),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Ремонтировал самостоятельно'),value:selfRepair,onChanged:(v)=>setD(()=>selfRepair=v)),
        if(!selfRepair)TextField(controller:workCost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Стоимость работы (необязательно)')),
        const SizedBox(height:8),const Align(alignment:Alignment.centerLeft,child:Text('С какого счёта оплачено',style:TextStyle(fontWeight:FontWeight.bold))),
        TextField(controller:vehicle,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Автобус, ₽')),
        TextField(controller:personal,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Личные, ₽')),
        TextField(controller:credit,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Кредиты, ₽')),
        TextField(controller:note,maxLines:2,decoration:const InputDecoration(labelText:'Заметка')),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Сохранить'))],
    )));
    if(ok==true&&title.text.trim().isNotEmpty){
      double n(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'))??0;
      final pc=n(partCost),wc=selfRepair?0:n(workCost),vp=n(vehicle),pp=n(personal),cp=n(credit);
      final expected=source=='expense'?wc:pc+wc; final paid=vp+pp+cp;
      if((paid-expected).abs()>0.01&&paid>0&&mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Распределено ${paid.toStringAsFixed(0)} ₽, а стоимость ${expected.toStringAsFixed(0)} ₽. Нужно, чтобы суммы совпадали.')));return;}
      await _repo.save({'date':'${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}','mileage':int.tryParse(mileage.text),'title':title.text.trim(),'part_source':source,'part_name':part.text.trim().isEmpty?null:part.text.trim(),'expense_id':expenseId,'bookmark_id':bookmarkId,'self_repair':selfRepair?1:0,'work_cost':selfRepair?null:wc,'part_cost':source=='expense'?null:pc,'vehicle_paid':vp,'personal_paid':pp,'credit_paid':cp,'note':note.text.trim().isEmpty?null:note.text.trim()},id:row?['id'] as int?);await _load();
    }
  }
  Future<void> _delete(Map<String,Object?> r)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Удалить запись ремонта?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Удалить'))]));if(ok==true){await _repo.delete(r['id'] as int);await _load();}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Ремонт'),actions:[IconButton(onPressed:()=>_edit(),icon:const Icon(Icons.add))]),body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
    if(_items.isEmpty)const BusCard(child:Padding(padding:EdgeInsets.all(16),child:Text('История ремонта пока пустая. Запись можно добавить за любой день.'))),
    for(final r in _items)Padding(padding:const EdgeInsets.only(bottom:8),child:BusCard(onTap:()=>_edit(r),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.build_outlined),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['title'].toString(),style:const TextStyle(fontWeight:FontWeight.bold)),Text('${_date(r['date'].toString())}${r['mileage']!=null?' • ${r['mileage']} км':''}'),if(r['part_name']!=null)Text('Запчасть: ${r['part_name']}')])) ,IconButton(onPressed:()=>_delete(r),icon:const Icon(Icons.delete_outline))]))),
  ]));
}
