library taggables.store;

import 'dart:html';
import 'package:hub/hubclient.dart';
import 'package:taggables/taggables.dart';

void main(){

  var doc = window.document;
  var watch = TagDispatcher.create(doc.body);
  var store = watch.createStore('atom');
  var atom = Tag.create(doc.querySelector('atom'));
  atom.css({
    'background': 'red'
  });
  atom.init();

}
