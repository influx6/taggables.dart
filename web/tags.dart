library taggables.specs;

import 'dart:html';
import 'package:taggables/taggables.dart';

void main(){

	var body = window.document.body;
	//binds to the root of the dom i.e window.document
	var tag = Tag.create('badge',Taggables.core);

	tag.bind('domAdded',(e){ print('am-ready'); });
	tag.bind('domRemoved',(e){ print('am-dead'); });
	tag.bind('attributeChange',(e){ print('attrchange $e'); });
	tag.bind('attributeRemoved',(e){ print('attrrm $e'); });

	var dag = Tag.create('scrotter',Taggables.core);

	dag.bind('domAdded',(e){ print('scrot-ready'); });
	dag.bind('domRemoved',(e){ print('scrot-dead'); });
	dag.bind('attributeChange',(e){ print('scrot-attrchange $e'); });
	dag.bind('attributeRemoved',(e){ print('scrot-attrrm $e'); });

	tag.init(body.querySelector('#tag-wrapper'));
	dag.init(body.querySelector('#tag-wrapper'));


}