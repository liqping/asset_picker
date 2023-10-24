import 'package:flutter_asset_picker/src/widget/pick_base_cell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class AssetCollectionCell extends StatelessWidget {

  final String title;
  final int count;
  final Widget icon;
  final GestureTapCallback? callback;

  const AssetCollectionCell({super.key, required this.title , required this.icon, required this.count,
    this.callback}) ;

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      height: 66,
      child: Row(
        children: <Widget>[
          SizedBox(width: 66, height: 66, child: icon),
          const Padding(padding: EdgeInsets.only(left: 12)),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 17,
                    color: const CupertinoDynamicColor.withBrightness(color: Color(0xFF333333), darkColor: Color(0xFF999999)).resolveFrom(context)
                )
            ),
          ),
          const Padding(padding: EdgeInsets.only(left: 6)),
          Text('($count)',style: const TextStyle(color: Color(0xFF808080), fontSize: 16),),
          Icon(
            Icons.arrow_forward_ios,
            color:  const CupertinoDynamicColor.withBrightness(color: Color(0xFFCCCCCC), darkColor: Color(0xFF666666)).resolveFrom(context),
            size: 15,
          ),
          const Padding(padding: EdgeInsets.only(left: 15)),
        ],
      ),
    );
    return PickBaseCell(tapCallback: callback,child: child,);
  }
}


class AssetCollectionDropCell extends StatelessWidget {

  final String title;
  final int count;
  final Widget icon;
  final bool selected;
  final GestureTapCallback? callback;

  const AssetCollectionDropCell({super.key, required this.title , required this.selected , required this.icon, required this.count,
    this.callback}) ;

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox(
      height: 66,
      child: Row(
        children: <Widget>[
          SizedBox(width: 66, height: 66, child: icon),
          const Padding(padding: EdgeInsets.only(left: 12)),
          Expanded(
            child: Row(
              children: [
                Text(title,style: TextStyle(fontSize: 17,color: const CupertinoDynamicColor.withBrightness(color: Color(0xFF333333), darkColor: Color(0xFF999999)).resolveFrom(context))
                ),
                const Padding(padding: EdgeInsets.only(left: 2)),
                Text('($count)',style: const TextStyle(color: Color(0xFF808080), fontSize: 16),),
              ],
            ),
          ),
         SizedBox(width: 50,child: selected ?  const Icon(
           Icons.check,
           color:  Colors.blue,
           size: 26,
         ):null,) ,
          // const Padding(padding: EdgeInsets.only(left: 15)),
        ],
      ),
    );
    return PickBaseCell(tapCallback: callback,child: child,);
  }
}