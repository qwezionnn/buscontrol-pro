import 'package:flutter/material.dart';
import '../../repositories/part_bookmark_repository.dart';
import '../../widgets/bus_card.dart';

class PartBookmarksScreen extends StatefulWidget {
  const PartBookmarksScreen({super.key});
  @override State<PartBookmarksScreen> createState() => _PartBookmarksScreenState();
}

class _PartBookmarksScreenState extends State<PartBookmarksScreen> {
  final _repo = PartBookmarkRepository.instance;
  final _search = TextEditingController();
  List<Map<String,Object?>> _items = const [];
  bool _loading = true;

  @override void initState(){super.initState();_load();}
  @override void dispose(){_search.dispose();super.dispose();}
  Future<void> _load() async { final x=await _repo.getAll(); if(mounted)setState((){_items=x;_loading=false;});}
  List<Map<String,Object?>> get _filtered {
    final q=_search.text.trim().toLowerCase();
    if(q.isEmpty)return _items;
    return _items.where((x)=>['name','brand','article','shop','note'].any((k)=>(x[k]?.toString().toLowerCase()??'').contains(q))).toList();
  }
  Future<void> _edit([Map<String,Object?>? row]) async {
    final name=TextEditingController(text:row?['name']?.toString()??'');
    final brand=TextEditingController(text:row?['brand']?.toString()??'');
    final article=TextEditingController(text:row?['article']?.toString()??'');
    final shop=TextEditingController(text:row?['shop']?.toString()??'');
    final price=TextEditingController(text:row?['price']?.toString()??'');
    final url=TextEditingController(text:row?['url']?.toString()??'');
    final note=TextEditingController(text:row?['note']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(row==null?'Новая закладка':'Редактировать закладку'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Название *')),
        TextField(controller:brand,decoration:const InputDecoration(labelText:'Бренд (необязательно)')),
        TextField(controller:article,decoration:const InputDecoration(labelText:'Артикул (необязательно)')),
        TextField(controller:shop,decoration:const InputDecoration(labelText:'Где покупал (необязательно)')),
        TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Цена (необязательно)')),
        TextField(controller:url,decoration:const InputDecoration(labelText:'Ссылка (необязательно)')),
        TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Заметка (необязательно)')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Сохранить'))],
    ));
    if(ok==true && name.text.trim().isNotEmpty){
      await _repo.save(id:row?['id'] as int?,name:name.text,brand:brand.text,article:article.text,shop:shop.text,price:double.tryParse(price.text.replaceAll(',','.')),url:url.text,note:note.text); await _load();
    }
  }
  Future<void> _delete(Map<String,Object?> row) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Удалить закладку?'),content:Text(row['name'].toString()),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Удалить'))]));
    if(ok==true){await _repo.delete(row['id'] as int);await _load();}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Закладки запчастей'),actions:[IconButton(onPressed:()=>_edit(),icon:const Icon(Icons.add))]),
    body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Название, бренд, артикул, магазин…')),
      const SizedBox(height:12),
      if(_filtered.isEmpty)const BusCard(child:Padding(padding:EdgeInsets.all(16),child:Text('Закладок пока нет. Обязательное поле только название.'))),
      for(final x in _filtered)Padding(padding:const EdgeInsets.only(bottom:8),child:BusCard(onTap:()=>_edit(x),child:Row(children:[
        const Icon(Icons.bookmark_outline),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(x['name'].toString(),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
          if(x['brand']!=null||x['article']!=null)Text([if(x['brand']!=null)x['brand'],if(x['article']!=null)x['article']].join(' • ')),
          if(x['note']!=null)Text(x['note'].toString(),maxLines:2,overflow:TextOverflow.ellipsis),
        ])),IconButton(onPressed:()=>_delete(x),icon:const Icon(Icons.delete_outline))
      ]))),
    ])
  );
}
