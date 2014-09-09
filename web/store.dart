library taggables.store;

import 'dart:html';
import 'package:hub/hubclient.dart';
import 'package:taggables/taggables.dart';

void main(){

  Core.register('atoms','atom',(t){
    
    t.css({
      'background': 'red',
      'width':'100%',
      'height':'100%'
    });
     t.init();
  });

  var doc = window.document;
  var dh =  doc.querySelector('#dh');
  var watch = StoreDispatcher.create(doc.body);
  var store = watch.tagStore('atom');
  var attr = watch.attrStore('atomify');

  var wire = StoreDispatcher.Bind('atom',store,attr);

  watch.bind('domAdded',Funcs.tag('watch-domAdded'));
  watch.bind('childAdded',Funcs.tag('cdadd'));

  attr.adds.on(Funcs.tag('attr-added to'));
  attr.removes.on(Funcs.tag('attr-removed to'));

  watch.init();

}
