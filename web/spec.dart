library taggables.specs;

import 'dart:html';
import 'package:taggables/taggables.dart';
import 'package:hub/hubclient.dart';

void main(){

	Hook.core.register('dashboards','expando-text',(tag,init){

		init();
	});

	Hook.core.register('dashboards','dashboard-header',(tag,init){

		var span = new Element.html('<span>${tag.data("title")}</span>');
		tag.document.append(span);

		tag.css({
			'display':'block',
			'color': '#000'
		});

		// tag.css({
		// 	'display':'block',
		// 	'width':'100%',
		// 	'height':'100%'
		// },'pre');

		tag.updateFactory('updateDOM',(e){
			tag.fireEvent('teardownDOM',true);
			tag.document.append(span);
			tag.wrapper.append(tag.document);
		});

		tag.addFactory('titleUpdate',(e){
			tag.query('span',(s){
				s.setInnerHtml(tag.data('title'));
			});
			tag.fireEvent('updateDOM',true);
		});

		tag.bindFactory('attributeChange','titleUpdate');

		init();
	});

	Hook.bindWith(null,null,(doc,init){
		init();
	});


}