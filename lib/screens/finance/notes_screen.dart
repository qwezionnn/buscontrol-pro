import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../widgets/bus_card.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}
class _NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String,Object?>> _notes = const [];
  bool _loading = true;

  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    final rows=await _db.getNotes();
    if(!mounted)return;
    setState(()=>_notes=rows..sort((a,b)=> (b['updated_at']??'').toString().compareTo((a['updated_at']??'').toString())));
    setState(()=>_loading=false);
  }
  Future<void> _edit([Map<String,Object?>? note]) async {
    final title=TextEditingController(text: note?['title']?.toString()??'');
    final body=TextEditingController(text: note?['body']?.toString()??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(note==null?'Новая заметка':'Редактировать заметку'),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Заголовок')),
        TextField(controller:body,maxLines:5,decoration:const InputDecoration(labelText:'Текст')),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Сохранить')),
      ],
    ));
    if(ok==true && title.text.trim().isNotEmpty){
      await _db.saveNote(id: note?['id'] as int?,title:title.text,body:body.text);
      await _load();
    }
    title.dispose(); body.dispose();
  }
  Future<void> _delete(Map<String,Object?> note) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Удалить заметку?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Удалить'))]));
    if(ok==true){await _db.deleteNote(note['id'] as int);await _load();}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Заметки')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('Заметка'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_notes.isEmpty)
                      const BusCard(child: Text('Заметок пока нет.')),
                    for (final n in _notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _edit(n),
                          onLongPress: () => _delete(n),
                          child: BusCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((n['body']?.toString() ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(n['body'].toString()),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  'Нажмите для редактирования • удерживайте для удаления',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
}
