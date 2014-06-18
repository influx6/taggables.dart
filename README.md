# Taggables

##Description:
		A simple framework built around decoupling of html tags and functionality whilst still providing the same flexibility that comes with the xtag approach,although due to limitations in dart:html
		build approach certain differences occur especially when it comes to html sanitizations.

##Examples:

'''		
	Code from web/spec.dart:
     // register up your new tag
	Taggables.core.register('dashboards','dashboard-header',(tag,init){


			//still a bad idea for inline styles
		tag.css({
			'display':'block',
			'background': 'rgba(0,0,0,0.7)',
			'overflow': 'hidden',
			'width':'200px',
			'height': '30px',
			'padding': '0px 0px 0px 10px',
			'box-sizing':'border-box',
			'-moz-box-sizing':'border-box',
			'-webkit-box-sizing':'border-box',
		});

		tag.bind('beforedomReady',(e){
			tag.createElement("span",tag.data('title'));
			//still a bad idea for inline styles
			// tag.css({
			// 	'display':'block',
			// 	'width':'90%',
			// 	'height':'100%',
			// 	'color': 'rgba(255,255,255,1)',
			// 	'font-size': '1.5em',
			// 	'font-style': 'uppercase'
			// },'span');
		});

		tag.addFactory('titleUpdate',(e){
			tag.query('span',(s){
				tag.fetchData('title',(d){
					s.setInnerHtml(d);
				});
				tag.fireEvent('updateDOM',true);
			});
		});

		tag.bindFactory('attributeChange','titleUpdate');

		init();
	});

	//create a default hook that binds the document.body and watches for each tags
	Hook.bindWith(null,null,(doc,init){
		init();
	});


	Code from web/index.html:

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

'''