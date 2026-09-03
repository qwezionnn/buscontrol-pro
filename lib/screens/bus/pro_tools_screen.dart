import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/vehicle.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../widgets/bus_card.dart';
import '../../services/notification_service.dart';

class ProToolsScreen extends StatefulWidget {
  const ProToolsScreen({super.key});
  @override State<ProToolsScreen> createState() => _ProToolsScreenState();
}

class _ProToolsScreenState extends State<ProToolsScreen> {
  final db = DatabaseHelper.instance;
  final reports = ReportRepository.instance;
  final vehicles = VehicleRepository.instance;
  Vehicle? vehicle;
  List<Map<String,Object?>> planned = const [], service = const [], personal = const [];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    final v=await vehicles.getActiveVehicle();
    final p=await db.getPlannedExpenses(); final s=await db.getServicePlans(); final pe=await db.getPersonalVehicleEvents();
    if(!mounted)return; setState((){vehicle=v;planned=p;service=s;personal=pe;});
  }
  String money(Object? v)=>'${((v as num?)?.toDouble()??0).toStringAsFixed(0)} ₽';
  Future<void> _planned() async { final title=TextEditingController(), amount=TextEditingController(), date=TextEditingController(); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Планируемый расход'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Что планируется')),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Примерная сумма',suffixText:'₽')),TextField(controller:date,decoration:const InputDecoration(labelText:'Дата (ГГГГ-ММ-ДД), необязательно'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Добавить'))])); if(ok==true&&title.text.trim().isNotEmpty){await db.addPlannedExpense(title:title.text,amount:double.tryParse(amount.text.replaceAll(',','.'))??0,dueDate:date.text.trim().isEmpty?null:date.text.trim());await _load();} }
  Future<void> _service() async { final title=TextEditingController(), nextDate=TextEditingController(), nextKm=TextEditingController(), first=TextEditingController(text:'7'), second=TextEditingController(text:'1'); final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ТО / напоминание'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Например: масло и фильтры')),TextField(controller:nextDate,decoration:const InputDecoration(labelText:'Дата ГГГГ-ММ-ДД (необязательно)')),TextField(controller:nextKm,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Пробег замены (необязательно)')),TextField(controller:first,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Первое напоминание за, дней')),TextField(controller:second,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Второе напоминание за, дней'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Сохранить'))])); if(ok==true&&title.text.trim().isNotEmpty){final id=await db.addServicePlan({'title':title.text.trim(),'next_date':nextDate.text.trim().isEmpty?null:nextDate.text.trim(),'next_mileage':int.tryParse(nextKm.text),'first_notice_days':int.tryParse(first.text)??7,'second_notice_days':int.tryParse(second.text)??1,'first_notice_km':1000,'second_notice_km':200,'enabled':1}); if(nextDate.text.trim().isNotEmpty){await NotificationService.instance.scheduleService(id:id,title:title.text.trim(),date:nextDate.text.trim(),firstDays:int.tryParse(first.text)??7,secondDays:int.tryParse(second.text)??1);} await _load();} }
  Future<void> _personalEvent() async { final title=TextEditingController(), amount=TextEditingController(), mileage=TextEditingController(), brand=TextEditingController(), article=TextEditingController(); String type='part'; final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(title:const Text('Запись по личной машине'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:type,items:const [DropdownMenuItem(value:'part',child:Text('Запчасть')),DropdownMenuItem(value:'repair',child:Text('Ремонт')),DropdownMenuItem(value:'service',child:Text('ТО / обслуживание'))],onChanged:(v)=>setLocal(()=>type=v??'part')),TextField(controller:title,decoration:const InputDecoration(labelText:'Что купил / сделал')),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Стоимость',suffixText:'₽')),TextField(controller:mileage,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Пробег')),TextField(controller:brand,decoration:const InputDecoration(labelText:'Бренд')),TextField(controller:article,decoration:const InputDecoration(labelText:'Артикул'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Добавить'))]))); if(ok==true&&title.text.trim().isNotEmpty){final now=DateTime.now();await db.addPersonalVehicleEvent({'date':'${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}','mileage':int.tryParse(mileage.text),'type':type,'title':title.text.trim(),'amount':double.tryParse(amount.text.replaceAll(',','.'))??0,'brand':brand.text.trim(),'article':article.text.trim(),'favorite':0});await _load();} }
  Future<void> _search() async { final q=TextEditingController(); List<Map<String,Object?>> result=[]; await showDialog<void>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(title:const Text('Поиск по всей истории'),content:SizedBox(width:520,height:420,child:Column(children:[TextField(controller:q,decoration:InputDecoration(hintText:'Запчасть, заказ, ремонт...',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()async{result=await db.searchHistory(q.text);setLocal((){});}))),const SizedBox(height:8),Expanded(child:result.isEmpty?const Center(child:Text('Введите запрос')):ListView.builder(itemCount:result.length,itemBuilder:(_,i){final r=result[i];return ListTile(title:Text(r['title']?.toString()??r['description']?.toString()??r['name']?.toString()??''),subtitle:Text('${r['history_type']??''} • ${r['date']??r['created_at']??''}'));}))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Закрыть'))]))); }
  Future<void> _monthArchive() async { var month=DateTime(DateTime.now().year,DateTime.now().month); await Navigator.push(context,MaterialPageRoute(builder:(_)=>_MonthArchiveScreen(initial:month))); }
  Future<void> _year() async {
    final year=DateTime.now().year; var trips=0,orders=0,distance=0; var income=0.0,costs=0.0;
    for(var m=1;m<=12;m++){final r=await reports.getMonthReport(DateTime(year,m));trips+=r.completedTrips;orders+=r.completedOrders;distance+=r.distance;income+=r.tripIncome+r.orderIncome;costs+=r.fuelCost+r.expenseCost;}
    if(!mounted)return; await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:Text('Итоги $year года'),content:Text('Рейсы: $trips\nЗаказы: $orders\nПробег: $distance км\nДоход работы: ${money(income)}\nРабочие расходы: ${money(costs)}\nРезультат: ${money(income-costs)}'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Закрыть'))]));
  }
  @override Widget build(BuildContext context){final personalMode=vehicle?.isPersonal??false;return Scaffold(appBar:AppBar(title:Text(personalMode?'Журнал автомобиля':'Центр BusControl 5.0')),floatingActionButton:personalMode?FloatingActionButton.extended(onPressed:_personalEvent,icon:const Icon(Icons.add),label:const Text('Запись')):null,body:ListView(padding:const EdgeInsets.all(16),children:[if(!personalMode)...[BusCard(onTap:_monthArchive,child:const ListTile(leading:Icon(Icons.history),title:Text('История по месяцам'),subtitle:Text('Рейсы, заказы, топливо, расходы, ремонты и полная сводка'),trailing:Icon(Icons.chevron_right))),BusCard(onTap:_year,child:const ListTile(leading:Icon(Icons.bar_chart),title:Text('Итоги года'),subtitle:Text('Рейсы, заказы, пробег, доходы и рабочие расходы'),trailing:Icon(Icons.chevron_right))),BusCard(onTap:_search,child:const ListTile(leading:Icon(Icons.search),title:Text('Поиск по всей истории'),trailing:Icon(Icons.chevron_right))),BusCard(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DebtsScreen())),child:const ListTile(leading:Icon(Icons.request_quote_outlined),title:Text('Долги по заказам'),subtitle:Text('Все неоплаченные и частично оплаченные заказы'),trailing:Icon(Icons.chevron_right))),BusCard(onTap:_planned,child:ListTile(leading:const Icon(Icons.event_note),title:const Text('Планируемые расходы'),subtitle:Text('${planned.length} активных • ${money(planned.fold<double>(0,(a,r)=>a+((r['amount'] as num?)?.toDouble()??0)))}'),trailing:const Icon(Icons.add))),] else ...[const BusCard(child:ListTile(leading:Icon(Icons.directions_car),title:Text('Личный автомобиль'),subtitle:Text('Только пробег, запчасти, ремонты и ТО. Топливо и зарплата не учитываются.'))),...personal.map((r)=>Card(child:ListTile(title:Text(r['title']?.toString()??''),subtitle:Text('${r['date']} • ${r['mileage']??'—'} км • ${money(r['amount'])}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{await db.deletePersonalVehicleEvent(r['id'] as int);await _load();}))))],const SizedBox(height:8),BusCard(onTap:_service,child:ListTile(leading:const Icon(Icons.notifications_active_outlined),title:const Text('ТО и умные напоминания'),subtitle:Text('${service.length} пунктов • интервалы задаются индивидуально'),trailing:const Icon(Icons.add))),...service.map((r)=>Card(child:ListTile(title:Text(r['title']?.toString()??''),subtitle:Text('Дата: ${r['next_date']??'—'} • Пробег: ${r['next_mileage']??'—'} • напомнить за ${r['first_notice_days']} и ${r['second_notice_days']} дн.'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{await db.deleteServicePlan(r['id'] as int);await _load();})))),if(!personalMode)...planned.map((r)=>CheckboxListTile(value:r['completed']==1,title:Text(r['title']?.toString()??''),subtitle:Text('${money(r['amount'])}${r['due_date']==null?'':' • ${r['due_date']}'}'),onChanged:(v)async{await db.setPlannedExpenseCompleted(r['id'] as int,v??false);await _load();}))]));}
}


class _MonthArchiveScreen extends StatefulWidget {
  const _MonthArchiveScreen({required this.initial});
  final DateTime initial;

  @override
  State<_MonthArchiveScreen> createState() => _MonthArchiveScreenState();
}

class _MonthArchiveScreenState extends State<_MonthArchiveScreen> {
  final db = DatabaseHelper.instance;
  final reports = ReportRepository.instance;

  late DateTime month;
  bool loading = true;
  MonthReport? report;
  MonthReport? previous;
  List<Map<String, Object?>> trips = [];
  List<Map<String, Object?>> orders = [];
  List<Map<String, Object?>> fuel = [];
  List<Map<String, Object?>> expenses = [];
  List<Map<String, Object?>> repairs = [];

  @override
  void initState() {
    super.initState();
    month = widget.initial;
    load();
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _money(num value) => '${value.toDouble().toStringAsFixed(0)} ₽';

  double _price(Map<String, Object?> row) =>
      (row['price'] as num?)?.toDouble() ?? 0;

  double _waitHours(Map<String, Object?> row) =>
      (row['wait_hours'] as num?)?.toDouble() ?? 0;

  double _waitRate(Map<String, Object?> row) =>
      (row['wait_rate'] as num?)?.toDouble() ?? 0;

  double _tripTotal(Map<String, Object?> row) =>
      _price(row) + _waitHours(row) * _waitRate(row);

  Future<void> load() async {
    setState(() => loading = true);
    final from = _date(DateTime(month.year, month.month));
    final to = _date(DateTime(month.year, month.month + 1, 0));

    final currentReport = await reports.getMonthReport(month);
    final prevReport = await reports.getMonthReport(
      DateTime(month.year, month.month - 1),
    );
    final monthTrips = await db.getTripsBetween(from, to);
    final monthOrders = await db.getOrdersBetween(from, to);
    final monthFuel = await db.getFuelLogsBetween(from, to);
    final monthExpenses = await db.getExpensesBetween(from, to);
    final allRepairs = await db.getRepairs();

    if (!mounted) return;
    setState(() {
      report = currentReport;
      previous = prevReport;
      trips = monthTrips.where((x) => x['completed'] == 1).toList();
      orders = monthOrders;
      fuel = monthFuel;
      expenses = monthExpenses;
      repairs = allRepairs.where((x) {
        final date = x['date']?.toString() ?? '';
        return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
      }).toList();
      loading = false;
    });
  }

  int get _morningCount => trips.where((x) => x['type'] == 'morning').length;
  int get _eveningCount => trips.where((x) => x['type'] == 'evening').length;
  int get _extraCount => trips.where((x) => x['type'] == 'extra').length;

  double get _morningAmount => trips
      .where((x) => x['type'] == 'morning')
      .fold<double>(0, (a, x) => a + _tripTotal(x));

  double get _eveningAmount => trips
      .where((x) => x['type'] == 'evening')
      .fold<double>(0, (a, x) => a + _tripTotal(x));

  List<Map<String, Object?>> get _extraTrips =>
      trips.where((x) => x['type'] == 'extra').toList();

  int get _fullDays {
    final map = <String, Set<String>>{};
    for (final row in trips.where(
      (x) => x['type'] == 'morning' || x['type'] == 'evening',
    )) {
      final date = row['date']?.toString() ?? '';
      map.putIfAbsent(date, () => <String>{}).add(row['type'].toString());
    }
    return map.values
        .where((types) => types.contains('morning') && types.contains('evening'))
        .length;
  }

  int get _partialDays {
    final map = <String, Set<String>>{};
    for (final row in trips.where(
      (x) => x['type'] == 'morning' || x['type'] == 'evening',
    )) {
      final date = row['date']?.toString() ?? '';
      map.putIfAbsent(date, () => <String>{}).add(row['type'].toString());
    }
    return map.values.where((types) => types.length == 1).length;
  }

  double get _extraBase =>
      _extraTrips.fold<double>(0, (a, x) => a + _price(x));

  double get _extraWaitHours =>
      _extraTrips.fold<double>(0, (a, x) => a + _waitHours(x));

  double get _extraWaitAmount => _extraTrips.fold<double>(
        0,
        (a, x) => a + _waitHours(x) * _waitRate(x),
      );

  Widget _metric(String title, String value, {String? subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryTab() {
    final r = report;
    if (r == null) return const SizedBox.shrink();
    final consumption = r.distance > 0 ? r.fuelLiters / r.distance * 100 : 0.0;
    final tripDelta = r.completedTrips - (previous?.completedTrips ?? 0);
    final mileageDelta = r.distance - (previous?.distance ?? 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Главное за месяц',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('Полных рейсов (утро + вечер): $_fullDays'),
              Text('Неполных дней: $_partialDays'),
              Text('Доп. рейсов: $_extraCount'),
              Text('Заказов: ${orders.length}'),
              Text('Пробег: ${r.distance} км'),
              Text(
                'Топливо: ${r.fuelLiters.toStringAsFixed(1)} л • ${_money(r.fuelCost)}',
              ),
              Text('Средний расход: ${consumption.toStringAsFixed(1)} л/100 км'),
              Text('Другие расходы: ${_money(r.expenseCost)}'),
              const Divider(),
              Text(
                'Сравнение с прошлым месяцем: '
                'рейсы ${tripDelta >= 0 ? '+' : ''}$tripDelta, '
                'пробег ${mileageDelta >= 0 ? '+' : ''}$mileageDelta км',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _section(
          'Заказы',
          orders,
          (x) =>
              '${x['date']} • ${x['title']} • ${_money((x['amount'] as num?) ?? 0)}',
        ),
        _section(
          'Топливо',
          fuel,
          (x) =>
              '${x['date']} • ${x['liters']} л • ${_money((x['total'] as num?) ?? 0)}',
        ),
        _section(
          'Расходы / запчасти',
          expenses,
          (x) =>
              '${x['date']} • ${x['description'] ?? x['category']} • ${_money((x['amount'] as num?) ?? 0)}',
        ),
        _section(
          'Ремонты',
          repairs,
          (x) {
            final total =
                ((x['part_cost'] as num?)?.toDouble() ?? 0) +
                ((x['work_cost'] as num?)?.toDouble() ?? 0);
            return '${x['date']} • ${x['title']} • ${_money(total)}';
          },
        ),
      ],
    );
  }

  Widget _tripsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _metric(
                'Полных рейсов',
                '$_fullDays',
                subtitle: 'утро + вечер в один день',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric(
                'Неполных',
                '$_partialDays',
                subtitle: 'только утро или вечер',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Утро',
                '$_morningCount',
                subtitle: _money(_morningAmount),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric(
                'Вечер',
                '$_eveningCount',
                subtitle: _money(_eveningAmount),
              ),
            ),
          ],
        ),
        BusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Дополнительные рейсы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Рейсов: $_extraCount'),
              Text('За сами рейсы: ${_money(_extraBase)}'),
              Text(
                'Ожидание: ${_extraWaitHours.toStringAsFixed(_extraWaitHours == _extraWaitHours.roundToDouble() ? 0 : 1)} ч • ${_money(_extraWaitAmount)}',
              ),
              Text(
                'Итого доп. рейсы: ${_money(_extraBase + _extraWaitAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._extraTrips.map((x) {
          final waitHours = _waitHours(x);
          final waitRate = _waitRate(x);
          final waitTotal = waitHours * waitRate;
          return Card(
            child: ListTile(
              title: Text(x['title']?.toString() ?? 'Доп. рейс'),
              subtitle: Text(
                '${x['date']}'
                '${waitHours > 0 ? '\nОжидание: ${waitHours.toStringAsFixed(waitHours == waitHours.roundToDouble() ? 0 : 1)} ч × ${_money(waitRate)} = ${_money(waitTotal)}' : ''}',
              ),
              trailing: Text(
                _money(_tripTotal(x)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        _section(
          'Все утренние и вечерние поездки',
          trips
              .where((x) => x['type'] == 'morning' || x['type'] == 'evening')
              .toList(),
          (x) =>
              '${x['date']} • ${x['type'] == 'morning' ? 'Утро' : 'Вечер'} • ${_money(_tripTotal(x))}',
        ),
      ],
    );
  }

  Widget _section(
    String title,
    List<Map<String, Object?>> rows,
    String Function(Map<String, Object?>) text,
  ) =>
      ExpansionTile(
        title: Text('$title (${rows.length})'),
        children: rows
            .map((x) => ListTile(dense: true, title: Text(text(x))))
            .toList(),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('История по месяцам'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Сводка'),
              Tab(text: 'Рейсы'),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            month = DateTime(month.year, month.month - 1);
                            load();
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${month.month.toString().padLeft(2, '0')}.${month.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            month = DateTime(month.year, month.month + 1);
                            load();
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _summaryTab(),
                        _tripsTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class DebtsScreen extends StatefulWidget { const DebtsScreen({super.key}); @override State<DebtsScreen> createState()=>_DebtsScreenState(); }
class _DebtsScreenState extends State<DebtsScreen>{
  final db=DatabaseHelper.instance; List<Map<String,Object?>> rows=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{final id=await db.getActiveVehicleId();final d=await db.database;final r=await d.rawQuery("SELECT o.*, COALESCE((SELECT SUM(p.amount) FROM order_payments p WHERE p.order_id=o.id),0) paid_amount FROM orders o WHERE o.vehicle_id=? AND o.status='completed' AND COALESCE((SELECT SUM(p.amount) FROM order_payments p WHERE p.order_id=o.id),0)<o.amount ORDER BY o.date",[id]);if(mounted)setState(()=>rows=r);}
  @override Widget build(BuildContext context){final total=rows.fold<double>(0,(a,r)=>a+((r['amount'] as num).toDouble()-((r['paid_amount'] as num?)?.toDouble()??0)));return Scaffold(appBar:AppBar(title:const Text('Долги по заказам')),body:ListView(padding:const EdgeInsets.all(16),children:[BusCard(child:ListTile(title:const Text('Всего ожидаю'),trailing:Text('${total.toStringAsFixed(0)} ₽',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))),...rows.map((r){final left=(r['amount'] as num).toDouble()-((r['paid_amount'] as num?)?.toDouble()??0);return Card(child:ListTile(title:Text(r['title']?.toString()??'Заказ'),subtitle:Text('${r['date']} • оплачено ${((r['paid_amount'] as num?)?.toDouble()??0).toStringAsFixed(0)} ₽'),trailing:Text('${left.toStringAsFixed(0)} ₽')));})]));}
}
