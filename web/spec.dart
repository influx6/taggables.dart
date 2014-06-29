library taggables.specs;

import 'dart:html';
import 'dart:async';
import 'package:taggables/taggables.dart';
import 'package:hub/hubclient.dart';

void main(){
	
	Taggables.core.register('dashboards','writer',(tag,init){
          init();
        });

	Taggables.core.register('dashboards','dashboard-header',(tag,init){
    
                /*tag.sealShadow();*/

		tag.css.sel('dashboard-header',{
			'display':'block',
			'background': 'rgba(0,0,0,0.7)',
			'overflow': 'hidden',
			'width':'200px',
			'height': '30px',
			'padding': "0px 0px 0px 10px",
			'box-sizing':'border-box',
			'-moz-box-sizing':'border-box',
			'-webkit-box-sizing':'border-box',
			'& span':{
				'display':'block',
				'width':'90%',
				'height':'100%',
				'color': 'rgba(255,255,255,1)',
				'font-size': '1.5em',
			}
		});

		/*tag.bind('beforedomReady',(e){*/
		/*	tag.createShadowElement("span",tag.data('title'));*/
		/*});*/
  
		tag.bind('teardownDOM',(e){
                    tag.root.setInnerHtml("");
		});

		tag.bind('updateDOM',(e){
                    tag.createElement("span",tag.data('title'));
		});


		tag.addFactory('titleUpdate',(e){
                  print('grabbing title update');
                  tag.query('span',(s){
                    print('seen span $s title update');
                    tag.fetchData('title',(d){
                            s.setInnerHtml(d);
                    });
                    tag.fireEvent('update',true);
                  });
		});

		tag.bindFactory('attributeChange','titleUpdate');

		init();
	});

	Hook.bindWith(null,null,(doc,init){
		init();
	});
  
        /*Taggables.core.unregister('dashboards','dashboard-header');*/
}
