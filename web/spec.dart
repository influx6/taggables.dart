library taggables.specs;

import 'dart:html';
import 'dart:async';
import 'package:taggables/taggables.dart';
import 'package:hub/hubclient.dart';

void main(){
	
	Core.register('examples','live-header',(tag){

              print('making tag');
                tag.parentAtom.addAtomic('width',(e){
                    return e.width;
                });

                tag.parentAtom.bind('width',(e){
                    print('parents width just changed $e');
                });

		tag.css({
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

		tag.bind('teardownDOM',(e){
                    tag.root.setInnerHtml("");
		});

		tag.bind('updateDOM',(e){
                    tag.$.createElement("span",tag.$.data('title'));
		});

		tag.addFactory('titleUpdate',(e){
                  tag.$.query('span',(s){
                    tag.$.data('title',(d){
                            s.setInnerHtml(d);
                    });
                    tag.fireEvent('update',true);
                  });
		});

		tag.bindFactory('attributeChange','titleUpdate');

                print('initing tag $tag');
                tag.init();

        });


      Bind((doc){
          print('binded body');
          doc.createStore('live-header');
          doc.init();
      });
  
}
