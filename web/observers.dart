library taggables.specs;

import 'dart:html';
import 'package:taggables/taggables.dart';
import 'package:hub/hubclient.dart';

void main(){

	var body = window.document.body;
	
	var div = document.createElement('badge');
	div.setAttribute('id','street');

	var ob = DistributedObserver.create();
	var eb = ElementObservers.create(ob);

	eb.bind('domAdded',(n) => print('domAdded $n'));
	eb.bind('domRemoved',(n) => print('domRemoved $n'));

	eb.observe(div,body);

}