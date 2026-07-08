import 'package:flutter/material.dart';
/// mini buttons with floatting text next to it
Widget buildMiniFab(
  Color mainColor,
  {required IconData icon,
    required String label,
    required VoidCallback onPressed}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2))
          ],
        ),
        child: Text(label,
          style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      // El boton
      FloatingActionButton.small(
        onPressed: ()=>onPressed(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[700],
        heroTag: null,
        child: Icon(icon,color:mainColor,),
      ),
    ],
  );
}

//_fabKey.currentState?.toggleMenu();
/// a FAB that expands, showing a list of childrens (usually [buildMiniFab]).
/// Has to be inside a [Stack] for the black background (scrim) to work
/// and inside a [Positioned.fill] to allow the black background to cover the full screen.
class ExpandableFab extends StatefulWidget{
  final List<Widget> children;
  final Color mainColor;
  final double distance;

  const ExpandableFab({
    super.key,
    required this.children,
    this.mainColor = Colors.cyan, 
    this.distance = 8.0,
  });

  //static ExpandableFabState? of(BuildContext context){
  //  return context.findAncestorStateOfType<ExpandableFabState>();
  //}

  @override
  State<ExpandableFab> createState() => ExpandableFabState();
}

class ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;

  late AnimationController _animationController;
  late Animation<double> _scrimFadeAnimation;
  late Animation<double> _buttonsFadeAnimation;
  late Animation<Color?> _fabColorAnimation;
  late Animation<Color?> _fabIconColorAnimation;
  late Animation<double> _fabRotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController=AnimationController(
      vsync: this,
      duration: const Duration(milliseconds:200),
    );

    // Fade del fondo oscuro
    _scrimFadeAnimation=Tween<double>(begin:0.0,end:1.0).animate(
      CurvedAnimation(parent:_animationController,curve:Curves.easeIn),
    );

    // Fade de los botones pequeños
    _buttonsFadeAnimation=Tween<double>(begin:0.0,end:1.0).animate(
      CurvedAnimation(parent:_animationController,curve:Curves.easeIn),
    );

    // Animación de color del FAB principal
    _fabColorAnimation=ColorTween(
      begin: widget.mainColor,
      end: Colors.white,
    ).animate(_animationController);

    // Animación de color del icono
    _fabIconColorAnimation = ColorTween(
      begin: Colors.white,
      end: widget.mainColor,
    ).animate(_animationController);

    // Rotación del icono (de + a x)
    _fabRotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _buildButtonColumn() {
    return FadeTransition(
      opacity: _buttonsFadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        )),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var child in widget.children) ...[
              child,
              SizedBox(height: widget.distance),
            ],
            const SizedBox(height: 8), 
          ],
        ),
      ),
    );
  }

  Widget _buildMainFab() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FloatingActionButton(
          onPressed: toggleMenu,
          backgroundColor: _fabColorAnimation.value,
          heroTag: "mainExpandableFab",
          child: RotationTransition(
            turns: _fabRotationAnimation,
            child: Icon(Icons.add, color: _fabIconColorAnimation.value),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // FONDO OSCURO (SCRIM)
        Positioned.fill(
          child: IgnorePointer(
            ignoring:!_isMenuOpen,
            child:FadeTransition(
              opacity:_scrimFadeAnimation,
              child:GestureDetector(
                onTap:toggleMenu,
                child:Container(
                  color:Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        
        // BOTONES
        Column(
          mainAxisSize:MainAxisSize.min,
          mainAxisAlignment:MainAxisAlignment.end,
          crossAxisAlignment:CrossAxisAlignment.end,
          children:[
            // BOTONES PEQUEÑOS
            IgnorePointer(
              ignoring:!_isMenuOpen,
              child:_buildButtonColumn(),
            ),
            // FAB PRINCIPAL
            _buildMainFab(),
          ],
        ),
      ],
    );
  }
}
