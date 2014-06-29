# Taggables

##Description:
		A simple framework built around decoupling of html tags and functionality whilst still providing the same flexibility that comes with the xtag approach,although due to limitations in dart:html
		build approach certain differences occur especially when it comes to html sanitizations.

##Examples:

- Code from test/spec.dart
```		
	Taggables.core.register('dashboards','dashboard-header',(tag,init){
  
                // adds an atom watch field for the parent computedstyle stylesheet object,
                //allows watching of change of css values
                tag.parentAtom.addAtomic('width',(p) => p.width);

                //enables a shadowfragment and freezes it,only content within these fragment
                //will ever be added to the new tag as content

                tag.parentAtom.bind('width',(m){
                    //parent width has changed,do something
                });
                
                tag.sealShadow();

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
				'font-style': 'uppercase'
			}
		});

		tag.bind('beforedomReady',(e){
                    //add a span into the shadow
                    tag.createShadowElement("span",tag.data('title'));
		});

		tag.addFactory('titleUpdate',(e){
                        //query the shadow and update as necessary
			tag.queryShadow('span',(s){
				tag.fetchData('title',(d){
					s.setInnerHtml(d);
				});
                          //update the dom
                          tag.fireEvent('update',true);
			});
		});

		tag.bindFactory('attributeChange','titleUpdate');

		init();
                //add the atoms to the windows.requestAnimationFrame for smooth
                // and consistent checks on value change
                tag.startAtoms();
	});

	//creates a hook and automatically binds to the body tag
	Hook.bindWith(null,null,(doc,init){
		init(); //initalizes it lazy style
	});

```

  - Code from web/index.html:
```

	<!DOCTYPE html>
		<html>
			<head>
				<meta charset="utf-8">
				<title>Taggables</title>
				<link rel="stylesheet" href="./assets/css/reset.css"/>
				<link rel="stylesheet" href="./assets/css/grid.css"/>
				<link rel="stylesheet" href="./assets/css/helpers.css"/>
				<link rel="stylesheet" href="./assets/css/spark.css"/>
				<meta lang='en' />
				<style type="text/css"></style>
			</head>
			<body>
				<dashboard-header data-title="suckerbox"></dashboard-header>
			</body>
			<script src="spec.dart" type="application/dart"></script>
			<script src="packages/browser/dart.js"></script>
	</html>

```
