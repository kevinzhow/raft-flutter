import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../parity/parity_harness.dart' show loadParityFonts;
void main(){setUpAll(loadParityFonts);testWidgets('diagnostic width',(t)async{
 for(final weight in [FontWeight.w700,FontWeight.w900]){
 final p=TextPainter(text:TextSpan(text:'Cindy',style:TextStyle(fontFamily:'HankenGrotesk',fontSize:24,fontWeight:weight)),textDirection:TextDirection.ltr)..layout();
 print('Cindy $weight width=${p.width} line=${p.height}');p.dispose();
 }
});}
