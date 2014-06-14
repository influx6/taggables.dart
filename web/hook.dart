library taggables.specs;

import 'dart:html';
import 'package:taggables/taggables.dart';
import 'package:hub/hubclient.dart';

void main(){

	Hook.core.register('gamecore','sprite',(tag,init){
		init();
	});

	Hook.core.register('imagor','sprite-element',(tag,init){
		init();
	});

	var g = Tag.create('sprite',Hook.core);

	// //binds to the root of the dom i.e window.document
	Hook.bindWith(null,null,(doc,init){

		doc.bind('tagAdded',(m){
			print('new tag $m');
		});

		doc.bind('tagRemoved',(m){
			print('old tag removed $m');
		});

		doc.bind('childAdded',(m){
			print('new element added to ${m.target}');
		});

		doc.bind('childRemoved',(m){
			print('element removed from ${m.target}');
		});

		doc.bind('addNodeComplete',(e){
			print('node addition complete $e');
		});

		doc.bind('rmNodeComplete',(e){
			print('node removed complete $e');
		});

		init();

		doc.addTag(g);
		// g.init(doc.coreElement);

	});


}