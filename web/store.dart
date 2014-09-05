library taggables.store;

import 'dart:html';
import 'package:hub/hubclient.dart';
import 'package:taggables/taggables.dart';

void main(){

  var doc = window.document;
  var dh =  doc.querySelector('#dh');
  var watch = TagDispatcher.create(doc.body);
  var store = watch.createStore('atom');
  var atom = Tag.create(new Element.tag('atom'));
  atom.css({
    'background': 'red',
    'width':'100%',
    'height':'100%'
  });
  atom.init();

  watch.bind('domAdded',Funcs.tag('watch-domAdded'));
  atom.bind('domAdded',Funcs.tag('domAdded'));
  watch.bind('childAdded',Funcs.tag('cdadd'));

  watch.init();

}
