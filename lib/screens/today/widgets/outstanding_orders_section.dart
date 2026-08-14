import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../repositories/order_repository.dart';
import '../../../widgets/bus_card.dart';
import '../../orders/order_payment_screen.dart';

class OutstandingOrdersSection extends StatefulWidget {
  const OutstandingOrdersSection({super.key});
  @override State<OutstandingOrdersSection> createState()=>_OutstandingOrdersSectionState();
}
class _OutstandingOrdersSectionState extends State<OutstandingOrdersSection>{
  final _repo=OrderRepository.instance; List<Order> _orders=const[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final x=await _repo.getOutstandingOrders();if(mounted)setState((){_orders=x;_loading=false;});}
  String _money(double v)=>'${v.toStringAsFixed(0)} ₽';
  @override Widget build(BuildContext context){
    if(_loading||_orders.isEmpty)return const SizedBox.shrink();
    final total=_orders.fold<double>(0,(s,o)=>s+o.remainingAmount);
    return BusCard(backgroundColor:Colors.orange.withValues(alpha:.12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.circle,color:Colors.orange,size:14),const SizedBox(width:8),const Expanded(child:Text('Ожидаю оплату',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18))),Text(_money(total),style:const TextStyle(fontWeight:FontWeight.bold))]),
      const SizedBox(height:8),
      for(final o in _orders)ListTile(contentPadding:EdgeInsets.zero,title:Text(o.title),subtitle:Text('${o.date} • получено ${_money(o.paidAmount)} из ${_money(o.amount)}'),trailing:Text(_money(o.remainingAmount)),onTap:()async{await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>OrderPaymentScreen(order:o)));await _load();}),
    ]));
  }
}
