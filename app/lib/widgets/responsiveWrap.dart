import 'package:flutter/material.dart';

class ResponsiveWrap extends StatelessWidget{
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minItemWidth=350.0,
    this.spacing=10.0,
    this.runSpacing=10.0,
  });

  @override
  Widget build(BuildContext context){
    return LayoutBuilder(
      builder:(context,constraints){
        int columns=(constraints.maxWidth/minItemWidth).floor();
        if(columns<1)columns=1;

        final double availableWidth=constraints.maxWidth-(spacing*(columns-1));
        final double exactItemWidth=availableWidth/columns;

        return Wrap(
          spacing:spacing,
          runSpacing:runSpacing,
          children:children.map((child){
            return SizedBox(
              width:exactItemWidth,
              child:child,
            );
          }).toList(),
        );
      },
    );
  }
}
