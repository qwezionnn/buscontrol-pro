import 'package:flutter/material.dart';
import '../../../models/credit.dart';
import '../../../repositories/credit_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayCreditPaymentSection extends StatefulWidget {
  const TodayCreditPaymentSection({super.key});
  @override State<TodayCreditPaymentSection> createState()=>_TodayCreditPaymentSectionState();
}
class _TodayCreditPaymentSectionState extends State<TodayCreditPaymentSection>{
  final _repo=CreditRepository.instance;
  List<Credit> _credits=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {final c=await _repo.getCredits();if(mounted)setState(()=>_credits=c.where((x)=>!x.archived&&!x.isClosed).toList());}
  String _money(double v)=>'${v.toStringAsFixed(0)} ₽';
  Future<void> _pay(Credit credit) async {
    final amount=TextEditingController(text: credit.monthlyPayment?.toStringAsFixed(0)??'');
    DateTime month=DateTime.now();
    final result=await showDialog<Map<String,Object?>>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
      title:Text('Оплата • ${credit.title}'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Сумма',suffixText:'₽')),
        const SizedBox(height:12),
        OutlinedButton.icon(onPressed:()async{
          final d=await showDatePicker(context:c,initialDate:month,firstDate:DateTime(2020),lastDate:DateTime(2100));
          if(d!=null)setLocal(()=>month=d);
        },icon:const Icon(Icons.calendar_month),label:Text('Месяц: ${month.month.toString().padLeft(2,'0')}.${month.year}')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Отмена')),
        FilledButton(onPressed:()=>Navigator.pop(c,{'amount':double.tryParse(amount.text.replaceAll(',','.')),'month':'${month.year}-${month.month.toString().padLeft(2,'0')}'}),child:const Text('Заплатить'))])));
    amount.dispose();
    final a=result?['amount'] as double?;
    if(a==null||a<=0)return;
    await _repo.addPayment(creditId:credit.id!,amount:a,paymentMonth:result?['month'] as String?);
    await _load();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Платёж ${_money(a)} сохранён.')));
  }
  @override Widget build(BuildContext context){
    if(_credits.isEmpty)return const SizedBox.shrink();
    return BusCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('💳 Платёж по кредиту',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
      const SizedBox(height:6),const Text('Можно указать сумму и месяц, за который платёж внесён.'),
      const SizedBox(height:10),
      for(final c in _credits.take(3))Padding(padding:const EdgeInsets.only(bottom:6),child:ListTile(contentPadding:EdgeInsets.zero,title:Text(c.title),subtitle:Text('Остаток: ${_money(c.remainingAmount)}'),trailing:FilledButton(onPressed:()=>_pay(c),child:const Text('Заплатить'))))
    ]));
  }
}
