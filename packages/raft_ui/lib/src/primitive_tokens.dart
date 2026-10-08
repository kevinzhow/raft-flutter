// Tier 1: actual Web brand ramps and atomic color values. Generated from pinned CSS.
// Semantic meanings live in generated_tokens.dart, never in this palette.
import 'package:flutter/material.dart';

abstract final class RaftPrimitives {
  // Product index.css327 mobile selector vector-shadow atom.
  static const rgbaff141111 = Color(0xff141111);
  // Original switch.tsx: duration-180/ease-out and OKLCH thumb atoms.
  static const Duration switchDuration = Duration(milliseconds: 180);
  static const Curve switchCurve = Cubic(0, 0, .58, 1);
  static const switchDarkThumb = Color(0xff555552); // .45 .006 106.42
  static const switchDarkCheckedThumb = Color(0xff171715); // .205 .004 106.42
  static const switchDarkDisabledThumb = Color(0xff424241); // .38 .002 106.42
  static const switchDarkCheckedDisabledThumb = Color(
    0xff292928,
  ); // .28 .002 106.42
  // foundation.css148: disabled foreground30% of the original ink atom.
  static const rgba4d141110 = Color(0x4d141110);
  // foundation.css299/407: disabled foreground semantic atoms.
  static const rgbaff9f9f9a = Color(0xff9f9f9a);
  static const rgbaff8f8f8c = Color(0xff8f8f8c);
  // foundation.css318/430: OKLCH line atoms, converted to sRGB (not samples).
  static const rgbaffcbcbc6 = Color(0xffcbcbc6);
  static const rgbaff757571 = Color(0xff757571);
  static const rgba85f5f5f5 = Color(0x85f5f5f5);
  static const rgba00000000 = Color(0x00000000);
  static const rgbaA6000000 = Color(0xa6000000);
  static const rgba59000000 = Color(0x59000000);
  static const rgba99000000 = Color(0x99000000);
  static const rgbaffe63935 = Color(0xffe63935);
  static const rgbaffdb2c2b = Color(0xffdb2c2b);
  static const rgba47ffacc9 = Color(0x47ffacc9);
  static const rgba58f391b1 = Color(0x58f391b1);
  static const rgba58d6b75a = Color(0x58d6b75a);
  static const rgbafffafaf7 = Color(0xfffafaf7);
  static const rgba47c20065 = Color(0x47c20065);
  static const rgbafff8cad8 = Color(0xfff8cad8);
  static const rgbafff3e4b3 = Color(0xfff3e4b3);
  static const rgbaff31312d = Color(0xff31312d);
  static const rgbaff000000 = Color(0xff000000);
  static const String brutalFont = 'packages/raft_ui/HankenGrotesk';
  static const String elegantBodyFont = 'packages/raft_ui/Geist';
  static const String elegantHeadingFont = 'packages/raft_ui/Inter';
  static const String monoFont = 'packages/raft_ui/GeistMono';
  static const spacing = <double>[
    0,
    2,
    4,
    6,
    8,
    10,
    12,
    14,
    16,
    20,
    24,
    28,
    32,
    36,
    40,
    44,
    48,
    56,
    62,
    64,
  ];
  static const radii = <double>[0, 2, 4, 6, 8];
  static const Duration controlDuration = Duration(milliseconds: 100);
  static const Curve controlCurve = Cubic(.4, 0, .2, 1);
  static const cream100 = Color(0xfffffcf5);
  static const cream200 = Color(0xfffffaef);
  static const cream300 = Color(0xfff9eccf);
  static const cream400 = Color(0xffebd38f);
  static const cream50 = Color(0xfffffdf9);
  static const cream500 = Color(0xffd2b100);
  static const cream600 = Color(0xffa78c00);
  static const cream700 = Color(0xff7c6800);
  static const cream800 = Color(0xff554500);
  static const cream900 = Color(0xff312700);
  static const cream950 = Color(0xff191300);
  static const cyan100 = Color(0xffd7f2fe);
  static const cyan200 = Color(0xffa9e6fe);
  static const cyan300 = Color(0xff68dafd);
  static const cyan400 = Color(0xff28ccf3);
  static const cyan50 = Color(0xffecf9ff);
  static const cyan500 = Color(0xff1ea6c6);
  static const cyan600 = Color(0xff15849f);
  static const cyan700 = Color(0xff0e6276);
  static const cyan800 = Color(0xff06414f);
  static const cyan900 = Color(0xff02252f);
  static const cyan950 = Color(0xff01161c);
  static const lime100 = Color(0xffdcfac1);
  static const lime200 = Color(0xffc0f588);
  static const lime300 = Color(0xffb4e67f);
  static const lime400 = Color(0xffa9d877);
  static const lime50 = Color(0xfff1fde9);
  static const lime500 = Color(0xff8ab261);
  static const lime600 = Color(0xff6b8b4a);
  static const lime700 = Color(0xff506836);
  static const lime800 = Color(0xff344522);
  static const lime900 = Color(0xff1c2711);
  static const lime950 = Color(0xff101808);
  static const orange100 = Color(0xfffde6de);
  static const orange200 = Color(0xfffbd1c0);
  static const orange300 = Color(0xfff9b899);
  static const orange400 = Color(0xfff8a16f);
  static const orange50 = Color(0xfffef5f1);
  static const orange500 = Color(0xffdd7e34);
  static const orange600 = Color(0xffad6127);
  static const orange700 = Color(0xff83481a);
  static const orange800 = Color(0xff5b310f);
  static const orange900 = Color(0xff331905);
  static const orange950 = Color(0xff220e02);
  static const pink100 = Color(0xffffe1e8);
  static const pink200 = Color(0xfffec1d2);
  static const pink300 = Color(0xfffea0bc);
  static const pink400 = Color(0xfffe7da8);
  static const pink50 = Color(0xfffff0f4);
  static const pink500 = Color(0xfffe2f8b);
  static const pink600 = Color(0xffd4086f);
  static const pink700 = Color(0xff9f0551);
  static const pink800 = Color(0xff700238);
  static const pink900 = Color(0xff42011e);
  static const pink950 = Color(0xff2f0014);
  static const purple100 = Color(0xffefecf9);
  static const purple200 = Color(0xffdcd7f2);
  static const purple300 = Color(0xffccc4ec);
  static const purple400 = Color(0xffbbafe6);
  static const purple50 = Color(0xfff7f6fc);
  static const purple500 = Color(0xff9d8ada);
  static const purple600 = Color(0xff7f62cb);
  static const purple700 = Color(0xff6341b0);
  static const purple800 = Color(0xff442b7c);
  static const purple900 = Color(0xff251548);
  static const purple950 = Color(0xff170c31);
  static const red100 = Color(0xfffddedd);
  static const red200 = Color(0xfffbbdb9);
  static const red300 = Color(0xfffa9991);
  static const red400 = Color(0xfff97264);
  static const red50 = Color(0xfffef1f0);
  static const red500 = Color(0xffeb4423);
  static const red600 = Color(0xffbb3419);
  static const red700 = Color(0xff8e2510);
  static const red800 = Color(0xff621708);
  static const red900 = Color(0xff3e0b03);
  static const red950 = Color(0xff280501);
  static const rgba05000000 = Color(0x05000000);
  static const rgba05ffffff = Color(0x05ffffff);
  static const rgba0a000000 = Color(0x0a000000);
  static const rgba0a1a1a1a = Color(0x0a1a1a1a);
  static const rgba0affffff = Color(0x0affffff);
  // Input recipe: oklch(.985 .004 106.42 / .04) outer bottom shadow.
  static const rgba0afafaf7 = Color(0x0afafaf7);
  static const rgba0f000000 = Color(0x0f000000);
  static const rgba0f111111 = Color(0x0f111111);
  static const rgba0fffffff = Color(0x0fffffff);
  static const rgba14000000 = Color(0x14000000);
  static const rgba141a1a1a = Color(0x141a1a1a);
  static const rgba14fffff2 = Color(0x14fffff2);
  static const rgba1a000000 = Color(0x1a000000);
  static const rgba1a1d1414 = Color(0x1a1d1414);
  // Browser transparent-canvas palette preserves its CSS alpha .1. Packing
  // that alpha as 26/255 changes the mounted dark divider composite by 1 RGB.
  static const rgba1af5f5f5 = Color.fromRGBO(245, 245, 245, .1);
  static const rgba2614140d = Color(0x2614140d);
  static const rgba29000000 = Color(0x29000000);
  static const rgba29191913 = Color(0x29191913);
  static const rgba2989701f = Color(0x2989701f);
  static const rgba29cd447c = Color(0x29cd447c);
  static const rgba29f9f9f9 = Color(0x29f9f9f9);
  static const rgba2e005e7a = Color(0x2e005e7a);
  static const rgba2e167443 = Color(0x2e167443);
  static const rgba2ea1531c = Color(0x2ea1531c);
  static const rgba2ec83227 = Color(0x2ec83227);
  static const rgba33000000 = Color(0x33000000);
  static const rgba33191914 = Color(0x33191914);
  static const rgba33fafaf5 = Color(0x33fafaf5);
  static const rgba4d000000 = Color(0x4d000000);
  static const rgba4d141111 = Color(0x4d141111);
  static const rgba4d1a1714 = Color(0x4d1a1714);
  static const rgba4df8f8f8 = Color(0x4df8f8f8);
  static const rgba66000000 = Color(0x66000000);
  static const rgba66191914 = Color(0x66191914);
  static const rgba66fad452 = Color(0x66fad452);
  static const rgba66fafaf8 = Color(0x66fafaf8);
  static const rgba80141210 = Color(0x80141210);
  static const rgba99141111 = Color(0x99141111);
  static const rgbaad151210 = Color(0xad151210);
  static const rgbaad3c3c39 = Color(0xad3c3c39);
  static const rgbaadc4c4c1 = Color(0xadc4c4c1);
  static const rgbab3e8c54e = Color(0xb3e8c54e);
  static const rgbaff025f2c = Color(0xff025f2c);
  static const rgbaff06414f = Color(0xff06414f);
  static const rgbaff074c27 = Color(0xff074c27);
  static const rgbaff095c71 = Color(0xff095c71);
  static const rgbaff0a0a09 = Color(0xff0a0a09);
  static const rgbaff0a0a0a = Color(0xff0a0a0a);
  static const rgbaff0a0c10 = Color(0xff0a0c10);
  static const rgbaff0d0d0b = Color(0xff0d0d0b);
  static const rgbaff131311 = Color(0xff131311);
  static const rgbaff141110 = Color(0xff141110);
  static const rgbaff141411 = Color(0xff141411);
  static const rgbaff191815 = Color(0xff191815);
  static const rgbaff1b1b19 = Color(0xff1b1b19);
  static const rgbaff1c1500 = Color(0xff1c1500);
  static const rgbaff1fc16b = Color(0xff1fc16b);
  static const rgbaff242422 = Color(0xff242422);
  static const rgbaff24292e = Color(0xff24292e);
  static const rgbaff27ccf3 = Color(0xff27ccf3);
  static const rgbaff28ccf3 = Color(0xff28ccf3);
  static const rgbaff292927 = Color(0xff292927);
  static const rgbaff2f0014 = Color(0xff2f0014);
  static const rgbaff32322f = Color(0xff32322f);
  static const rgbaff393936 = Color(0xff393936);
  static const rgbaff3d3d3a = Color(0xff3d3d3a);
  static const rgbaff621708 = Color(0xff621708);
  static const rgbaff655000 = Color(0xff655000);
  static const rgbaff6a2700 = Color(0xff6a2700);
  static const rgbaff6ccdea = Color(0xff6ccdea);
  static const rgbaff6ed892 = Color(0xff6ed892);
  static const rgbaff787878 = Color(0xff787878);
  static const rgbaff7b7b77 = Color(0xff7b7b77);
  static const rgbaff8f8f8d = Color(0xff8f8f8d);
  static const rgbaff96240e = Color(0xff96240e);
  static const rgbaff9ff9c9 = Color(0xff9ff9c9);
  static const rgbaffa5a5a1 = Color(0xffa5a5a1);
  static const rgbaffa9d877 = Color(0xffa9d877);
  static const rgbaffbaeafd = Color(0xffbaeafd);
  static const rgbaffbbafe6 = Color(0xffbbafe6);
  static const rgbaffc00064 = Color(0xffc00064);
  static const rgbaffc0b9b1 = Color(0xffc0b9b1);
  static const rgbaffc4c4c1 = Color(0xffc4c4c1);
  static const rgbaffc6fed5 = Color(0xffc6fed5);
  static const rgbaffd3ad03 = Color(0xffd3ad03);
  static const rgbaffd7f2fe = Color(0xffd7f2fe);
  static const rgbaffd84100 = Color(0xffd84100);
  static const rgbaffd8d8d5 = Color(0xffd8d8d5);
  static const rgbaffe5061d = Color(0xffe5061d);
  static const rgbaffe50b1e = Color(0xffe50b1e);
  static const rgbaffe5e5e2 = Color(0xffe5e5e2);
  static const rgbaffebebeb = Color(0xffebebeb);
  static const rgbaffededed = Color(0xffededed);
  static const rgbaffeeeeed = Color(0xffeeeeed);
  static const rgbaffeeefec = Color(0xffeeefec);
  static const rgbafff0f3f6 = Color(0xfff0f3f6);
  static const rgbafff3f3f3 = Color(0xfff3f3f3);
  static const rgbafff4f4f3 = Color(0xfff4f4f3);
  static const rgbafff6d56b = Color(0xfff6d56b);
  static const rgbafff70720 = Color(0xfff70720);
  static const rgbafff86e70 = Color(0xfff86e70);
  static const rgbafff8a16f = Color(0xfff8a16f);
  static const rgbafff8a49d = Color(0xfff8a49d);
  static const rgbafff8f8f7 = Color(0xfff8f8f7);
  static const rgbafff97264 = Color(0xfff97264);
  static const rgbafffbfaf8 = Color(0xfffbfaf8);
  static const rgbafffcfcfa = Color(0xfffcfcfa);
  static const rgbafffcfcfb = Color(0xfffcfcfb);
  static const rgbafffdd1ce = Color(0xfffdd1ce);
  static const rgbafffddedd = Color(0xfffddedd);
  static const rgbafffe2f8b = Color(0xfffe2f8b);
  static const rgbafffe7da8 = Color(0xfffe7da8);
  static const rgbaffff6900 = Color(0xffff6900);
  static const rgbaffffacc7 = Color(0xffffacc7);
  static const rgbaffffaf76 = Color(0xffffaf76);
  static const rgbaffffd440 = Color(0xffffd440);
  static const rgbaffffd441 = Color(0xffffd441);
  static const rgbaffffd6e2 = Color(0xffffd6e2);
  static const rgbaffffe9df = Color(0xffffe9df);
  static const rgbaffffe9e0 = Color(0xffffe9e0);
  static const rgbafffff0bd = Color(0xfffff0bd);
  static const rgbafffffaef = Color(0xfffffaef);
  static const rgbaffffffff = Color(0xffffffff);
  static const stone100 = Color(0xffefedeb);
  static const stone200 = Color(0xffe0dcd7);
  static const stone300 = Color(0xffd2cbc2);
  static const stone400 = Color(0xffc0b9b1);
  static const stone50 = Color(0xfff7f6f5);
  static const stone500 = Color(0xff9d9891);
  static const stone600 = Color(0xff7b7671);
  static const stone700 = Color(0xff5d5955);
  static const stone800 = Color(0xff3e3b38);
  static const stone900 = Color(0xff23211f);
  static const stone950 = Color(0xff141312);
  static const yellow100 = Color(0xfffff6e3);
  static const yellow200 = Color(0xffffe9b9);
  static const yellow300 = Color(0xffffdf91);
  static const yellow400 = Color(0xffffd441);
  static const yellow50 = Color(0xfffff9ed);
  static const yellow500 = Color(0xffd3ad03);
  static const yellow600 = Color(0xffa78802);
  static const yellow700 = Color(0xff7a6300);
  static const yellow800 = Color(0xff534300);
  static const yellow900 = Color(0xff2d2300);
  static const yellow950 = Color(0xff1c1500);
}
